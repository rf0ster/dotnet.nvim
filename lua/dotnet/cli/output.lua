-- Description: The dotnet cli module outputs all of its commands to a new window.
-- This window is tracked and cleared when a new command is run.
-- This window is automatically closed when focus shifts away from it.

local M = {
    win_id = nil
}

local utils = require("dotnet.utils")

-- Given a command, run it and display the output in a new window.
function M.run_cmd(cmd)
    if M.win_id and vim.api.nvim_win_is_valid(M.win_id) then
        vim.api.nvim_win_close(M.win_id, true)
    end
    M.win_id = nil

    -- Floating window centered in the middle of the screen.
    local width = math.floor(vim.o.columns * 0.8)
    local height = math.floor(vim.o.lines * 0.8)
    local row = math.floor((vim.o.lines - height) / 2)
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
        title = "Output - " .. cmd,
    })

    -- Set window so that the output cannot be modified.
    vim.wo[win].wrap = false
    vim.wo[win].cursorline = false
    vim.wo[win].cursorcolumn = false
    vim.wo[win].statusline = "Output"

    utils.create_knot({win})

    -- Store the window id so that it can be cleared later.
    M.win_id = win

    -- Run the command and capture the output.
    local consecutive_spaces = 0
    local function on_output(_, data, _)
        if not data then
            return
        end

        local win_width = vim.api.nvim_win_get_width(win)
        vim.api.nvim_buf_set_option(bufnr, "modifiable", true)

        for _, line in ipairs(data) do
            local smart_split = utils.smart_split(line, win_width, 2, 2)

            if #smart_split == 0 then
                consecutive_spaces = consecutive_spaces + 1
                if consecutive_spaces == 2 then
                    consecutive_spaces = 0
                    smart_split = {""}
                end
            end

            if #smart_split > 0 then
                vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, smart_split)
            end

            local last_line = vim.api.nvim_buf_line_count(bufnr)
            vim.api.nvim_win_set_cursor(0, {last_line, 0})

        end

        vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
    end

    vim.fn.jobstart(cmd, {
        on_stdout = on_output,
        on_stderr = on_output,
        on_exit = function()
            vim.bo[bufnr].modifiable = false
        end,
        stdout_buffered = false,
        stderr_buffered = false,
    })

end

return M
