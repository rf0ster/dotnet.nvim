local M = {}

local utils = require "dotnet.utils"

function M.create(opts)
    local defaults = {
        title = "Picker",
        values = {},
        win_opts = utils.center_win(0.5, 0.5),
        on_change = function(val) print(val) end,
        display = function(val) return val end,
    }

    opts = opts or {}
    for k, v in pairs(opts) do
        defaults[k] = v
    end

    local bufnr, win_id = utils.float_win(defaults.title, defaults.win_opts)
    vim.api.nvim_buf_set_option(bufnr, "buftype", "nofile")
    vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
    vim.api.nvim_buf_set_option(bufnr, "cursorline", true)

    local values = {}
    vim.api.nvim_create_autocmd("CursorMoved", {
        buffer = bufnr,
        callback = function()
            -- Assumes that the row number is the index of the value in the values table
            local row = vim.api.nvim_win_get_cursor(win_id)[1]
            if row <= #values then
                defaults.on_change(values[row])
            end
        end
    })

    -- assumes values is a table 
    local set_values = function(vals)
        values = vals or {}

        local display_values = {}
        for _, val in ipairs(values) do
            table.insert(display_values, defaults.display(val))
        end

        vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})
        vim.api.nvim_buf_set_lines(bufnr, 0, 0, false, display_values)
        vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
        vim.api.nvim_win_set_cursor(win_id, { 1, 0 })

        -- Call on_change for the first value
        if #values > 0 then
            defaults.on_change(values[1])
        else
            defaults.on_change(nil)
        end
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
