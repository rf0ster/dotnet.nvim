local M  = {}

local solution = require "dotnet.solution"
local cli = require "dotnet.cli"
local xml = require "xml2lua"
if xml == nil then
    vim.notify("xml2lua not found. Please install it using luarocks")
    return
end

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
            return {}
        end

        local tests = {}
        local test_capture_start = false
        for _, line in ipairs(output) do
            -- If the line contains the text "The following Tests are available",
            -- then we can start capturing the tests.
            -- This is a major assumption of the dotnet cli, andy may break in the future.
            if line:find('The following Tests are available') then
                test_capture_start = true
            elseif test_capture_start and line ~= '' then
                table.insert(tests, line:match("^%s*(.-)%s*$"))
            end
        end

        table.insert(M.tests, {
            proj_name = project.name,
            proj_file = project.file,
            tests = tests
        })
    end
end

-- Funcion that will read the current line of the buffer and print
-- the test name to the console. If the line is a project, print
-- name of the project. If the line is a test, get the name of the
-- test, and search up the buffer for the project name.
local function run_test()
    local line = vim.api.nvim_get_current_line()
    if line == nil then
        return
    end

    -- Trim leading and trailing spaces
    line = line:match("^%s*(.-)%s*$")
    if line == "" then
        return
    end

    local logger = "\"trx;LogFileName=testResults.trx\""
    if line:match("%.csproj") ~= nil then
        cli.mstest(line, nil, logger)
    else
        local test = line:match("^%s*(.-)%s*$")
        local project = nil

        local bufnr = vim.api.nvim_get_current_buf()
        local current_line = vim.api.nvim_win_get_cursor(0)[1]

        for i = current_line, 1, -1 do
            local l = vim.api.nvim_buf_get_lines(bufnr, i - 1, i, false)[1]
            l = l:match("^%s*(.-)%s*$")
            if l:match("%.csproj") then
                project = l
                break
            end
        end

        if project then
            cli.mstest(project, test, logger)
        end
    end
end

function M.open()
    local bufnr = vim.api.nvim_create_buf(false, true)
	local width = math.floor(vim.o.columns * 0.8)
	local height = math.floor(vim.o.lines * 0.8)
	local row = math.floor((vim.o.lines - height) / 2)
	local col = math.floor((vim.o.columns - width) / 2)

    local win = vim.api.nvim_open_win(bufnr, true, {
        relative = "editor",
        width = width,
        height = height,
        row = row,
        col = col,
        style = "minimal",
        border = "double",
        title = "Test Runner"
    })
    vim.wo[win].wrap = false
    vim.wo[win].cursorline = false
    vim.wo[win].cursorcolumn = false
    vim.wo[win].statusline = "Test Runner"
    vim.wo[win].wrap = false

    -- Pretty prints the tests to the buffer
    local ns_id = vim.api.nvim_create_namespace("circle_namespace")
    local function write_line(text, spaces)
        local line_num = vim.api.nvim_buf_line_count(bufnr)

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

        vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, {res})
        vim.api.nvim_buf_set_extmark(bufnr, ns_id, line_num, spaces - 2, {
            virt_text = {{"●", "Comment"}},
            virt_text_pos = "overlay"
        })
    end

    -- This will clear the buffer and reload the tests.
    local function load(reload)
        -- Clears all text from the buffer
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})
        -- Clears all extmarks from the buffer
        vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
        -- Sets cursor to the first line
        vim.api.nvim_win_set_cursor(win, {1, 0})

        -- Load the tests
        local sln = solution.get_solution()
        if sln == nil then
            print("No solution found")
            return
        end
        if reload or M.tests == nil or #M.tests == 0 then
            load_tests()
        end
        if M.tests == nil or #M.tests == 0 then
            print("No tests found")
            return
        end

        -- Write the tests to the buffer
        for _, t in ipairs(M.tests) do
            if #t.tests ~= 0 then
                write_line(t.proj_file, 2)
                for _, test in ipairs(t.tests) do
                    write_line(test, 4)
                end
            end
        end
    end

    vim.api.nvim_buf_set_keymap(bufnr, "n", "<CR>", "", {
        noremap = true,
        silent = true,
        callback = run_test
    })
    vim.api.nvim_buf_set_keymap(bufnr, "n", "r", "", {
        noremap = true,
        silent = true,
        callback = function()
            load(true)
        end
    })
    vim.api.nvim_buf_set_option(0, "cursorline", true)

    load(false)

end

return M
