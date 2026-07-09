-- Description: Module that uses Telescope windows to navigate the
-- user through build configuration steps before running a build command.
local M = {}

local pickers = require "telescope.pickers"
local finders = require "telescope.finders"
local actions_state = require "telescope.actions.state"
local manager_cli = require "dotnet.manager.cli"

--- Given the solution, open the build manager
--- @param solution table The solution to open the build manager for
--- @param operation string|nil The operation to run: "Build" (default) or "Rebuild"
function M.open(solution, operation)
    if not solution then
        return
    end
    operation = operation or "Build"

    local cli = manager_cli.get_cli()
    local function run(configuration)
        if operation == "Rebuild" then
            cli:rebuild(solution.sln_path_abs, configuration)
        else
            cli:build(solution.sln_path_abs, configuration)
        end
    end

    -- Create Telescope picker for build configuration options
    local build_options = {
        { name = "Debug",   action = function() run("Debug") end },
        { name = "Release", action = function() run("Release") end },
    }

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
        prompt_title = operation .. " Configuration for " .. solution.sln_name,
        initial_mode = "normal",
        finder = finder,
        layout_strategy = "vertical",
        layout_config = {
            prompt_position = "top",
            width = 0.5,
            height = 0.5,
        },
        attach_mappings = function(_, map)
            map("n", "<CR>", function()
                local selection = actions_state.get_selected_entry()
                selection.value.action()
            end)
            return true
        end,
    }):find()
end

return M
