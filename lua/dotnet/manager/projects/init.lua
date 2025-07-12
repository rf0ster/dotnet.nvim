-- Description: This module provides functionality to open a window for managing projects in a .NET solution.
-- It includes options to build, clean, restore, and delete projects.

local M = {}

function M.open()
    local sln_info = require("dotnet.manager").load_solution()
    if not sln_info then
        return
    end

    local dotnet_cli = require("dotnet.cli")
    local dotnet_nuget_project = require("dotnet.nuget.project")

    local finders = require "telescope.finders"
    local pickers = require "telescope.pickers"
    local sorters = require "telescope.sorters"
    local actions_state = require "telescope.actions.state"

    local prompt_title = sln_info.sln_name
    local results_title = "Projects (n)uget - (b)uild - (c)lean - (r)estore - (d)elete"

    -- Create a finder that lists all projects in the solution
    local finder = finders.new_table {
        results = vim.tbl_map(function(cmd)
            return cmd.name
        end, sln_info.projects or {}),
    }

    pickers.new({}, {
        initial_mode = "normal",
        prompt_title = prompt_title,
        results_title = results_title,
        finder = finder,
        sorter = sorters.get_generic_fuzzy_sorter(),
        sorting_strategy = "ascending",
        layout_strategy = "vertical",
        layout_config = {
            prompt_position = "top",
            width = 0.5,
            height = 0.5,
        },
        attach_mappings = function(_, map)
            map("n", "n", function()
                local project = actions_state.get_selected_entry().value
                dotnet_nuget_project.open(project)
            end)
            map("n", "b", function()
                local project = actions_state.get_selected_entry().value
                dotnet_cli.build(project)
            end)
            map("n", "c", function()
                local project = actions_state.get_selected_entry().value
                dotnet_cli.clean(project)
            end)
            map("n", "r", function()
                local project = actions_state.get_selected_entry().value
                dotnet_cli.restore(project)
            end)
            map("n", "d", function()
                local project = actions_state.get_selected_entry().value
                dotnet_cli.delete_project(project)
            end)
            return true
        end,
    }):find()
end

return M
