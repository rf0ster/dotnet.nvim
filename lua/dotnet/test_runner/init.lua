local M = {}

local solution = require "dotnet.solution"
local cli = require "dotnet.cli"

-- creates a namespace for the circle markers
local ns_id = vim.api.nvim_create_namespace("circle_namespace")

-- Given a row, reads the line to capture the test name.
-- If the test name is not a .csproj files, then iterate down
-- through the buffer until a .csproj file is found.
-- Returns the test name and the project file. 
-- If the buffer is already at a .csproj file, then the test name is nil.
local function get_test_info()
    local bufnr = vim.api.nvim_get_current_buf()
    if bufnr ~= M.bufnr_tests then
        return {
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

    local row = vim.api.nvim_win_get_cursor(0)[1] -- Get the current row
    local line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1]  -- Fetch the line
    line = trim(line)

    if is_proj(line) then
        return {
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
        proj_name = proj_file,
        test_name = test_name
    }
end


-- Creates a new window with the buffer
local create_windows = function()
    -- Calculate window sizes
	local height = math.floor(vim.o.lines * 0.8)
	local width = math.floor(vim.o.columns * 0.8) -- Two windows, divide by 2
	local row = math.floor((vim.o.lines - height) / 2)
	local col = math.floor((vim.o.columns - width) / 2)

    local create_win = function(bufnr, title, c)
        local win = vim.api.nvim_open_win(bufnr, true, {
            title = " " .. title,
            relative = "editor",
            height = height,
            width = math.floor(width * 0.5),
            row = row,
            col = c,
            style = "minimal",
            border = "rounded",
        })
        vim.wo[win].statusline = "hello"
        vim.wo[win].cursorcolumn = false
        vim.wo[win].cursorline = false
        vim.wo[win].wrap = false
        return win
    end

    -- Create test selection window
    M.bufnr_tests = vim.api.nvim_create_buf(false, true)
    M.win_tests = create_win(M.bufnr_tests, "Test Runner", col)

    -- Create test results window
    M.bufnr_results = vim.api.nvim_create_buf(false, true)
    M.win_results = create_win(M.bufnr_results, "Results", col + math.floor(width * 0.5) + 1)

    -- Close both windows when either buffer is closed.
    local close_windows = function()
        if vim.api.nvim_win_is_valid(M.win_tests) then
            vim.api.nvim_win_close(M.win_tests, true)
        end
        if vim.api.nvim_win_is_valid(M.win_results) then
            vim.api.nvim_win_close(M.win_results, true)
        end
    end

    local evts = {"BufWipeout", "BufWinLeave", "WinClosed"}
    vim.api.nvim_create_autocmd(evts, {
        buffer = M.bufnr_tests,
        callback = close_windows
    })
    vim.api.nvim_create_autocmd(evts, {
        buffer = M.bufnr_results,
        callback = close_windows
    })

    -- Creates autocmd that if the cursor in the bufrnr_tests is moved, the results are updated
    vim.api.nvim_create_autocmd("CursorMoved", {
        buffer = M.bufnr_tests,
        callback = function()
            local info = get_test_info()
            local p = info.proj_name or ""
            local t = info.test_name or ""

            if p == "" then
                return
            end

            local result = {}
            if t ~= "" then
                result = {M.tests[p].tests[t].result}
            end
            vim.api.nvim_buf_set_lines(M.bufnr_results, 0, -1, false, result)
        end
    })

    -- set current window to the test window
    vim.api.nvim_set_current_win(M.win_tests)
end


-- Loads the tests from the solution
local function load_tests()
    local sln = solution.get_solution()
    if sln == nil then
        return
    end

    local projects = solution.get_projects()
    if not projects then
        return
    end

    M.tests = {}
    for _, project in ipairs(projects) do
        local output = cli.test_list_all(project.file)
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
                tests[name] = {
                    name = name,
                    result = "Results for " .. name
                }
            end
        end

        if tests ~= nil then
            M.tests[project.file] = {
                proj_name = project.name,
                proj_file = project.file,
                tests = tests
            }
        end
    end
end

-- Pretty prints the tests to the buffer with cool circle markers
local write_test = function(text, spaces)
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
        virt_text = {{"●", "Comment"}},
        virt_text_pos = "overlay"
    })
end

-- Writes tests to buffer
local write_tests_to_buffer = function()
    -- Clears all text from the buffer
    vim.api.nvim_buf_set_lines(M.bufnr_tests, 0, -1, false, {})
    -- Clears all extmarks from the buffer
    vim.api.nvim_buf_clear_namespace(M.bufnr_tests, ns_id, 0, -1)
    -- Sets cursor to first line in buffer
    vim.api.nvim_win_set_cursor(M.win_tests, {1, 0})

    -- Load the tests
    if M.tests == nil then
        return
    end

    -- Write the tests to the buffer
    for key, val in pairs(M.tests) do
        write_test(key, 2)
        if val.tests ~= nil then
            for k, _ in pairs(val.tests) do
                write_test(k, 4)
            end
        end
    end
end

-- set buffer options
local set_buffer_options = function(bufnr)
    vim.api.nvim_buf_set_option(bufnr, "modifiable", false)  -- No editing
    vim.api.nvim_buf_set_option(bufnr, "buftype", "nofile")  -- Not a real file
    vim.api.nvim_buf_set_option(bufnr, "swapfile", false)    -- No swap file
    vim.api.nvim_buf_set_option(bufnr, "bufhidden", "wipe")  -- Close on exit
    vim.api.nvim_buf_set_option(bufnr, "readonly", true)     -- Mark as read-only
    vim.api.nvim_buf_set_option(bufnr, "cursorline", true)   -- highlight current line
end

-- Opens the test runner window
M.open = function()
    if M.tests == nil then
        load_tests()
    end

    create_windows()

    write_tests_to_buffer()
    set_buffer_options(M.bufnr_tests)
    --set_buffer_options(M.bufnr_results)
end

return M
