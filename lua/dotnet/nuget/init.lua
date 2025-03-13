local M = {}

local previewers = require "telescope.previewers"
local finders = require "telescope.finders"
local pickers = require "telescope.pickers"
local sorters = require "telescope.sorters"
local nuget = require "dotnet.nuget.api"

function M.NugetManager()
    local previewer = previewers.new_buffer_previewer ({
        define_preview = function(self, entry)
            -- clear the buffer
            vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, {
                "ID: " .. entry.value.id,
                "Version: " .. entry.value.version,
            })
        end,
    })

    local entry_maker = function(pkg)
        return {
            value = pkg,
            display = pkg.id,
            ordinal = pkg.id,
        }
    end

    local dynamic_finder = function(prompt)
        if not prompt or prompt == "" then
            return {}
        end
        return nuget.query(prompt)
    end

    local opts = {
        layout_strategy = "horizontal"
    }
    pickers.new(opts, {
        initial_mode = "normal",
        prompt_title = "NuGet Manager",
        results_title = "Results",
        finder = finders.new_dynamic {
            fn = dynamic_finder,
            entry_maker = entry_maker,
        },
        sorter = sorters.get_generic_fuzzy_sorter(),
        sorting_strategy = "ascending",
        layout_strategy = "vertical",
        layout_config = {
            prompt_position = "top",
            width = 0.5,
            height = 0.5,
        },
        previewer = previewer,
    }):find()
end

function M.close()
	return M.window.close()
end

return M
