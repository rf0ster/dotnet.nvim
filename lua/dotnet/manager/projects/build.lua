-- Description: Module that allows users to build up a dotnet build command
-- by selecting options interactively through Telescope pickers.

local M = {}

local pickers = require "telescope.pickers"
local finders = require "telescope.finders"
local actions = require "telescope.actions"
local actions_state = require "telescope.actions.state"

-- Available dotnet build options
local build_options = {
    { name = "configuration" },
    { name = "runtime" },
    { name = "framework" },
    { name = "output" },
    { name = "verbosity" },
    { name = "no-restore" },
    { name = "no-dependencies" },
    { name = "force" },
    { name = "no-incremental" },
    { name = "self-contained" },
}

-- Public function to open the build command builder
function M.open(project)
    if not project then
        return
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
        prompt_title = "Build Options for " .. project.name,
        results_title = "Select build option",
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
                actions.close(prompt_bufnr)

                -- For now, just print what was selected
                print("Selected: " .. selection.value.name)
            end)
            return true
        end,
    }):find()
end

return M
