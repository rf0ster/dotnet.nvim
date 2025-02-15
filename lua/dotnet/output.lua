-- Dontnet plugin manages a single output window for commands that need to be displayed to the user.
-- This module is responsible for running commands and displaying the output in a new window by tracking
-- a singles output window at a time and closing it when a new command is run.
local M = {
    -- Tracks the current output window.
    -- This is used to close the window when a new command is run.
    win_id = nil
}

-- Removes the current output window from vim.
function M.clear()
    if M.win_id then
        pcall(vim.api.nvim_win_close, M.win_id, true)
        M.win_id = nil
    end
end

-- Runs a command and displays the output in a new window.
-- param cmd: The command to run.
function M.run_cmd(cmd)
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

    vim.wo[win].wrap = false
    vim.wo[win].cursorline = false
    vim.wo[win].cursorcolumn = false
    vim.wo[win].statusline = "Output"
    vim.wo[win].wrap = false
    M.clear()
    M.win_id = win

    local function on_output(_, data, _)
        if data then
            for _, line in ipairs(data) do
                if line:match("^%s*$") then
                    line = ""
                end

                if line ~= "" then
                    -- Replace carriage return (^M) with nothing
                    -- Is this only on windows??
                    line = string.gsub(line, "\r", "")
                    -- Trim leading and trailing whitespace
                    line = line:gsub("^%s+", ""):gsub("%s+$", "")
                    -- Add indentation
                    line = " " .. line
                end
                vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, {line})
            end
        end

        local last_line = vim.api.nvim_buf_line_count(bufnr)
        vim.api.nvim_win_set_cursor(0, {last_line, 0})
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
