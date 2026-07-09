-- Description: Parser for .slnx (XML-based Visual Studio solution) files.
-- Extracts project information from the newer .slnx format.

local M = {}

--- Extracts the project name from a project path.
--- @param project_path string The path to the project file
--- @return string name The project name (without extension)
local function get_project_name(project_path)
    -- Extract filename from path and remove extension
    local filename = project_path:match("([^/\\]+)$")
    if filename then
        return filename:match("(.+)%.[^.]+$") or filename
    end
    return project_path
end

--- Determines the project extension from the path.
--- @param project_path string The path to the project file
--- @return string ext The file extension (e.g., ".csproj")
local function get_project_ext(project_path)
    return project_path:match("(%.[^.]+)$") or ".csproj"
end

--- Parses a .slnx file and extracts project information.
--- The .slnx format is XML-based with the structure:
--- <Solution>
---   <Project Path="path/to/project.csproj" />
---   <Folder Name="src">
---     <Project Path="src/project/project.csproj" />
---   </Folder>
--- </Solution>
--- @param slnx_content table The lines of the .slnx file
--- @param sln_dir string The directory containing the solution file, used to resolve project paths
--- @return table projects A table of project entries
function M.parse(slnx_content, sln_dir)
    local projects = {}
    local content = table.concat(slnx_content, "\n")

    -- Match all Project elements with Path attribute
    -- Handles both self-closing <Project Path="..." /> and <Project Path="..."></Project>
    for project_path in content:gmatch('<Project[^>]+Path="([^"]+)"') do
        -- Only include actual project files (.csproj, .fsproj, .vbproj)
        local ext = get_project_ext(project_path)
        if ext == ".csproj" or ext == ".fsproj" or ext == ".vbproj" then
            local project_name = get_project_name(project_path)

            table.insert(projects, {
                name = project_name,
                ext = ext,
                guid = nil, -- .slnx files don't use GUIDs for projects
                type = "SDK-style project",
                path_rel = project_path:gsub("\\", "/"),
                path_abs = vim.fs.normalize(sln_dir .. "/" .. project_path:gsub("\\", "/")),
            })
        end
    end

    return projects
end

return M
