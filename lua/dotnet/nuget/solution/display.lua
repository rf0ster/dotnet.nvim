-- Description: Rendering helpers for the solution-level nuget manager
-- detail (view) pane.

local M = {}

local buffer = require "dotnet.utils.buffer"
local window = require "dotnet.utils.window"
local api = require "dotnet.nuget.api"
local project_display = require "dotnet.nuget.project.display"

--- Appends a per-project version breakdown for an aggregated package.
--- @param agg table An aggregated package from packages.aggregate.
--- @param bufnr number The view buffer.
local function breakdown(agg, bufnr)
    local max_name = 0
    for _, entry in ipairs(agg.entries) do
        max_name = math.max(max_name, #entry.project.name)
    end

    local lines = { "", " Projects:" }
    for _, entry in ipairs(agg.entries) do
        local pad = string.rep(" ", max_name - #entry.project.name + 2)
        table.insert(lines, "   " .. entry.project.name .. pad .. entry.version)
    end
    buffer.append_lines(bufnr, lines)
end

--- Renders an aggregated package into the view pane: package details
--- (fetched async from the NuGet API) followed by the per-project breakdown.
--- @param agg table An aggregated package from packages.aggregate.
--- @param bufnr number The view buffer.
--- @param win number The view window.
function M.package(agg, bufnr, win)
    if not buffer.is_valid(bufnr) or not window.is_valid(win) then
        return
    end
    buffer.clear(bufnr)

    -- Show the highest installed version's details
    local version = agg.distinct_versions[#agg.distinct_versions]
    api.get_pkg_registration_async(agg.id, version, function(pkg)
        if not buffer.is_valid(bufnr) or not window.is_valid(win) then
            return
        end
        buffer.clear(bufnr)

        if pkg and pkg.id and pkg.version then
            project_display.package(pkg, bufnr, win)
        else
            buffer.write(bufnr, { " " .. agg.id })
        end
        breakdown(agg, bufnr)
    end)
end

return M
