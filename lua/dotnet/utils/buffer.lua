local M = {}

--- Normalizes a list of lines for display. Each entry is split on any
--- embedded newline into separate lines and has its carriage returns stripped,
--- so CRLF-sourced text (Windows output, API responses) never renders a stray
--- "^M" and nvim_buf_set_lines never errors on a value containing a "\n".
--- @param lines table A list of strings to normalize.
--- @return table A flat list of newline-free, carriage-return-free lines.
local function sanitize(lines)
    if type(lines) ~= "table" then
        return {}
    end

    local out = {}
    for _, line in ipairs(lines) do
        line = tostring(line):gsub("\r", "")
        if line:find("\n", 1, true) then
            for part in (line .. "\n"):gmatch("(.-)\n") do
                table.insert(out, part)
            end
        else
            table.insert(out, line)
        end
    end
    return out
end

--- This function temporarily sets the buffer to modifiable, executes the action,
--- and then restores the modifiable state.
local function buffer_write_action(bufnr, action)
    if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
        return
    end

    local modifiable = vim.api.nvim_buf_get_option(bufnr, "modifiable")
    vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
    action()
    vim.api.nvim_buf_set_option(bufnr, "modifiable", modifiable)
end

--- Reads all the lines from a buffer.
-- @param bufnr The buffer number to read from.
-- @return A table containing all the lines in the buffer.
function M.read_lines(bufnr)
    if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
        return {}
    end

    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    return lines
end

function M.delete(bufnr)
    if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
        vim.api.nvim_buf_delete(bufnr, { force = true })
    end
end

function M.set_modifiable(bufnr, modifiable)
    if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
        vim.api.nvim_buf_set_option(bufnr, "modifiable", modifiable)
    end
end

function M.clear(bufnr)
    buffer_write_action(bufnr, function()
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})
    end)
end

function M.append_lines(bufnr, lines)
    lines = sanitize(lines)
    if #lines == 0 then
        return
    end
    buffer_write_action(bufnr, function()
        -- A buffer always holds at least one line, so a freshly cleared
        -- buffer is a single empty line. Overwrite it on the first append so
        -- output does not start with a spurious blank line.
        local count = vim.api.nvim_buf_line_count(bufnr)
        local first = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1]
        if count == 1 and (first == nil or first == "") then
            vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
        else
            vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, lines)
        end
    end)
end

function M.write(bufnr, lines)
    lines = sanitize(lines)
    buffer_write_action(bufnr, function()
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    end)
end

--- Returns true if the buffer is valid
--- @param bufnr number The buffer number to check
--- @return boolean True if the buffer is valid, false otherwise
function M.is_valid(bufnr)
    return bufnr and vim.api.nvim_buf_is_valid(bufnr)
end

--- Destroys all buffers in the list if they are valid.
--- @param bufs table A list of buffer numbers to delete
function M.destroy(bufs)
    if not bufs or type(bufs) ~= "table" then
        return
    end
    for _, buf in ipairs(bufs) do
        M.delete(buf)
    end
end

return M
