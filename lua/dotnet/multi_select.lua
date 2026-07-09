-- Description: A generic multi-select checkbox modal.
-- Shows a list of items with checkboxes; used for choosing a subset
-- of items (build flags, projects, etc.).

local M = {}

--- Opens a multi-select modal over the current UI.
--- The window is opened with noautocmd so it can float over knotted
--- window groups without closing them.
--- @param opts table Options:
---   - title (string): The window title.
---   - items (table): List of { display, value, checked } entries.
---   - on_confirm (function): Called with the list of selected values (may be empty).
---   - on_cancel (function|nil): Called when the modal is dismissed.
function M.open(opts)
    opts = opts or {}
    local items = opts.items or {}
    local on_confirm = opts.on_confirm or function(_) end
    local on_cancel = opts.on_cancel or function() end

    if #items == 0 then
        return
    end

    local checked = {}
    for i, item in ipairs(items) do
        checked[i] = item.checked or false
    end

    local hint = " <space> toggle - (a)ll - <CR> confirm "
    local width = #hint + 2
    for _, item in ipairs(items) do
        width = math.max(width, #item.display + 8)
    end
    local height = #items + 2

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

    local function render()
        vim.bo[bufnr].modifiable = true
        local lines = {}
        for i, item in ipairs(items) do
            local box = checked[i] and "[x]" or "[ ]"
            table.insert(lines, " " .. box .. " " .. item.display)
        end
        table.insert(lines, "")
        table.insert(lines, hint)
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
        vim.bo[bufnr].modifiable = false
    end
    render()
    vim.api.nvim_win_set_cursor(win, { 1, 0 })

    local function toggle_current()
        local line = vim.api.nvim_win_get_cursor(win)[1]
        if checked[line] ~= nil then
            checked[line] = not checked[line]
            render()
        end
    end

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

    set_keymap("<Space>", toggle_current)
    set_keymap("x", toggle_current)
    set_keymap("a", function()
        local all_checked = true
        for i = 1, #items do
            if not checked[i] then
                all_checked = false
                break
            end
        end
        for i = 1, #items do
            checked[i] = not all_checked
        end
        render()
    end)
    set_keymap("<CR>", function()
        local selected = {}
        for i, item in ipairs(items) do
            if checked[i] then
                table.insert(selected, item.value)
            end
        end
        close()
        on_confirm(selected)
    end)
    set_keymap("<Esc>", function() close() on_cancel() end)
    set_keymap("q", function() close() on_cancel() end)
end

return M
