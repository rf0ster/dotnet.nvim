local M = {}

local parser = require "dotnet.test_runner.parser"
local manager = require "dotnet.manager"
local utils = require "dotnet.utils"
local cli = require "dotnet.cli"

-- creates a namespace for the circle markers
local ns_id = vim.api.nvim_create_namespace("circle_namespace")

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
        return s:match("%.sln$") ~= nil
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
    M.tests = {}
    for _, project in ipairs(sln.projects) do
        local output = cli.test_list_all(project.path_abs)
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
                tests = tests
            }
        end
    end
end

local load_results = function()
    local found_nil = false
    local found_failed = false
    for _, test_project in pairs(M.tests) do
        local results = parser.parse_trx_file(test_project.results_file)
        if results == nil then
            test_project.outcome = nil
            found_nil = true
            for _, test in pairs(test_project.tests) do
                test.result = { outcome = nil }
            end
        else
            local res = "Passed"
            for _, test_result in pairs(results) do
                test_project.tests[test_result.testName].result = test_result
                if test_result.outcome == "Failed" then
                    found_failed = true
                    res = "Failed"
                end
            end
            test_project.outcome = res
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
local write_test = function(text, spaces, highlight)
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

    vim.api.nvim_buf_set_lines(M.bufnr_tests, -1, -1, false, {res})
    vim.api.nvim_buf_set_extmark(M.bufnr_tests, ns_id, line_num, spaces - 2, {
        virt_text = {{"●", highlight}},
        virt_text_pos = "overlay"
    })
end

-- Writes tests to buffer
local write_tests_to_buffer = function()
    set_buf_modifiable(M.bufnr_tests, true)

    -- Clears all text from the buffer
    vim.api.nvim_buf_set_lines(M.bufnr_tests, 0, -1, false, {})
    -- Clears all extmarks from the buffer
    vim.api.nvim_buf_clear_namespace(M.bufnr_tests, ns_id, 0, -1)
    -- Sets cursor to first line in buffer
    vim.api.nvim_win_set_cursor(M.win_tests, {1, 0})
    -- Write header in the first line of the buffer
    vim.api.nvim_buf_set_lines(M.bufnr_tests, 0, -1, false, {" (R)eload Tests"})
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
    write_test(M.sln_outcome.sln_name, 2, get_highlight(M.sln_outcome.result))
    for _, val in pairs(M.tests) do
        write_test(val.project.path_rel, 4, get_highlight(val.outcome))
        if val.tests ~= nil then
            for k, v in pairs(val.tests) do
                write_test(k, 6, get_highlight(v.result.outcome))
            end
        end
    end

    set_buf_modifiable(M.bufnr_tests, false)
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

    local on_output = function(_, data, _)
        if data then
            for _, line in ipairs(data) do
                vim.api.nvim_buf_set_lines(M.bufnr_output, -1, -1, false, {utils.clean_line(line)})
            end
        end
        local last_line = vim.api.nvim_buf_line_count(M.bufnr_output)
        vim.api.nvim_win_set_cursor(M.win_output, {last_line, 0})
    end

    -- clear contents of the output buffer
    set_buf_modifiable(M.bufnr_output, true)
    vim.api.nvim_buf_set_lines(M.bufnr_output, 0, -1, false, {})

    local target = p or s
    local cmd ="dotnet test " .. target .. filter .. " --logger \"trx;LogFileName=nvim_dotnet_results.trx\""
    vim.fn.jobstart(cmd, {
        on_stdout = on_output,
        on_stderr = on_output,
        on_exit = function()
            load_results()
            write_tests_to_buffer()
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
