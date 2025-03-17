local M = {}

local actions_state = require "telescope.actions.state"
local previewers = require "telescope.previewers"
local finders = require "telescope.finders"
local pickers = require "telescope.pickers"
local sorters = require "telescope.sorters"
local nuget = require "dotnet.nuget.api"
local utils = require "dotnet.utils"

function M.NugetManager(project)
    local win_opts = {
        relative = "editor",
        style = "minimal",
        border = "double",
        title = "NuGet Manager",
        row = 1,
        height = 10,
    }
    win_opts = utils.center_win_width(0.5, win_opts)
    local bufnr, title_win_id = utils.float_win("NuGet Manager", win_opts)


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

    local current_picker = nil
    local dynamic_finder = function(prompt)
        if not prompt or prompt == "" then
            return {}
        end
        if current_picker and current_picker.results_border then
            local height = vim.api.nvim_win_get_height(current_picker.results_border.win_id)
            return nuget.query(prompt, height)
        end
        return nuget.query(prompt, 5)
    end

    local resize_title_win = function(picker)
        if not picker then
            return
        end

        local prompt_win = picker.prompt_win
        local results_win = picker.results_win
        local preview_win = picker.preview_win

        if not prompt_win or not results_win or not preview_win then
            return
        end

        local prompt_config = vim.api.nvim_win_get_config(prompt_win)
        local results_config = vim.api.nvim_win_get_config(results_win)
        local preview_config = vim.api.nvim_win_get_config(preview_win)

        local total_w = prompt_config.width + preview_config.width
        local total_h = prompt_config.height + results_config.height

        local c, r = prompt_config.col, prompt_config.row

        vim.api.nvim_win_set_height(title_win_id, 20)
        vim.api.nvim_win_set_width(title_win_id, 10)
        vim.api.nvim_win_set_config(title_win_id, {
            relative = "editor",
            row = r - 5,
            col = c - 1,
        })
        --vim.api.nvim_win_set_option(title_win_id, "winblend", 50)
    end
    local opts = {
        layout_strategy = "horizontal"
    }
    pickers.new(opts, {
        initial_mode = "normal",
        prompt_title = "Search",
        results_title = "Results",
        finder = finders.new_dynamic {
            fn = dynamic_finder,
            entry_maker = entry_maker
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
        attach_mappings = function(prompt_bufnr, map)
            current_picker = actions_state.get_current_picker(prompt_bufnr)
            local install = function()
                local selection = actions_state.get_selected_entry()
                require "dotnet.cli".add_package(project, selection.value.id, selection.value.version)
            end

            map("i", "<CR>", install)
            map("n", "<CR>", install)

            return true
        end
    }):find()


    resize_title_win(current_picker)
end

return M
