local M = {
    opts = {}
}

--- Stores the plugin options and forwards subsystem options.
--- Supported shape:
--- setup({
---     nuget = {
---         ui = { width = 0.8, height = 0.8, border = "rounded", style = "minimal" },
---         cache = { use_cache = true },
---     },
--- })
M.setup = function(opts)
    opts = opts or {}
    M.opts = vim.tbl_deep_extend("force", {}, M.opts, opts)

    if M.opts.nuget then
        require("dotnet.nuget.config").setup({ ui = M.opts.nuget.ui })
        require("dotnet.nuget.api.cache").setup(M.opts.nuget.cache)
    end
end

return M
