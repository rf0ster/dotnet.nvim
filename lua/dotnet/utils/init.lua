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

-- Given a single string, splits it into a table of strings
-- based on the newline character. If you provide a bufnr,
-- it will also calculate the width of the buffer and further
-- split the string into lines based on the width of the buffer.
-- given a single string, splits it into a table of strings
-- based on the newline character. If you provide a bufnr,
-- it will also calculate the width of the buffer and further
-- split the string into lines based on the width of the buffer.
function M.smart_split(str, width, pad_left, pad_right)
    pad_left = pad_left or 0
    pad_right = pad_right or 0
    local padded_width = width - pad_left - pad_right

    local function pad(s)
        return string.rep(" ", pad_left) .. s .. string.rep(" ", pad_right)
    end

    local newline_splits = {}
    for line in str:gmatch("[^\r\n]+") do
        table.insert(newline_splits, line)
    end

    local lines = {}
    for _, line in ipairs(newline_splits) do
        if #line < padded_width then
            table.insert(lines, pad(line))
            goto continue
        end

        for i = 1, #line, padded_width do
            local l = line:sub(i, i + padded_width - 1)
            table.insert(lines, pad(l))
        end

        ::continue::
    end

    return lines
end

-- Given a table of window ids, it will set autocmds to close all
-- the given windows if any of them close. It will also close all
-- the windows if the user switches to a window that is not in the
-- list of window ids.
function M.tie_wins(win_ids)
    local buffers = {}
    for _, win_id in ipairs(win_ids) do
        local bufnr = vim.api.nvim_win_get_buf(win_id)
        table.insert(buffers, bufnr)
        vim.api.nvim_buf_set_keymap(bufnr, "n", "<esc>", ":q!<cr>", { noremap = true, silent = true })
    end

    local cmd
    local function close_all()
        for _, bufnr in ipairs(buffers) do
            vim.api.nvim_clear_autocmds({ buffer = bufnr })
        end
        if cmd then
            vim.api.nvim_del_autocmd(cmd)
        end


        for _, win_id in ipairs(win_ids) do
            if vim.api.nvim_win_is_valid(win_id) then
                vim.api.nvim_win_close(win_id, true)
            end
        end
    end

    for _, bufnr in ipairs(buffers) do
        vim.api.nvim_create_autocmd("WinClosed", {
            buffer = bufnr,
            callback = close_all,
        })
    end

    cmd = vim.api.nvim_create_autocmd("WinEnter", {
        pattern = "*",
        callback = function()
            local win_id = vim.api.nvim_get_current_win()
            if not vim.tbl_contains(win_ids, win_id) then
                close_all()
            end
        end
    })
end

return M
