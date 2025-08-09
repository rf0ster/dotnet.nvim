-- Description: Creates a telescope picker that loads
-- the historical commands from the .NET CLI module.
-- User can select a command to run it again.
local M = {}

function M.open()
    local cli = require "dotnet.manager.cli".get_cli()

    local finders = require "telescope.finders"
    local pickers = require "telescope.pickers"
    local sorters = require "telescope.sorters"
    local actions = require "telescope.actions"
    local actions_state = require "telescope.actions.state"

    -- Load the historical commands from the .NET CLI module.
    local commands = cli:get_history()

    pickers.new({}, {
        prompt_title = "Historical Commands",
        results_title = "Select a command to run",
        initial_mode = "normal",
        layout_strategy = "vertical",
        layout_config = {
            prompt_position = "top",
            width = 0.5,
            height = 0.5,
        },
        finder = finders.new_table {
            results = commands,
            entry_maker = function(entry)
                return {
                    value = entry,
                    display = entry.cmd,
                    ordinal = entry.cmd,
                }
            end,
        },
        sorter = sorters.get_generic_fuzzy_sorter(),
        attach_mappings = function(_, map)
            map("n", "<CR>", function(prompt_bufnr)
                local selection = actions_state.get_selected_entry()
                cli:run_cmd(selection.value.cmd)
                pcall(actions.close, prompt_bufnr)
            end)
            return true
        end,
    }):find()
end

return M

