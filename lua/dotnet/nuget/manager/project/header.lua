-- Creates the header component for the nuget manager
-- 
-- * header ***********************
-- * browse | installed | updates *
-- ********************************
-- * search     * view            *
-- **************                 *
-- * packages   *                 *
-- *            *                 *
-- *            *                 *
-- ********************************
-- * output                       *
-- ********************************

local M = {}

local config = require "dotnet.nuget.config"
local utils = require "dotnet.utils"

function M.open()
    -- Calculate window dimensions
    local d = utils.get_centered_win_dims(
        config.opts.ui.width,
        config.opts.ui.height
    )

    -- Calculate dimensions for each component
    local header_h = 1
    local header_w = d.width
    local header_r = d.row
    local header_c = d.col

    local header_bufnr = vim.api.nvim_create_buf(false, true)
    local header_win = vim.api.nvim_open_win(header_bufnr, true, {
        title = "NugetManager",
        relative = "editor",
        style = config.opts.ui.style,
        border = config.opts.ui.border,
        height = header_h,
        width = header_w,
        row = header_r,
        col = header_c,
    })

    -- Set header content
    local text = "  (B)rowse  |  (I)nstalled  |  (U)pdates  "
    vim.api.nvim_buf_set_lines(header_bufnr, 0, -1, false, {text})

    local function tab(opt)
        local opt_text
        if opt == 0 then
            opt_text = "(B)rowse"
        elseif opt == 1 then
            opt_text = "(I)nstalled"
        elseif opt == 2 then
            opt_text = "(U)pdates"
        else
            return
        end

        -- clear the old highlight
        vim.api.nvim_buf_clear_namespace(header_bufnr, -1, 0, -1)

        -- add a % char in front of each ( and ) in the opt_text to escape them
        local opt_text_esc = opt_text:gsub("%(", "%%("):gsub("%)", "%%)")

        -- add a highlight to the selected option
        local start_col = text:find(opt_text_esc) - 2
        local end_col = start_col + #opt_text + 2
        vim.api.nvim_buf_add_highlight(header_bufnr, -1, "Visual", 0, start_col, end_col)

    end

    return {
        bufnr = header_bufnr,
        win = header_win,
        tab = tab,
    }
end

return M

