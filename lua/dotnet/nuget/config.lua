local M = {}

-- user defined configuration
M.opts = {
    -- UI configuration for the nuget manager.
    ui = {
        width = 0.8, -- Percentage of the screen width to use for the nuget manager.
        height = 0.8, -- Percentage of the screen height to use for the nuget manager.
        border = "rounded", -- Border style for the nuget manager window.
        style = "minimal", -- Style of the nuget manager window.
    }
}

-- configuration that is not user configurable
M.defaults = {
    ui = {
        header_h = 2, -- Height of the header component.
    }
}

M.setup = function(opts)
    opts = opts or {}
    M.opts = vim.tbl_deep_extend("force", {}, M.opts, opts)
end

return M
