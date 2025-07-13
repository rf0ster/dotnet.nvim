-- Description: This module provides functionality to open a window for managing projects in a .NET solution.
-- It includes options to build, clean, restore, and delete projects.

local M = {}

local dotnet_cli = require("dotnet.cli")
local dotnet_manager = require("dotnet.manager")
local dotnet_nuget_project = require("dotnet.nuget.project")
local dotnet_confirm = require "dotnet.confirm"

local finders = require "telescope.finders"
local pickers = require "telescope.pickers"
local sorters = require "telescope.sorters"
local actions = require "telescope.actions"
local actions_state = require "telescope.actions.state"

function M.open()
    local sln_info = dotnet_manager.load_solution()
    if not sln_info then
        return
    end

    local prompt_title = sln_info.sln_name
    local results_title = "Projects (n)uget - (b)uild - (c)lean - (r)estore - (d)elete"

    -- Create a finder that lists all projects in the solution
    local finder = finders.new_table {
        results = vim.tbl_map(function(cmd)
            return cmd.name
        end, sln_info.projects or {}),
    }

    local function get_project_info()
        local project = actions_state.get_selected_entry().value
        local project_info = dotnet_manager.get_project(project)
        if not project_info then
            return nil
        end
        return project_info
    end

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
            map("n", "<CR>", function(prompt_buffrn)
                local project = get_project_info()
                actions.close(prompt_buffrn)

                if not project then
                    return
                end
                vim.api.nvim_command("e " .. project.path_abs)
            end)
            map("n", "n", function()
                local project = get_project_info()
                if not project then
                    return
                end
                dotnet_nuget_project.open(project.path_abs)
            end)
            map("n", "b", function()
                local project = get_project_info()
                if not project then
                    return
                end
                require "dotnet.manager.projects.build".open_build(project)
            end)
            map("n", "c", function()
                local project = get_project_info()
                if not project then
                    return
                end
                dotnet_cli.clean(project.path_abs)
            end)
            map("n", "r", function()
                local project = get_project_info()
                if not project then
                    return
                end
                dotnet_cli.restore(project.path_abs)
            end)
            map("n", "d", function()
                local project = get_project_info()
                if not project then
                    return
                end

                dotnet_confirm.open({
                    prompt_title = "Delete Project",
                    prompt = {"Delete " .. project.path_rel ..  " from " .. sln_info.sln_name .. "?"},
                    on_close = function(answer)
                        if answer == "yes" then
                            dotnet_cli.sln_remove(sln_info.sln_file, project.path_abs)
                            dotnet_manager.load_solution()
                        end
                    end
                })
            end)
            return true
        end,
    }):find()
end

return M
