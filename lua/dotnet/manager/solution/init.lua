-- Description: This module provides functions to create a window for managing a .NET solution.
-- The window includes options to build, rebuild, clean, restore, and test the solution.
-- It also allows creating, adding, and removing projects.

local M = {}

local dotnet_manager_solution_build = require("dotnet.manager.solution.build")
local dotnet_manager_solution_add_existing = require("dotnet.manager.solution.add_existing")
local dotnet_manager_solution_new_project = require("dotnet.manager.solution.new_project")
local dotnet_confirm = require("dotnet.confirm")
local cli = require "dotnet.manager.cli".get_cli()

function M.create()
    dotnet_confirm.open({
        prompt = { "No solution file found. Do you want to create a new solution?" },
        on_confirm = function()
            local sln_name = vim.fn.input("Solution name: ")

            if sln_name == "" then
                vim.api.nvim_echo({{"[Error] Solution name cannot be empty", "ErrorMsg"}}, true, {})
                return
            end

            cli:new_solution(sln_name)
        end,
    })
end

--- Opens a picker of the solution's projects and removes the selected one
--- after confirmation.
--- @param sln table The loaded solution.
local function remove_project(sln)
    local finders = require "telescope.finders"
    local pickers = require "telescope.pickers"
    local sorters = require "telescope.sorters"
    local actions = require "telescope.actions"
    local actions_state = require "telescope.actions.state"

    pickers.new({}, {
        initial_mode = "normal",
        prompt_title = "Remove project from " .. sln.sln_name,
        results_title = "Projects",
        finder = finders.new_table {
            results = sln.projects or {},
            entry_maker = function(entry)
                return {
                    value = entry,
                    display = entry.name .. " " .. entry.path_rel,
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

                local project = selection.value
                dotnet_confirm.open({
                    prompt_title = "Remove Project",
                    prompt = { "Remove " .. project.path_rel .. " from " .. sln.sln_name .. "?" },
                    on_confirm = function()
                        cli:sln_remove(sln.sln_path_abs, project.path_abs)
                        require "dotnet.manager".load_solution()
                    end,
                })
            end)
            return true
        end,
    }):find()
end

function M.open()
    local sln = require "dotnet.manager".load_solution()
    if not sln then
        return
    end

    local commands = {
        { name = "Build",                key = "b", on_execute = function() dotnet_manager_solution_build.open(sln) end },
        { name = "Rebuild",              key = "B", on_execute = function() dotnet_manager_solution_build.open(sln, "Rebuild") end },
        { name = "Clean",                key = "c", on_execute = function() cli:clean(sln.sln_path_abs) end },
        { name = "Restore",              key = "r", on_execute = function() cli:restore(sln.sln_path_abs) end },
        { name = "Test",                 key = "t", on_execute = function() cli:mstest(sln.sln_path_abs) end },
        { name = "NuGet",                key = "g", on_execute = function() require "dotnet.nuget.solution".open() end },
        { name = "New project",          key = "n", on_execute = function() dotnet_manager_solution_new_project.open(sln) end },
        { name = "Add existing project", key = "a", on_execute = function() dotnet_manager_solution_add_existing.open(sln) end },
        { name = "Remove project",       key = "d", on_execute = function() remove_project(sln) end },
    }

    local finders = require "telescope.finders"
    local pickers = require "telescope.pickers"
    local sorters = require "telescope.sorters"
    local actions = require "telescope.actions"
    local actions_state = require "telescope.actions.state"

    pickers.new({}, {
        initial_mode = "normal",
        prompt_title = sln.sln_name,
        -- No results title: the hotkeys are shown next to each option
        results_title = false,
        finder = finders.new_table {
            results = commands,
            entry_maker = function(entry)
                return {
                    value = entry,
                    display = "(" .. entry.key .. ") " .. entry.name,
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
                if selection then
                    selection.value.on_execute()
                end
            end)
            for _, command in ipairs(commands) do
                map("n", command.key, function(prompt_bufnr)
                    pcall(actions.close, prompt_bufnr)
                    command.on_execute()
                end)
            end
            return true
        end,
    }):find()
end

return M
