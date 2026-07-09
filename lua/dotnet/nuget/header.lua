-- Creates the header component for the nuget manager UIs.
--
-- * header ***********************
-- * browse | installed | updates *
-- ********************************
-- * search     * view            *
-- **************                 *
-- * packages   *                 *
-- *            *                 *
-- ********************************
-- * output                       *
-- ********************************

local M = {}

local config = require "dotnet.nuget.config"
local windows = require "dotnet.nuget.windows"
local buffer = require "dotnet.utils.buffer"

local ns_tabs = vim.api.nvim_create_namespace("dotnet_nuget_header_tabs")
local ns_prerelease = vim.api.nvim_create_namespace("dotnet_nuget_header_prerelease")

--- Opens the header window with a tab bar and an optional prerelease indicator.
--- @param opts table Options:
---   - title (string): The window title.
---   - tabs (table): List of { key, label } entries, e.g. { key = "B", label = "Browse" }.
---   - prerelease (boolean|nil): When not nil, shows the (P)rerelease yes/no
---     indicator with the active choice highlighted.
--- @return table A table with:
---   - bufnr, win: The header buffer and window.
---   - tab (function): Highlights the tab at the given zero-based index.
function M.open(opts)
    opts = opts or {}
    local tabs = opts.tabs or {}

    local d = windows.get_dimensions()

    local header_bufnr = vim.api.nvim_create_buf(false, true)
    local header_win = vim.api.nvim_open_win(header_bufnr, true, {
        title = opts.title or "NugetManager",
        relative = "editor",
        style = config.opts.ui.style,
        border = config.opts.ui.border,
        height = d.header.height,
        width = d.header.width,
        row = d.header.row,
        col = d.header.col,
    })

    -- Build the tab bar, tracking each tab's start/end byte columns
    -- so highlights don't need pattern matching.
    local text = "  "
    local tab_spans = {}
    for i, tab in ipairs(tabs) do
        if i > 1 then
            text = text .. "  |  "
        end
        local display = "(" .. tab.key .. ")" .. tab.label:sub(2)
        table.insert(tab_spans, { start_col = #text - 1, end_col = #text + #display + 1 })
        text = text .. display
    end
    text = text .. "  "

    -- Build the prerelease indicator with the active choice highlighted.
    local pre_span
    if opts.prerelease ~= nil then
        local pre_text = "(P)rerelease: "
        local choice = opts.prerelease and "yes" or "no"
        local pre_start = #pre_text
        pre_text = pre_text .. choice .. "  "

        local padding = string.rep(" ", math.max(0, d.header.width - #text - #pre_text))
        pre_span = { start_col = #text + #padding + pre_start, end_col = #text + #padding + pre_start + #choice }
        text = text .. padding .. pre_text
    end

    vim.api.nvim_buf_set_lines(header_bufnr, 0, -1, false, { text })

    if pre_span then
        vim.api.nvim_buf_add_highlight(header_bufnr, ns_prerelease, "Visual", 0, pre_span.start_col, pre_span.end_col)
    end

    --- Highlights the tab at the given zero-based index as active.
    local function tab(idx)
        local span = tab_spans[idx + 1]
        if not span then
            return
        end

        buffer.set_modifiable(header_bufnr, true)
        vim.api.nvim_buf_clear_namespace(header_bufnr, ns_tabs, 0, -1)
        vim.api.nvim_buf_add_highlight(header_bufnr, ns_tabs, "Visual", 0, span.start_col, span.end_col)
        buffer.set_modifiable(header_bufnr, false)
    end

    return {
        bufnr = header_bufnr,
        win = header_win,
        tab = tab,
    }
end

return M
