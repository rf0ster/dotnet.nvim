local M = {}

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
    buffer_write_action(bufnr, function()
        vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, lines)
    end)
end

function M.write(bufnr, lines)
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
