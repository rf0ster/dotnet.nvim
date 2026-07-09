-- Description: A single-select list modal.
-- Used by the solution-level nuget manager to pick a version from a list.

local M = {}

--- Opens a single-select modal over the current UI.
--- The window is opened with noautocmd so it can float over knotted
--- window groups without closing them.
--- @param opts table Options:
---   - title (string): The window title.
---   - items (table): List of { display, value } entries.
---   - on_select (function): Called with the selected entry's value.
---   - on_cancel (function|nil): Called when the modal is dismissed.
function M.open(opts)
    opts = opts or {}
    local items = opts.items or {}
    local on_select = opts.on_select or function(_) end
    local on_cancel = opts.on_cancel or function() end

    if #items == 0 then
        return
    end

    local hint = " <CR> select - <Esc> cancel "
    local width = #hint + 2
    for _, item in ipairs(items) do
        width = math.max(width, #item.display + 4)
    end
    local max_height = math.floor(vim.o.lines * 0.6)
    local height = math.min(#items + 2, max_height)

    local row = math.floor((vim.o.lines - height) / 4)
    local col = math.floor((vim.o.columns - width) / 2)

    local bufnr = vim.api.nvim_create_buf(false, true)
    local win = vim.api.nvim_open_win(bufnr, true, {
        relative = "editor",
        width = width,
        height = height,
        row = row,
        col = col,
        style = "minimal",
        border = "double",
        title = opts.title or "Select",
        title_pos = "left",
        noautocmd = true,
    })
    vim.wo[win].cursorline = true

    local lines = {}
    for _, item in ipairs(items) do
        table.insert(lines, " " .. item.display)
    end
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    vim.bo[bufnr].modifiable = false
    vim.api.nvim_win_set_cursor(win, { 1, 0 })

    local function close()
        if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_close(win, true)
        end
    end

    local function set_keymap(key, callback)
        vim.api.nvim_buf_set_keymap(bufnr, "n", key, "", {
            noremap = true,
            silent = true,
            callback = callback,
        })
    end

    set_keymap("<CR>", function()
        local line = vim.api.nvim_win_get_cursor(win)[1]
        local item = items[line]
        close()
        if item then
            on_select(item.value)
        else
            on_cancel()
        end
    end)
    set_keymap("<Esc>", function() close() on_cancel() end)
    set_keymap("q", function() close() on_cancel() end)
end

return M
