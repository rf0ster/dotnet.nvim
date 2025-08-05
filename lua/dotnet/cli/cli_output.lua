local M = {}

local win = nil
local buf = nil
local spaces = 0 -- Count spaces and collapse consecutive empty lines

--- Deletes the previous window and buffer, if they exist.
--- Creates a new windows with the specified options.
local function reset_win(opts, cmd)
    opts = opts or {}

    if win and vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
    end
    if buf and vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_buf_delete(buf, { force = true })
    end
    win = nil
    buf = nil

    local width = opts.width or math.floor(vim.o.columns * 0.8)
    local height = opts.height or math.floor(vim.o.lines * 0.8)
    local row = opts.row or math.floor((vim.o.lines - height) / 2)
    local col = opts.col or math.floor((vim.o.columns - width) / 2)

    buf = vim.api.nvim_create_buf(false, true)
    win = vim.api.nvim_open_win(buf, true, {
        title = opts.title or ("Output - " .. (cmd or "")),
        relative = opts.relative or "editor",
        border = opts.border or "rounded",
        style = opts.style or "minimal",
        width = width,
        height = height,
        row = row,
        col = col,
    })

    require "dotnet.utils".create_knot({win})
    spaces = 0 -- Reset spaces count
end

--- Writes data to the buffer.
local function on_data_out(data)
    if not vim.api.nvim_buf_is_valid(buf) then
        return
    end
    if not data or #data == 0 then
        return
    end

    -- Create a smart split of the output data
    local split_smart = require "dotnet.utils".split_smart
    local width = vim.api.nvim_win_get_width(win)

    -- Smartly split the output lines based on the width
    local splits = {}
    for _, line in ipairs(data) do
        local split_lines = split_smart(line, width, 2, 1, 2)
        for _, split_line in ipairs(split_lines) do
            local is_space = not split_line or split_line:match("^%s*$")
            if is_space then
                spaces = spaces + 1
                if spaces % 2 == 1 then
                    table.insert(splits, "")
                end
            else
                spaces = 0
                table.insert(splits, split_line)
            end
        end
    end

    -- Ensure the buffer is modifiable before writing to it
    vim.api.nvim_buf_set_option(buf, "modifiable", true)

    -- Get the last line of the buffer to append after
    local last_line = vim.api.nvim_buf_line_count(buf)

    --- Append new lines to the buffer
    vim.api.nvim_buf_set_lines(buf, last_line, -1, false, splits)

    -- Set cursor to the end of the buffer
    last_line = vim.api.nvim_buf_line_count(buf)
    vim.api.nvim_win_set_cursor(win, { last_line, 0 })
end

function M.singleton_window(opts)
    local on_start = function(cmd) reset_win(opts, cmd) end
    local on_exit = function() end

    local on_stdout = function(_, data, _) on_data_out(data) end
    local on_stderr = function(_, data, _) on_data_out(data) end

    return {
        win = win,
        buf = buf,
        on_cmd_start = on_start,
        on_cmd_exit = on_exit,
        on_cmd_stdout = on_stdout,
        on_cmd_stderr = on_stderr,
    }
end

return M
