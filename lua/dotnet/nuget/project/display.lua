local M = {}

local buffer = require "dotnet.utils.buffer"
local window = require "dotnet.utils.window"
local utils = require "dotnet.utils"

function M.package(pkg, bufnr, win)
    buffer.write(bufnr, {
        " ID: " .. pkg.id,
        " Version: " .. pkg.version,
        " Authors: " .. (pkg.authors[1] or ""),
        " Project URL: " .. (pkg.project_url or ""),
        " Description: "
    })

    local w = window.get_dimensions(win).width
    local s = utils.split_smart(pkg.description, w, 3, 1)

    buffer.append_lines(bufnr,  s)
end

return M
