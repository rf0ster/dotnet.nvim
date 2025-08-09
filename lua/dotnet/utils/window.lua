local M = {}

function M.close(win)
    if win and vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
    end
end

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

function M.centered_dimensions(centered_percentage)
    centered_percentage = centered_percentage or 0.8
    return {
        width = math.floor(vim.o.columns * centered_percentage),
        height = math.floor(vim.o.lines * centered_percentage),
        row = math.floor((vim.o.lines - vim.o.lines * centered_percentage) / 2),
        col = math.floor((vim.o.columns - vim.o.columns * centered_percentage) / 2),
    }
end

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

return M
