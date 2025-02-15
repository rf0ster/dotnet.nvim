local M = {}

local actions_state = require "telescope.actions.state"
local actions       = require "telescope.actions"
local confirmation  = require "dotnet.confirmation"
local solution      = require "dotnet.solution"
local picker        = require "dotnet.picker"
local cli           = require "dotnet.cli"

function M.open()
    local sln_info = solution.get_solution()
    if not sln_info then
        return
    end

    local function add_project(project_name)
        local p_name = project_name .. '/' .. project_name .. ".csproj"
        cli.sln_add(sln_info.file, p_name)
        solution.load_projects()
        vim.notify(p_name .. " added to " .. sln_info.name)
    end

    local commands = {
        {
            name = "Build",
            on_execute = function()
                cli.build(sln_info.file)
            end
        },
        {
            name = "Clean",
            on_execute = function()
                cli.clean(sln_info.file)
            end
        },
        {
            name = "Restore",
            on_execute = function()
                cli.restore(sln_info.file)
            end
        },
        {
            name = "Test",
            on_execute = function()
                cli.mstest(sln_info.file)
            end
        },
        {
            name = "Add project",
            on_execute = function()
                print("Add project")
            end
        },
        {
            name = "New console",
            on_execute = function()
                local project_name = vim.fn.input("Project name: ")
                cli.new_console(project_name)
                add_project(project_name)
            end
        },
        {
            name = "New classlib",
            on_execute = function()
                local project_name = vim.fn.input("Project name: ")
                cli.new_classlib(project_name)
                add_project(project_name)
            end
        },
        {
            name = "New web",
            on_execute = function()
                local project_name = vim.fn.input("Project name: ")
                cli.new_web(project_name)
                add_project(project_name)
            end
        },
        {
            name = "New mvc",
            on_execute = function()
                local project_name = vim.fn.input("Project name: ")
                cli.new_mvc(project_name)
                add_project(project_name)
            end
        },
        {
            name = "New mstest",
            on_execute = function()
                local project_name = vim.fn.input("Project name: ")
                cli.new_mstest(project_name)
                add_project(project_name)
            end
        }
    }

    local results = {}
    for _, command in ipairs(commands) do
        table.insert(results, command.name)
    end

    picker.picker({
        prompt_title = sln_info.name,
        results_title = "Options",
        finder = require "telescope.finders".new_table {
            results = results
        },
        attach_mappings = function(_, map)
            map("n", "<CR>", function(prompt_bufnr)
                local selection = actions_state.get_selected_entry().value
                for _, command in ipairs(commands) do
                    if command.name == selection then
                        command.on_execute()
                        break
                    end
                end
                pcall(actions.close, prompt_bufnr)
            end)
            return true
        end
    })
end

function M.open_projects()
    local sln_info = solution.get_solution()
    if not sln_info then
        return
    end

    local sln_projects = solution.get_projects()
    if not sln_projects then
        return
    end

    local projects = {}
    for _, project in ipairs(sln_projects) do
        table.insert(projects, project.name)
    end

    local function project_file(proj_name)
        for _, project in ipairs(sln_projects) do
            if project.name == proj_name then
                return project.file
            end
        end

        return nil
    end


    picker.picker({
        prompt_title = sln_info.name,
        results_title = "Projects (b)uild - (r)estore - (c)lean - (d)elete",
        items = projects,
        maps = {
            {
                mode = "n",
                key = "<CR>",
                fn = function (prompt_buffrn)
                    local selection = actions_state.get_selected_entry()
                    actions.close(prompt_buffrn)
                    vim.api.nvim_command("e " .. project_file(selection.value))
                end
            },
            {
                mode = "n",
                key = "b",
                fn = function()
                    local selection = actions_state.get_selected_entry()
                    cli.build(project_file(selection.value))
                end
            },
            {
                mode = "n",
                key = "c",
                fn = function()
                    local selection = actions_state.get_selected_entry()
                    cli.clean(project_file(selection.value))
                end
            },
            {
                mode = "n",
                key = "r",
                fn = function()
                    local selection = actions_state.get_selected_entry()
                    cli.restore(project_file(selection.value))
                end
            },
            {
                mode = "n",
                key = "d",
                fn = function()
                    local selection = actions_state.get_selected_entry()
                    local prompt ="Delete " .. selection.value ..  " from " .. sln_info.name .. "?"
                    confirmation.open({
                        prompt_title = "Delete Project",
                        prompt = {prompt},
                        on_close = function(answer)
                            if answer == "yes" then
                                cli.sln_remove(sln_info.name, project_file(selection.value))
                                solution.load_projects()
                            end
                        end
                    })
                end
            }
        },
    })
end

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
end

return M
