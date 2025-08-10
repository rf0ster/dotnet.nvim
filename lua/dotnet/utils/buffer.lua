local M = {}

function M.delete(bufnr)
    if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
        vim.api.nvim_buf_delete(bufnr, { force = true })
    end
end

function M.clean(bufnr)
    if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
        vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})
        vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
    end
end

function M.set_modifiable(bufnr, modifiable)
    if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
        vim.api.nvim_buf_set_option(bufnr, "modifiable", modifiable)
    end
end

function M.append_lines(bufnr, lines)
    vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
    if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
        vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, lines)
    end
end

function M.write(bufnr, lines)
    if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
        vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    end
end

return M
