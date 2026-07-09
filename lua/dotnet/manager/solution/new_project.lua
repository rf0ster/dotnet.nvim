-- Description: Module that walks the user through creating a new project
-- from a dotnet template and adding it to the solution.

local M = {}

local dotnet_manager = require "dotnet.manager"
local manager_cli = require "dotnet.manager.cli"

local templates = {
    { name = "Console",        template = "console" },
    { name = "Class library",  template = "classlib" },
    { name = "MSTest",         template = "mstest" },
    { name = "xUnit",          template = "xunit" },
    { name = "NUnit",          template = "nunit" },
    { name = "Web (empty)",    template = "web" },
    { name = "Web API",        template = "webapi" },
    { name = "MVC",            template = "mvc" },
    { name = "Blazor",         template = "blazor" },
    { name = "Worker service", template = "worker" },
}

--- Creates the project from the given template and adds it to the solution.
--- Paths are resolved against the solution directory so the result is the
--- same no matter what nvim's current working directory is.
--- @param sln table The loaded solution.
--- @param template string The dotnet template short name.
local function create_project(sln, template)
    local name = vim.fn.input("Project name: ")
    if name == "" then
        vim.api.nvim_echo({{"[Error] Project name cannot be empty", "ErrorMsg"}}, true, {})
        return
    end

    local sln_dir = vim.fn.fnamemodify(sln.sln_path_abs, ":h")
    local output = vim.fn.input("Output dir, relative to solution (default " .. name .. "): ")
    if output == "" then
        output = name
    end
    output = vim.fs.normalize(sln_dir .. "/" .. output)

    local cli = manager_cli.get_cli()
    cli:new_project(template, name, output)
    cli:sln_add(sln.sln_path_abs, output .. "/" .. name .. ".csproj")
    dotnet_manager.load_solution()
end

--- Opens a picker of project templates to create a new project.
--- @param sln table The loaded solution.
function M.open(sln)
    if not sln then
        return
    end

    local finders = require "telescope.finders"
    local pickers = require "telescope.pickers"
    local sorters = require "telescope.sorters"
    local actions = require "telescope.actions"
    local actions_state = require "telescope.actions.state"

    pickers.new({}, {
        initial_mode = "normal",
        prompt_title = "New project for " .. sln.sln_name,
        results_title = "Project templates",
        finder = finders.new_table {
            results = templates,
            entry_maker = function(entry)
                return {
                    value = entry,
                    display = entry.name,
                    ordinal = entry.name,
                }
            end,
        },
        sorter = sorters.get_generic_fuzzy_sorter(),
        sorting_strategy = "ascending",
        layout_strategy = "vertical",
        layout_config = {
            prompt_position = "top",
            width = 0.5,
            height = 0.5,
        },
        attach_mappings = function(_, map)
            map("n", "<CR>", function(prompt_bufnr)
                local selection = actions_state.get_selected_entry()
                pcall(actions.close, prompt_bufnr)
                if not selection then
                    return
                end
                create_project(sln, selection.value.template)
            end)
            return true
        end,
    }):find()
end

return M
