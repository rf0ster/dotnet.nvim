-- Description: Aggregates installed NuGet packages across all projects
-- of a solution. Pure data module; recomputed on every tab (re)build.

local M = {}

--- Aggregates the NuGet packages installed across the given projects.
--- @param projects table The solution's projects ({ name, path_abs, ... }).
--- @return table packages A sorted list of aggregated packages:
---   - id (string): The package id.
---   - entries (table): List of { project, version } for each project containing it.
---   - versions (table): Map of version -> count of projects using it.
---   - distinct_versions (table): Sorted list of the distinct installed versions.
---   - has_conflict (boolean): True when more than one distinct version is installed.
function M.aggregate(projects)
    local manager = require "dotnet.manager"

    local by_id = {}
    for _, project in ipairs(projects or {}) do
        local pkgs = manager.get_nuget_pkgs(project.path_abs) or {}
        for _, pkg in ipairs(pkgs) do
            local key = pkg.id:lower()
            local agg = by_id[key]
            if not agg then
                agg = { id = pkg.id, entries = {}, versions = {} }
                by_id[key] = agg
            end
            table.insert(agg.entries, { project = project, version = pkg.version })
            agg.versions[pkg.version] = (agg.versions[pkg.version] or 0) + 1
        end
    end

    local packages = {}
    for _, agg in pairs(by_id) do
        agg.distinct_versions = {}
        for version in pairs(agg.versions) do
            table.insert(agg.distinct_versions, version)
        end
        table.sort(agg.distinct_versions)
        agg.has_conflict = #agg.distinct_versions > 1
        table.insert(packages, agg)
    end

    table.sort(packages, function(a, b) return a.id:lower() < b.id:lower() end)
    return packages
end

--- Returns the projects of an aggregated package as a preselected-set
--- keyed by project name, for use with the project_select modal.
--- @param agg table An aggregated package from M.aggregate.
--- @return table projects, table preselected
function M.containing_projects(agg)
    local projects = {}
    local preselected = {}
    for _, entry in ipairs(agg.entries) do
        table.insert(projects, entry.project)
        preselected[entry.project.name] = true
    end
    return projects, preselected
end

return M
