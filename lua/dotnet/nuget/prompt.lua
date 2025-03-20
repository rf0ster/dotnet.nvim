local M = {}

-- Why create a custom picker?
-- I wanted to originally resuse the telescope picker, but there
-- were some limitations about how and when the picker was rendered
-- that caused problems for how I need the nuget manager to work.
--
-- I also wanted to separate the prompt and results display into
-- separate components that can be used independently.

local utils = require "dotnet.utils"

function M.create(opts)
    -- default options
    local win_opts = utils.center_win(0.5, 0.5)
    win_opts.height = 1

    local defaults = {
        title = "Prompt",
        win_opts = win_opts,
        debounce = 200,
        on_change = function(_) end,
    }

    -- override defaults with user options
    opts = opts or {}
    for k, v in pairs(opts) do
        defaults[k] = v
    end

    local bufnr, win_id = utils.float_win(defaults.title, defaults.win_opts) -- creates a floating window
    vim.api.nvim_buf_set_option(bufnr, "buftype", "nofile")
    vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
    vim.api.nvim_buf_set_keymap(bufnr, 'i', '<CR>', '<NOP>', { noremap = true, silent = true })
    vim.api.nvim_buf_set_keymap(bufnr, 'n', 'o', '<NOP>', { noremap = true, silent = true })
    vim.api.nvim_buf_set_keymap(bufnr, 'n', 'O', '<NOP>', { noremap = true, silent = true })
    vim.api.nvim_buf_set_keymap(bufnr, 'n', 'p', '<NOP>', { noremap = true, silent = true })
    vim.api.nvim_buf_set_keymap(bufnr, 'n', 'P', '<NOP>', { noremap = true, silent = true })

    local wrapped_on_change = function()
        local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
        if not lines or #lines == 0 then
            return
        end

        defaults.on_change(lines[1])
    end

    local debounce_timer = nil
    vim.api.nvim_create_autocmd("TextChangedI", {
        buffer = bufnr,
        callback = function()
            if defaults.debounce == 0 then
                wrapped_on_change()
                return
            end

            if debounce_timer then
                vim.fn.timer_stop(debounce_timer)
            end
            debounce_timer = vim.fn.timer_start(defaults.debounce, function()
                wrapped_on_change()
                debounce_timer = nil
            end)
        end
    })

    return {
        bufnr = bufnr,
        win_id = win_id,
    }
end

return M
