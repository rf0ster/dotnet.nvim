local M = {}

M.setup = function(opts)
    for k, v in pairs(opts) do
        M[k] = v
    end
end

return M
