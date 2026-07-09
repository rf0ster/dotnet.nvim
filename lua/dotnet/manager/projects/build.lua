-- Description: Module that uses Telescope windows to navigate the
-- user through build configuration steps before running a build command.
local M = {}

local pickers = require "telescope.pickers"
local finders = require "telescope.finders"
local actions = require "telescope.actions"
local actions_state = require "telescope.actions.state"
local build_wizard = require "dotnet.manager.projects.build_wizard"
local manager_cli = require "dotnet.manager.cli"

--- Given the project, open the build manager.
--- Debug and Release build right away; Custom opens the step-by-step
--- wizard (which starts with the Debug/Release choice).
--- @param project table The project to open the build manager for
--- @param operation string|nil The operation to run: "Build" (default) or "Rebuild"
function M.open(project, operation)
    if not project then
        return
    end
    operation = operation or "Build"

    local cli = manager_cli.get_cli()
    local build_options
    if operation == "Rebuild" then
        build_options = {
            { name = "Debug",   action = function() cli:rebuild(project.path_abs, "Debug") end },
            { name = "Release", action = function() cli:rebuild(project.path_abs, "Release") end },
        }
    else
        build_options = {
            { name = "Debug",   action = function() cli:build(project.path_abs, "Debug") end },
            { name = "Release", action = function() cli:build(project.path_abs, "Release") end },
            { name = "Custom",  action = function() build_wizard.open(project) end },
        }
    end

    local finder = finders.new_table {
        results = build_options,
        entry_maker = function(entry)
            return {
                value = entry,
                display = entry.name,
                ordinal = entry.name,
            }
        end,
    }

    pickers.new({}, {
        prompt_title = operation .. " Configuration for " .. project.name,
        initial_mode = "normal",
        finder = finder,
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
                    selection.value.action()
                end
            end)
            return true
        end,
    }):find()
end

return M
