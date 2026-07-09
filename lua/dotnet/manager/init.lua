-- Description: This module provides functionality to manage and retrieve information about a solution file.
-- It includes methods to load the solution from disk, store its file information, and load the corresponding
-- projects and tests associated with the solution.

local M = {
    -- The full path to the solution file with the file name and extension
    sln_path_abs = nil,

    -- The relative path to the solution file with the file name
    sln_path_rel = nil,

    -- The name of the solution file with the extension
    sln_name = nil,

    -- A boolean indicating if the solution file is a .slnx file
    is_slnx = false,

    -- A table to store the projects associated with the solution.
    -- Each project is represented as a table with the following keymaps
    -- name: The name of the project with the extension
    -- path_abs: The absolute path to the project file with the file name
    -- path_rel: The relative path to the project file with the file name
    -- guid: The unique identifier for the project
    projects = {}
}

local parser_sln = require("dotnet.manager.solution.parser_sln")
local parser_slnx = require("dotnet.manager.solution.parser_slnx")

--- Function to set the solution file path and name.
--- The file path can be absolute or relative, and it can include the file name or not.
--- If the file name is included, it will be used to match the solution file in the given directory.
--- If the provided file path is relative, it will be resolved against the current working directory.
--- If the provided file path is absolute, it will be used directly.
--- If the file name is not provided, it will search for the first solution file in the given directory.
--- If no path is provided, it will search for the first solution file in the current directory.
--- Loads the projects defined in the solution file and returns a table with the solution file path, name, and projects loaded.
--- @param sln_file_path string|nil The path to the solution file
--- @return table|nil table Module the solution file path and name set, and the projects loaded.
function M.load_solution(sln_file_path)
    local manager_solution = require("dotnet.manager.solution")
    sln_file_path = sln_file_path or vim.fn.getcwd()
    local is_slnx = false

    -- Check if the provided path is a file or a directory
    if vim.fn.filereadable(sln_file_path) == 1 then
        -- If it's a file, ensure it has a .sln or .slnx extension
        if sln_file_path:match("%.slnx$") then
            is_slnx = true
        elseif not sln_file_path:match("%.sln$") then
            -- If the file does not have a .sln or .slnx extension, print to the user and return
            vim.api.nvim_echo({{"[Warning] Invalid solution file", "WarningMsg"}}, true, {})
            return nil
        end
    else
        -- If it's a directory, search for the first solution file in that directory
        local files = vim.fn.globpath(sln_file_path, "*.sln", false, true)
        if #files > 0 then
            sln_file_path = files[1]
        else
            files = vim.fn.globpath(sln_file_path, "*.slnx", false, true)
            if #files > 0 then
                is_slnx = true
                sln_file_path = files[1]
            else
                vim.api.nvim_echo({{"[Warning] No solution file found in the specified directory", "WarningMsg"}}, true, {})
                manager_solution.create()
                return nil
            end
        end
    end

    M.sln_path_abs = vim.fn.fnamemodify(sln_file_path, ":p"):gsub("\\", "/")
    M.sln_path_rel = vim.fn.fnamemodify(sln_file_path, ":~:.:p"):gsub("\\", "/")
    M.is_slnx = is_slnx

    if is_slnx then
        M.sln_name = vim.fn.fnamemodify(sln_file_path, ":t:r") .. ".slnx"
    else
        M.sln_name = vim.fn.fnamemodify(sln_file_path, ":t:r") .. ".sln"
    end

    -- Read the file from disk, parse it and load the projects
    local sln_content = vim.fn.readfile(sln_file_path)
    if not sln_content or #sln_content == 0 then
        vim.api.nvim_echo({{"[Error] Solution file is empty or could not be read", "ErrorMsg"}}, true, {})
        manager_solution.create()
        return
    end

    -- Parse the solution file contents using the appropriate parser.
    -- Project paths in the solution file are relative to the solution
    -- file's directory, not the current working directory.
    local sln_dir = vim.fn.fnamemodify(M.sln_path_abs, ":h")
    local projects
    if is_slnx then
        projects = parser_slnx.parse(sln_content, sln_dir)
    else
        projects = parser_sln.parse(sln_content, sln_dir)
    end
    M.projects = projects

    return M
end

--- Function to retrieve the NuGet packages defined in a project file.
--- Handles both the self-closing attribute form:
---   <PackageReference Include="Pkg" Version="1.0.0" />
--- and the block form with a Version child element:
---   <PackageReference Include="Pkg"><Version>1.0.0</Version></PackageReference>
--- @param project_file string The path to the project file (e.g., .csproj)
function M.get_nuget_pkgs(project_file)
    local f = io.open(project_file, "r")
    if not f then
        return nil
    end

    local content = f:read("*a")
    f:close()

    local packages = {}
    local init = 1
    while true do
        local s, e, attrs = content:find("<PackageReference([^>]*)>", init)
        if not s then
            break
        end
        init = e + 1

        local id = attrs:match('Include%s*=%s*"([^"]+)"')
        local version = attrs:match('Version%s*=%s*"([^"]+)"')

        -- Block form: version comes from a <Version> child element
        if id and not version and not attrs:match("/%s*$") then
            local close_s = content:find("</PackageReference>", e, true)
            if close_s then
                local body = content:sub(e + 1, close_s - 1)
                version = body:match("<Version>%s*([^<%s]+)%s*</Version>")
            end
        end

        if id and version then
            table.insert(packages, { id = id, version = version })
        end
    end

    return packages
end


-- Prints the current solution information to the user.
function M.print_solution_info()
    print("Solution Name: " .. (M.sln_name or ""))
    print("Solution Path (Abs): " .. (M.sln_path_abs or ""))
    print("Solution Path (Rel): " .. (M.sln_path_rel or ""))

    print("Projects:")
    for _, project in ipairs(M.projects) do
        print("  " .. (project.name or ""))
        print("  - GUID:     " .. (project.guid or ""))
        print("  - Type:     " .. (project.type or ""))
        print("  - Name:     " .. (project.name or ""))
        print("  - Path (Rel): " .. (project.path_rel or ""))
        print("  - Path (Abs): " .. (project.path_abs or ""))
        print()
    end
end

function M.get_project(project_name)
    for _, project in ipairs(M.projects) do
        if project.name == project_name then
            return project
        end
    end
    return nil
end

return M

