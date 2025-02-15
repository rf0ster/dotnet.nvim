local M = {}

function M.picker(opts)
    require "dotnet.output".clear()

    local finders = require "telescope.finders"
    local pickers = require "telescope.pickers"
    local sorters = require "telescope.sorters"

    opts = opts or {}

    pickers.new(opts, {
        initial_mode = "normal",
        prompt_title = opts.prompt_title or "Viewer",
        results_title = opts.results_title or "Results",
        finder = finders.new_table {
            results = opts.items or {},
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
            if opts.maps then
                for _, value in ipairs(opts.maps) do
                    map(value.mode, value.key, value.fn)
                end
            end
            return true
        end,
    }):find()
end

return M
