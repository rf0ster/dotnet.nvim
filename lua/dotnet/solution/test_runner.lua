local M  = {
}

local solution = require "dotnet.solution"

function M.open_tests()

    local sln_info = solution.get_solution()
    if not sln_info then
        return
    end

    local sln_projects = solution.get_projects()
    if not sln_projects then
        return
    end

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
        title = sln_info.name .. " - Test Runner"
    })
    vim.wo[win].wrap = false
    vim.wo[win].cursorline = false
    vim.wo[win].cursorcolumn = false
    vim.wo[win].statusline = "Test Runner"
    vim.wo[win].wrap = false

    local function write_line(line)
        vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, {"  " .. line})
    end

    local projects = solution.load_tests_all()
    if not projects then
        return
    end

    for _, p in ipairs(projects) do
        if #p.tests ~= 0 then
            write_line("Project: " .. p.name)
            for _, test in ipairs(p.tests) do
                write_line("  " .. test)
            end
        end
    end

    local function get_project_name(line)
        -- Trim leading and trailing spaces
        line = line:match("^%s*(.-)%s*$")

        -- Check if the line contains "Project"
        if line:match("Project") then
            -- Extract the project name using pattern matching
            local project_name = line:match("Project:%s*(.-)%.csproj")

            if project_name then
                return project_name
            end
        end

        return nil  -- Return nil if no match is found
    end

    -- Funcion that will read the current line of the buffer and print
    -- the test name to the console. If the line is a project, print
    -- name of the project. If the line is a test, get the name of the
    -- test, and search up the buffer for the project name.
    local function run_test()
        local line = vim.api.nvim_get_current_line()
        if line == nil or line == "" then
            return
        end

        if line:find("Project") then
            local p = get_project_name(line)
            require "dotnet.cli".mstest(p)
        else
            local test = line:match("  (.*)")
            test = test:match("^%s*(.-)%s*$")

            local current_line = vim.api.nvim_win_get_cursor(0)[1]
            local project = nil

            for i = current_line, 1, -1 do
                local l = vim.api.nvim_buf_get_lines(bufnr, i - 1, i, false)[1]
                if l:match("Project") then
                    project = get_project_name(l)
                    break
                end
            end

            if project then
                require "dotnet.cli".mstest(project, test)
            end
        end
    end

    vim.api.nvim_buf_set_keymap(bufnr, "n", "<CR>", "", {
        noremap = true,
        silent = true,
        callback = run_test
    })
end

return M
