-- Creates the header component for the project-level nuget manager.
-- Thin wrapper over the shared nuget header.

local M = {}

local header = require "dotnet.nuget.header"

--- Opens the project nuget manager header.
--- @param proj_file string The project file the manager is opened for.
--- @param opts table|nil Options:
---   - prerelease (boolean): Whether prerelease packages are included.
--- @return table The header handle: { bufnr, win, tab }.
function M.open(proj_file, opts)
    opts = opts or {}
    return header.open({
        title = "NugetManager  -  " .. proj_file,
        tabs = {
            { key = "B", label = "Browse" },
            { key = "I", label = "Installed" },
            { key = "U", label = "Updates" },
        },
        prerelease = opts.prerelease or false,
    })
end

return M
