-- Description: Parser for .sln (Visual Studio solution) files.
-- Extracts project information from the traditional .sln format.

local M = {}

local guid = require("dotnet.manager.guid")

--- Parses a .sln file and extracts project information.
--- @param sln_content table The lines of the .sln file
--- @param sln_dir string The directory containing the solution file, used to resolve project paths
--- @return table projects A table of project entries
function M.parse(sln_content, sln_dir)
    local projects = {}

    for _, line in ipairs(sln_content) do
        -- A solution defines projects with the format:
        -- Project("{<project-type-guid>}") = "<project-name>", "<project-path>", "{<project-guid>}" EndProject
        -- Extract the project name, path, and guid
        local project_pattern = 'Project%("([^"]+)"%) = "([^"]+)", "([^"]+)", "([^"]+)"'
        local project_type_guid, project_name, project_path, project_guid = line:match(project_pattern)

        if project_type_guid and project_name and project_path and project_guid then
            local project_type = guid[project_type_guid]
            if project_type and project_type.is_proj then
                table.insert(projects, {
                    name = project_name,
                    ext = ".csproj",
                    guid = project_guid,
                    type = project_type.type,
                    path_rel = project_path:gsub("\\", "/"),
                    path_abs = vim.fs.normalize(sln_dir .. "/" .. project_path:gsub("\\", "/")),
                })
            end
        end
    end

    return projects
end

return M
