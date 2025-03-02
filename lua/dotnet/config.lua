local M = {
    opts = {}
}

M.setup = function(opts)
    opts = opts or {}
    M.opts = vim.tbl_deep_extend("force", {}, M.opts, opts)

    print(vim.inspect(M))
end

return M
