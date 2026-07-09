local M = {}

--- Closes the specified window if it is valid.
--- @param win number: Window number to close.
function M.close(win)
    if win and vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
    end
end

--- Creates a floating window with the specified options.
--- @param opts table: Options for the floating window.
---   - width (number): Width of the window.
---   - height (number): Height of the window.
---   - row (number): Row position of the window.
---   - col (number): Column position of the window.
---   - title (string): Title of the window.
---   - relative (string): Relative position for the window (default: "editor").
---   - border (string): Border style for the window (default: "rounded").
---   - style (string): Style of the window (default: "minimal").
--- @return number, number: Buffer number and window number of the created floating window.
function M.create(opts)
    opts = opts or {}
    local default_dim = M.centered_dimensions(opts.centered_percentage)

    local w = opts.width or default_dim.width
    local h = opts.height or default_dim.height
    local r = opts.row or default_dim.row
    local c = opts.col or default_dim.col

    local bufnr = vim.api.nvim_create_buf(false, true)
    local win = vim.api.nvim_open_win(bufnr, true, {
        title = opts.title,
        relative = opts.relative or "editor",
        border = opts.border or "rounded",
        style = opts.style or "minimal",
        width = w,
        height = h,
        row = r,
        col = c,
    })

    return bufnr, win
end

--- Creates dimensions for a centered floating window based on the current editor size.
--- @param centered_percentage number|nil: Percentage of the editor size to use for the window (default: 0.8).
--- @return table: A table containing the width, height, row, and column for the centered window.
---   - width (number): Width of the window.
---   - height (number): Height of the window.
---   - row (number): Row position of the window.
---   - col (number): Column position of the window.
function M.centered_dimensions(centered_percentage)
    centered_percentage = centered_percentage or 0.8
    return {
        width = math.floor(vim.o.columns * centered_percentage),
        height = math.floor(vim.o.lines * centered_percentage),
        row = math.floor((vim.o.lines - vim.o.lines * centered_percentage) / 2),
        col = math.floor((vim.o.columns - vim.o.columns * centered_percentage) / 2),
    }
end

--- Sets the cursor to the end of the buffer in the specified window.
--- @param win number: Window number where the cursor should be set.
function M.set_cursor_end(win)
    if win and vim.api.nvim_win_is_valid(win) then
        local bufnr = vim.api.nvim_win_get_buf(win)
        if not vim.api.nvim_buf_is_valid(bufnr) then
            return
        end
        local line_count = vim.api.nvim_buf_line_count(bufnr)
        if line_count > 0 then
            vim.api.nvim_win_set_cursor(win, { line_count, 0 })
        end
    end
end

--- Gets the current dimensions of the specified window.
--- @param win number: Window number to get dimensions for.
--- @return table|nil: A table containing the width, height, row, and column of the window, or nil if the window is invalid.
---  - width (number): Width of the window.
---  - height (number): Height of the window.
---  - row (number): Row position of the window.
---  - col (number): Column position of the window.
---  - nil if the window is invalid.
function M.get_dimensions(win)
    if not win or not vim.api.nvim_win_is_valid(win) then
        return nil
    end
    local config = vim.api.nvim_win_get_config(win)
    return {
        width = config.width,
        height = config.height,
        row = config.row,
        col = config.col,
    }
end

--- Returns true if the window is valid
--- @param win number The window number to check
--- @return boolean True if the window is valid, false otherwise
function M.is_valid(win)
    return win and vim.api.nvim_win_is_valid(win)
end

--- Destorys all windows in the list if they are valid.
--- @param wins table A list of window numbers to close
function M.destroy(wins)
    if not wins or type(wins) ~= "table" then
        return
    end

    for _, win in ipairs(wins) do
        M.close(win)
    end
end

return M
