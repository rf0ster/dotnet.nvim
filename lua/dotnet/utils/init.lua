local M = {}

function M.float_win(title, opts)
    local win_opts = {
        relative = "editor",
        style = "minimal",
        border = "double",
        title = title,
    }

    opts = opts or {}
    for k, v in pairs(opts) do
        win_opts[k] = v
    end

    local bufnr = vim.api.nvim_create_buf(false, true)
    local win_id = vim.api.nvim_open_win(bufnr, true, win_opts)

    return bufnr, win_id
end

function M.center_win(w_perc, h_perc, opts)
    opts = opts or {}

    M.center_win_width(w_perc, opts)
    M.center_win_height(h_perc, opts)

    return opts
end

function M.center_win_width(w_perc, opts)
    local w = math.floor(vim.o.columns * w_perc)
    local c = math.floor((vim.o.columns - w) / 2)

    opts = opts or {}
    opts.width = w
    opts.col = c

    return opts
end

function M.center_win_height(h_perc, opts)
    local h = math.floor(vim.o.lines * h_perc)
    local r = math.floor((vim.o.lines - h) / 2)

    opts = opts or {}
    opts.height = h
    opts.row = r

    return opts
end

return M
