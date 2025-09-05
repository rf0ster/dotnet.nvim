-- Description: This module provides a submenu for project-specific actions
-- when a user selects a project from the projects picker.

local M = {}

local cli = require "dotnet.manager.cli".get_cli()
local finders = require "telescope.finders"
local pickers = require "telescope.pickers"
local sorters = require "telescope.sorters"
local actions = require "telescope.actions"
local actions_state = require "telescope.actions.state"

function M.open(project)
    if not project then
        return
    end

    -- Create submenu options
    local submenu_options = {
        { name = "Open in Editor", action = function() vim.api.nvim_command("e " .. project.path_abs) end },
        { name = "Build", action = function() require "dotnet.manager.projects.build".open(project) end },
        { name = "Publish", action = function() require "dotnet.manager.projects.publish".open(project) end },
        { name = "NuGet", action = function() require "dotnet.nuget.project".open(project.path_abs) end },
        { name = "Clean", action = function() cli:clean(project.path_abs) end },
        { name = "Restore", action = function() cli:restore(project.path_abs) end },
    }

    local function entry_maker(entry)
        return {
            value = entry,
            display = entry.name,
            ordinal = entry.name,
        }
    end

    pickers.new({}, {
        prompt_title = "Project Actions: " .. project.name,
        results_title = "Select an action",
        finder = finders.new_table {
            results = submenu_options,
            entry_maker = entry_maker,
        },
        sorter = sorters.get_generic_fuzzy_sorter(),
        initial_mode = "normal",
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
                actions.close(prompt_bufnr)
                if selection and selection.value.action then
                    selection.value.action()
                end
            end)
            
            -- Keymap for each option using first letter
            map("n", "o", function(prompt_bufnr)
                actions.close(prompt_bufnr)
                vim.api.nvim_command("e " .. project.path_abs)
            end)
            
            map("n", "b", function(prompt_bufnr)
                actions.close(prompt_bufnr)
                require "dotnet.manager.projects.build".open(project)
            end)
            
            map("n", "p", function(prompt_bufnr)
                actions.close(prompt_bufnr)
                require "dotnet.manager.projects.publish".open(project)
            end)
            
            map("n", "n", function(prompt_bufnr)
                actions.close(prompt_bufnr)
                require "dotnet.nuget.project".open(project.path_abs)
            end)
            
            map("n", "c", function(prompt_bufnr)
                actions.close(prompt_bufnr)
                cli:clean(project.path_abs)
            end)
            
            map("n", "r", function(prompt_bufnr)
                actions.close(prompt_bufnr)
                cli:restore(project.path_abs)
            end)
            
            return true
        end,
    }):find()
end

return M
