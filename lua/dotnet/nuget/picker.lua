local M = {}

local utils = require "dotnet.utils"

function M.create(opts)
    local defaults = {
        title = "Picker",
        values = {},
        win_opts = utils.center_win(0.5, 0.5),
        on_change = function(val) print(val) end,
    }

    opts = opts or {}
    for k, v in pairs(opts) do
        defaults[k] = v
    end

    local bufnr, win_id = utils.float_win(defaults.title, defaults.win_opts)
    vim.api.nvim_buf_set_option(bufnr, "buftype", "nofile")
    vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
    vim.api.nvim_buf_set_option(bufnr, "cursorline", true)

    vim.api.nvim_create_autocmd("CursorMoved", {
        buffer = bufnr,
        callback = function()
            -- get the current line
            local line = vim.api.nvim_get_current_line()
            if not line then
                return
            end
            defaults.on_change(line)
        end
    })

    -- assumes values is a table 
    local set_values = function(values)
        vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})
        vim.api.nvim_buf_set_lines(bufnr, 0, 0, false, values)
        vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
        vim.api.nvim_win_set_cursor(win_id, { 1, 0 })
    end

    set_values(defaults.values)
    return {
        bufnr = bufnr,
        win_id = win_id,
        set_values = set_values,
        on_change = defaults.on_change,
    }
end

return M
