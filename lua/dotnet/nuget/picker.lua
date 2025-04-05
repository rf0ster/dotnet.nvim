-- Why create a custom prompt/picker?
-- I wanted to originally resuse the telescope picker, but there
-- were some limitations about how and when the picker was rendered
-- that caused problems for how I need the nuget manager to work.
--
-- I also wanted to separate the prompt and results display into
-- separate components that can be used independently.

local M = {}

local utils = require "dotnet.utils"

function M.create(opts)
    local defaults = {
        title = "Picker",
        values = {},
        win_opts = utils.center_win(0.5, 0.5),
        keymaps = {},
        on_change = function(_) end,
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

    -- get the selected value
    -- assumes the selected row is expected table index
    local values = {}
    local get_selected_value = function()
        local row = vim.api.nvim_win_get_cursor(win_id)[1]
        if row <= #values then
            return values[row]
        end
        return nil
    end

    -- set keymaps
    for _, km in ipairs(defaults.keymaps) do
        vim.keymap.set("n", km.key, function()
            km.fn(get_selected_value())
        end, { buffer = bufnr })
    end

    vim.api.nvim_create_autocmd("CursorMoved", {
        buffer = bufnr,
        callback = function()
            defaults.on_change(get_selected_value())
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
