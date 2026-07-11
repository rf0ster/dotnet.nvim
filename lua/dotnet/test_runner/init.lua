local M = {}

local parser = require "dotnet.test_runner.parser"
local store = require "dotnet.test_runner.store"
local manager = require "dotnet.manager"
local utils = require "dotnet.utils"
local DotnetCli = require "dotnet.cli"

-- creates a namespace for the circle markers
local ns_id = vim.api.nvim_create_namespace("circle_namespace")

-- namespace for highlighting the streamed `dotnet test` output
local output_ns = vim.api.nvim_create_namespace("dotnet_output_namespace")

-- Picks a highlight group for a line of `dotnet test` output so results and
-- boilerplate read at a glance. Returns nil to leave the line unhighlighted.
local function output_highlight(line)
    if line:match("^%s*Passed!") or line:match("^%s*Passed%s") then
        return "String"
    end
    if line:match("^%s*Failed!") or line:match("^%s*Failed%s") then
        return "ErrorMsg"
    end
    if line:match("^%s*Skipped!") or line:match("^%s*Skipped%s") then
        return "WarningMsg"
    end
    if line:match("[Bb]uild succeeded") then
        return "String"
    end
    if line:match("[Bb]uild FAILED") then
        return "ErrorMsg"
    end
    -- Dim the restore/boilerplate noise so the results stand out.
    if line:match("^%s*Determining projects to restore")
        or line:match("up%-to%-date for restore")
        or line:match("%->%s")
        or line:match("^%s*Microsoft %(R%)")
        or line:match("^%s*Copyright")
        or line:match("Starting test execution")
        or line:match("A total of %d+ test file")
    then
        return "Comment"
    end
    return nil
end

-- Frames for the "tests running" loader. Braille dots read as a smooth spinner.
local spinner_frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
M.spinner_idx = 1
M.running_marks = {} -- {line, col, id} of the test-list circles currently spinning

-- Stops the loader animation timer if one is running.
local function stop_spinner()
    if M.spinner_timer then
        vim.fn.timer_stop(M.spinner_timer)
        M.spinner_timer = nil
    end
end

-- Advances the loader one frame. The output-window header and every running
-- circle in the test list share the frame so they animate in sync. Updates are
-- by extmark id, so they work even while the buffers are non-modifiable.
local function spinner_tick()
    M.spinner_idx = (M.spinner_idx % #spinner_frames) + 1
    local frame = spinner_frames[M.spinner_idx]

    if M.header_mark and M.bufnr_output and vim.api.nvim_buf_is_valid(M.bufnr_output) then
        vim.api.nvim_buf_set_extmark(M.bufnr_output, output_ns, 0, 1, {
            id = M.header_mark,
            virt_text = {{frame, "Title"}},
            virt_text_pos = "overlay",
        })
    end

    if M.bufnr_tests and vim.api.nvim_buf_is_valid(M.bufnr_tests) then
        for _, mark in ipairs(M.running_marks) do
            vim.api.nvim_buf_set_extmark(M.bufnr_tests, ns_id, mark.line, mark.col, {
                id = mark.id,
                virt_text = {{frame, "Comment"}},
                virt_text_pos = "overlay",
            })
        end
    end
end

-- Starts the loader animation (10 fps).
local function start_spinner()
    stop_spinner()
    M.spinner_timer = vim.fn.timer_start(100, spinner_tick, { ["repeat"] = -1 })
end

-- Clears the "running" flag from the solution, every project and every test.
local function clear_running()
    M.sln_running = false
    if M.tests then
        for _, proj in pairs(M.tests) do
            proj.running = false
            if proj.tests then
                for _, tst in pairs(proj.tests) do
                    tst.running = false
                end
            end
        end
    end
end

local set_buf_modifiable = function(bufnr, modifiable)
    vim.api.nvim_buf_set_option(bufnr, "readonly", not modifiable)
    vim.api.nvim_buf_set_option(bufnr, "modifiable", modifiable)
end

-- Given a row, reads the line to capture the test name.
-- If the test name is not a .csproj files, then iterate down
-- through the buffer until a .csproj file is found.
-- Returns the test name and the project file. 
-- If the buffer is already at a .csproj file, then the test name is nil.
local function get_test_info()
    local bufnr = vim.api.nvim_get_current_buf()
    if bufnr ~= M.bufnr_tests then
        return {
            sln_name = nil,
            proj_name = nil,
            test_name = nil
        }
    end

    local trim = function(s)
        if s == nil then
            return nil
        end
        return s:match("^%s*(.-)%s*$")
    end

    local is_proj = function(s)
        if s == nil then
            return false
        end
        return s:match("%.csproj$") ~= nil
    end

    local is_sln = function(s)
        if s == nil then
            return false
        end
        return s:match("%.sln$") ~= nil or s:match("%.slnx$") ~= nil
    end

    local row = vim.api.nvim_win_get_cursor(0)[1] -- Get the current row
    local line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1]  -- Fetch the line
    line = trim(line)

    if is_sln(line) then
        return {
            sln_name = line,
            proj_name = nil,
            test_name = nil
        }
    end
    if is_proj(line) then
        return {
            sln_name = nil,
            proj_name = line,
            test_name = nil
        }
    end

    local test_name = line
    local proj_file = nil
    for i = row, 1, -1 do
        line = vim.api.nvim_buf_get_lines(M.bufnr_tests, i - 1, i, false)[1]
        line = trim(line)
        if is_proj(line) then
            proj_file = line
            break
        end
    end

    return {
        sln_name = nil,
        proj_name = proj_file,
        test_name = test_name
    }
end


-- Loads the tests from the solution
local function load_tests()
    local sln = manager.load_solution()
    if sln == nil or sln.projects == nil then
        return
    end

    M.sln_outcome = {
        result = { "No Results" },
        sln_name = sln.sln_name, -- Get relative path
    }

    -- Preserve each project's collapsed state across reloads.
    local prev_collapsed = {}
    if M.tests ~= nil then
        for key, val in pairs(M.tests) do
            prev_collapsed[key] = val.collapsed
        end
    end
    M.tests = {}

    local cli = DotnetCli:new({})
    for _, project in ipairs(sln.projects) do
        local output = cli:test_list_all(project.path_abs)
        if not output then
            break
        end

        local tests = nil
        local test_capture_start = false
        for _, line in ipairs(output) do
            -- If the line contains the text "The following Tests are available",
            -- then we can start capturing the tests.
            -- This is a major assumption of the dotnet cli, andy may break in the future.
            if line:find('The following Tests are available') then
                test_capture_start = true
            elseif test_capture_start and line ~= '' then
                if tests == nil then
                    tests = {}
                end
                local name = line:match("^%s*(.-)%s*$")
                if name ~= nil and name ~= "" and not name:find("Workload updates are available") then
                    tests[name] = {
                        name = name,
                        result = { "No Results" }
                    }
                end
            end
        end

        if tests ~= nil then
            local results_file = project.path_abs:match("(.*/)")
            if vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1 then
                results_file = results_file .. "\\TestResults\\nvim_dotnet_results.trx"
            else
                results_file = results_file .. "TestResults/nvim_dotnet_results.trx"
            end

            M.tests[project.path_rel] = {
                project = project,
                results_file = results_file,
                tests = tests,
                collapsed = prev_collapsed[project.path_rel]
            }
        end
    end
end

local load_results = function()
    -- Fold each project's latest .trx into the persistent store. A run
    -- overwrites the .trx with only the tests it covered, so merging (newest
    -- result per test wins) is what keeps state for tests outside that run.
    local sln_path = manager.sln_path_abs
    local data = store.load(sln_path)
    for _, test_project in pairs(M.tests) do
        local results = parser.parse_trx_file(test_project.results_file)
        store.merge_project(data, test_project.project.path_rel, results)
    end
    store.save(sln_path, data)

    -- Populate the display state from the merged store rather than the raw
    -- .trx. Tests not present in the store have never been run.
    local found_nil = false
    local found_failed = false
    for _, test_project in pairs(M.tests) do
        local bucket = data[test_project.project.path_rel] or {}
        local has_result = false
        local proj_failed = false
        for name, test in pairs(test_project.tests) do
            local record = bucket[name]
            if record ~= nil then
                test.result = record
                has_result = true
                if record.outcome == "Failed" then
                    proj_failed = true
                end
            else
                test.result = { outcome = nil }
            end
        end

        if proj_failed then
            test_project.outcome = "Failed"
            found_failed = true
        elseif has_result then
            test_project.outcome = "Passed"
        else
            test_project.outcome = nil
            found_nil = true
        end
    end

    if found_failed then
        M.sln_outcome.result = "Failed"
    elseif found_nil then
        M.sln_outcome.result = nil
    else
        M.sln_outcome.result = "Passed"
    end
end

-- Pretty prints the tests to the buffer with cool circle markers
local write_test = function(text, spaces, highlight, running)
    local line_num = vim.api.nvim_buf_line_count(M.bufnr_tests)

    if not spaces then
        spaces = 0
    end
    if spaces < 2 then
        spaces = 2
    end
    spaces = spaces + 1

    local res = ""
    for _ = 1, spaces do
        res = res .. " "
    end
    res = res .. text

    -- Running items show a grey spinner in place of the status circle; the
    -- animation timer updates the extmark by id while the job runs.
    local glyph, hl = "●", highlight
    if running then
        glyph, hl = spinner_frames[M.spinner_idx], "Comment"
    end

    vim.api.nvim_buf_set_lines(M.bufnr_tests, -1, -1, false, {res})
    local mark_id = vim.api.nvim_buf_set_extmark(M.bufnr_tests, ns_id, line_num, spaces - 2, {
        virt_text = {{glyph, hl}},
        virt_text_pos = "overlay"
    })
    if running then
        table.insert(M.running_marks, { line = line_num, col = spaces - 2, id = mark_id })
    end
    return line_num
end

-- Writes tests to buffer
local write_tests_to_buffer = function()
    set_buf_modifiable(M.bufnr_tests, true)

    -- Rebuilt below; the animation timer reads this fresh each tick.
    M.running_marks = {}

    -- Clears all text from the buffer
    vim.api.nvim_buf_set_lines(M.bufnr_tests, 0, -1, false, {})
    -- Clears all extmarks from the buffer
    vim.api.nvim_buf_clear_namespace(M.bufnr_tests, ns_id, 0, -1)
    -- Sets cursor to first line in buffer
    vim.api.nvim_win_set_cursor(M.win_tests, {1, 0})
    -- Write header in the first line of the buffer
    vim.api.nvim_buf_set_lines(M.bufnr_tests, 0, -1, false, {" (R)eload Tests    (<Tab>) Fold Project"})
    -- Write an empy line to the buffer
    vim.api.nvim_buf_set_lines(M.bufnr_tests, 1, -1, false, {""})

    -- Load the tests
    if M.tests == nil then
        return
    end

    local get_highlight = function(outcome)
        if outcome == nil then
            return "Comment"
        end
        if outcome == "Passed" then
            return "String"
        end
        if outcome == "Failed" then
            return "ErrorMsg"
        end
        return "Comment"
    end

    -- Write the tests to the buffer
    write_test(M.sln_outcome.sln_name, 2, get_highlight(M.sln_outcome.result), M.sln_running)
    for _, val in pairs(M.tests) do
        local proj_line = write_test(val.project.path_rel, 4, get_highlight(val.outcome), val.running)

        -- Draw a fold chevron for the project. This is virtual text rather than
        -- real characters so get_test_info() still sees a clean ".csproj" line.
        local chevron = val.collapsed and "▸" or "▾"
        vim.api.nvim_buf_set_extmark(M.bufnr_tests, ns_id, proj_line, 1, {
            virt_text = {{chevron, "Comment"}},
            virt_text_pos = "overlay"
        })

        if val.tests ~= nil and not val.collapsed then
            for k, v in pairs(val.tests) do
                write_test(k, 6, get_highlight(v.result.outcome), v.running)
            end
        end
    end

    set_buf_modifiable(M.bufnr_tests, false)
end

-- Rewrites the buffer while keeping the cursor on its current row. Collapsing a
-- project only removes lines below it, so the row of the item under the cursor
-- is unchanged; clamp in case the buffer got shorter.
local rewrite_keeping_cursor = function()
    local row = vim.api.nvim_win_get_cursor(M.win_tests)[1]
    write_tests_to_buffer()
    local line_count = vim.api.nvim_buf_line_count(M.bufnr_tests)
    if row > line_count then
        row = line_count
    end
    vim.api.nvim_win_set_cursor(M.win_tests, {row, 0})
end

-- Toggles the collapsed state of the project under the cursor. Only acts when
-- the cursor is on a project line (a test line has a test_name).
local toggle_collapse = function()
    local info = get_test_info()
    local p = info.proj_name
    if not p or info.test_name ~= nil or M.tests[p] == nil then
        return
    end
    M.tests[p].collapsed = not M.tests[p].collapsed
    rewrite_keeping_cursor()
end

-- Sets the collapsed state of every project (collapse-all / expand-all).
local set_all_collapsed = function(collapsed)
    if M.tests == nil then
        return
    end
    for _, val in pairs(M.tests) do
        val.collapsed = collapsed
    end
    rewrite_keeping_cursor()
end

local run_test = function()
    local info = get_test_info()
    local s = info.sln_name
    local p = info.proj_name
    local t = info.test_name

    if not p and not s then
        return
    end

    local filter = ""
    if t then
        filter = " --filter " .. t
    end

    -- Collapse runs of blank lines; true so leading/duplicate blanks are dropped.
    local last_was_blank = true

    -- Appends one line to the output buffer, collapsing blank runs and applying
    -- a highlight based on its content.
    local append_line = function(raw)
        local text = utils.clean_line(raw)
        local is_blank = text == ""
        if is_blank and last_was_blank then
            return
        end
        last_was_blank = is_blank

        local lnum = vim.api.nvim_buf_line_count(M.bufnr_output)
        vim.api.nvim_buf_set_lines(M.bufnr_output, -1, -1, false, {text})
        if not is_blank then
            local hl = output_highlight(text)
            if hl then
                vim.api.nvim_buf_add_highlight(M.bufnr_output, output_ns, hl, lnum, 0, -1)
            end
        end
    end

    local render = function(lines)
        for _, line in ipairs(lines) do
            append_line(line)
        end
    end

    -- clear contents of the output buffer
    set_buf_modifiable(M.bufnr_output, true)
    vim.api.nvim_buf_set_lines(M.bufnr_output, 0, -1, false, {})
    vim.api.nvim_buf_clear_namespace(M.bufnr_output, output_ns, 0, -1)

    local target = p or s
    -- Header line; the reserved second cell holds an animated loader (then a
    -- pass/fail glyph) via an overlay extmark so the header text stays put.
    vim.api.nvim_buf_set_lines(M.bufnr_output, 0, -1, false, {"   dotnet test " .. (t or target)})
    vim.api.nvim_buf_add_highlight(M.bufnr_output, output_ns, "Title", 0, 0, -1)
    M.header_mark = vim.api.nvim_buf_set_extmark(M.bufnr_output, output_ns, 0, 1, {
        virt_text = {{spinner_frames[M.spinner_idx], "Title"}},
        virt_text_pos = "overlay",
    })

    -- Flag the targeted scope as running so the list shows grey spinners, paint
    -- them, and start the loader animation. p present => a project or a single
    -- test; otherwise the whole solution is running.
    clear_running()
    if p and M.tests[p] then
        local proj = M.tests[p]
        if t then
            if proj.tests[t] then proj.tests[t].running = true end
        else
            proj.running = true
            for _, tst in pairs(proj.tests) do tst.running = true end
        end
    else
        M.sln_running = true
        if M.tests then
            for _, proj in pairs(M.tests) do
                proj.running = true
                for _, tst in pairs(proj.tests) do tst.running = true end
            end
        end
    end
    rewrite_keeping_cursor()
    start_spinner()

    -- Buffer each stream: Neovim splits buffered output on newlines and hands
    -- back a complete, correctly-bounded line list, so lines never get torn
    -- across job callbacks (which garbled multi-project summaries before).
    local stdout_lines, stderr_lines = {}, {}
    local cmd ="dotnet test " .. target .. filter .. " --logger \"trx;LogFileName=nvim_dotnet_results.trx\""
    vim.fn.jobstart(cmd, {
        stdout_buffered = true,
        stderr_buffered = true,
        on_stdout = function(_, data) if data then stdout_lines = data end end,
        on_stderr = function(_, data) if data then stderr_lines = data end end,
        on_exit = function()
            stop_spinner()
            clear_running()
            load_results()

            -- Repaint the list with real pass/fail colours (running now false).
            if M.bufnr_tests and vim.api.nvim_buf_is_valid(M.bufnr_tests)
                and M.win_tests and vim.api.nvim_win_is_valid(M.win_tests) then
                write_tests_to_buffer()
            end

            if not (M.bufnr_output and vim.api.nvim_buf_is_valid(M.bufnr_output)) then
                return
            end
            render(stdout_lines)
            render(stderr_lines)

            -- Swap the loader for a pass/fail glyph in the header.
            local outcome
            if p and M.tests[p] then
                if t and M.tests[p].tests[t] then
                    outcome = M.tests[p].tests[t].result.outcome
                else
                    outcome = M.tests[p].outcome
                end
            else
                outcome = M.sln_outcome.result
            end
            local glyph, hl = "▶", "Title"
            if outcome == "Passed" then
                glyph, hl = "✓", "String"
            elseif outcome == "Failed" then
                glyph, hl = "✗", "ErrorMsg"
            end
            if M.header_mark then
                vim.api.nvim_buf_set_extmark(M.bufnr_output, output_ns, 0, 1, {
                    id = M.header_mark,
                    virt_text = {{glyph, hl}},
                    virt_text_pos = "overlay",
                })
            end

            if M.win_output and vim.api.nvim_win_is_valid(M.win_output) then
                local last_line = vim.api.nvim_buf_line_count(M.bufnr_output)
                vim.api.nvim_win_set_cursor(M.win_output, {last_line, 0})
            end
            set_buf_modifiable(M.bufnr_output, false)
        end
    })
end

-- Creates a new window with the buffer
local create_windows = function()
    -- Calculate max window area for all windows
	local height = math.floor(vim.o.lines * 0.8)
	local width = math.floor(vim.o.columns * 0.8)
	local row = math.floor((vim.o.lines - height) / 2)
	local col = math.floor((vim.o.columns - width) / 2)

    local output_height = math.floor(height * 0.2)
    local create_win = function(bufnr, title, c, w)
        local win = vim.api.nvim_open_win(bufnr, true, {
            title = " " .. title,
            relative = "editor",
            height = math.floor(height - output_height) - 3,
            width = w,
            row = row,
            col = c,
            style = "minimal",
            border = "rounded",
        })
        vim.wo[win].cursorcolumn = false
        vim.wo[win].cursorline = false
        vim.wo[win].wrap = false
        return win
    end

    -- Create test selection window
    M.bufnr_tests = vim.api.nvim_create_buf(false, true)
    M.win_tests = create_win(M.bufnr_tests, "Test Runner", col, math.floor(width * 0.5) - 1)

    -- Create test results window
    M.bufnr_results = vim.api.nvim_create_buf(false, true)
    M.win_results = create_win(M.bufnr_results, "Results", col + math.floor(width * 0.5) + 1, math.floor(width * 0.5) - 1)

    -- Create test output window
    M.bufnr_output = vim.api.nvim_create_buf(false, true)
    M.win_output = vim.api.nvim_open_win(M.bufnr_output, true, {
        title = " Output",
        relative = "editor",
        height = output_height,
        width = width,
        row = row + math.floor(height * 0.8),
        col = col,
        style = "minimal",
        border = "rounded",
    })

    utils.create_knot({M.win_tests, M.win_results, M.win_output})

    -- Creates autocmd that if the cursor in the bufrnr_tests is moved, the results are updated
    vim.api.nvim_create_autocmd("CursorMoved", {
        buffer = M.bufnr_tests,
        callback = function()
            local info = get_test_info()
            local p = info.proj_name or ""
            local t = info.test_name or ""

            if p == "" or t == "" then
                vim.api.nvim_buf_set_lines(M.bufnr_results, 0, -1, false, {})
                return
            end

            local result = M.tests[p].tests[t].result
            local nil_to_str = function(v)
                if v == nil then
                    return ""
                end
                return v
            end
            local output = {
                " Result: " .. nil_to_str(result.outcome),
                " Start Time: " .. nil_to_str(result.startTime),
                " End Time: " .. nil_to_str(result.endTime),
                " Duration: " .. nil_to_str(result.duration)
            }
            if result.output ~= nil then
                table.insert(output, "")
                table.insert(output, " Output:")
                table.insert(output, "   Message: " .. result.output.Message)
                table.insert(output, "   Stack Trace:")

                local w = vim.api.nvim_win_get_width(M.win_results)
                local smart_lines = utils.split_smart(result.output.StackTrace, w, 5, 1)
                for _, line in ipairs(smart_lines) do
                    table.insert(output, line)
                end
            end

            vim.api.nvim_buf_set_lines(M.bufnr_results, 0, -1, false, output)
        end
    })

    -- set current window to the test window
    vim.api.nvim_set_current_win(M.win_tests)

    vim.api.nvim_buf_set_keymap(M.bufnr_tests, "n", "<CR>", "", {
        noremap = true,
        silent = true,
        callback = run_test
    })
    vim.api.nvim_buf_set_keymap(M.bufnr_tests, "n", "R", "", {
        noremap = true,
        silent = true,
        callback = M.reload
    })

    -- Fold the project under the cursor. <Tab> and za both toggle it; zM/zR
    -- collapse/expand every project at once (mirroring Vim's fold commands).
    for _, key in ipairs({ "<Tab>", "za" }) do
        vim.api.nvim_buf_set_keymap(M.bufnr_tests, "n", key, "", {
            noremap = true,
            silent = true,
            callback = toggle_collapse
        })
    end
    vim.api.nvim_buf_set_keymap(M.bufnr_tests, "n", "zM", "", {
        noremap = true,
        silent = true,
        callback = function() set_all_collapsed(true) end
    })
    vim.api.nvim_buf_set_keymap(M.bufnr_tests, "n", "zR", "", {
        noremap = true,
        silent = true,
        callback = function() set_all_collapsed(false) end
    })
end

-- set buffer options
local set_buffer_options = function(bufnr)
    set_buf_modifiable(bufnr, false)
    vim.api.nvim_buf_set_option(bufnr, "buftype", "nofile")  -- Not a real file
    vim.api.nvim_buf_set_option(bufnr, "swapfile", false)    -- No swap file
    vim.api.nvim_buf_set_option(bufnr, "bufhidden", "wipe")  -- Close on exit
    vim.api.nvim_buf_set_option(bufnr, "cursorline", true)   -- highlight current line
end

-- Reloads the tests and writes them to the buffer
M.reload = function()
    load_tests()
    load_results()
    write_tests_to_buffer()
end

-- Opens the test runner window
M.open = function()
    if M.tests == nil then
        load_tests()
    end
    load_results()
    create_windows()
    write_tests_to_buffer()
    set_buffer_options(M.bufnr_tests)
end

return M
