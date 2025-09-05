-- Description: Module that uses Telescope windows to navigate the
-- user through publish configuration steps before running a publish command.
local M = {}

local cli = require "dotnet.manager.cli".get_cli()
local runtime_selector = require "dotnet.manager.projects.runtime"
local pickers = require "telescope.pickers"
local finders = require "telescope.finders"
local actions_state = require "telescope.actions.state"

--- Given the project, open the publish manager
--- @param project table The project to open the publish manager for
function M.open(project)
    if not project then
        return
    end

    -- Create Telescope picker for publish configuration options
    local publish_options = {
        { name = "Debug",   action = function() runtime_selector.open(project, "Debug", "Publish") end },
        { name = "Release", action = function() runtime_selector.open(project, "Release", "Publish") end },
    }

    local finder = finders.new_table {
        results = publish_options,
        entry_maker = function(entry)
            return {
                value = entry,
                display = entry.name,
                ordinal = entry.name,
            }
        end,
    }

    pickers.new({}, {
        prompt_title = "Publish Configuration for " .. project.name,
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