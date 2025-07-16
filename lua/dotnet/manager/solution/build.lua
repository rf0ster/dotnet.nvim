-- Description: Module that uses Telescope windows to navigate the
-- user through build configuration steps before running a build command.
local M = {}

local dotnet_cli = require "dotnet.cli"

local pickers = require "telescope.pickers"
local finders = require "telescope.finders"
local actions_state = require "telescope.actions.state"

-- Given the project name, open the build manager
-- and allow the user to configure the build.
function M.open_build(solution)
    if not solution then
        return
    end

    -- Create Telescope picker for build configuration options
    local build_options = {
        { name = "Debug",   action = function() dotnet_cli.build(solution.path_abs, "Debug") end },
        { name = "Release", action = function() dotnet_cli.build(solution.path_abs, "Release") end },
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
        prompt_title = "Build Configuration for " .. solution.name,
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
