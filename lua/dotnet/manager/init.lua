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

    -- A table to store the projects associated with the solution.
    -- Each project is represented as a table with the following keymaps
    -- name: The name of the project with the extension
    -- path_abs: The absolute path to the project file with the file name
    -- path_rel: The relative path to the project file with the file name
    -- guid: The unique identifier for the project
    projects = {}
}

local guid = require("dotnet.manager.guid")

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
    sln_file_path = sln_file_path or vim.fn.getcwd()

    -- Check if the provided path is a file or a directory
    if vim.fn.filereadable(sln_file_path) == 1 then
        -- If it's a file, ensure it has a .sln extension
        if not sln_file_path:match("%.sln$") then
            -- If the file does not have a .sln extension, print to the user and returns
            vim.api.nvim_echo({{"[Warning] Invalid solution file", "WarningMsg"}}, true, {})
            return nil
        end
    else
        -- If it's a directory, search for the first solution file in that directory
        local files = vim.fn.globpath(sln_file_path, "*.sln", false, true)
        if #files > 0 then
            sln_file_path = files[1]
        else
            vim.api.nvim_echo({{"[Warning] No solution file found in the specified directory", "WarningMsg"}}, true, {})
            return nil
        end
    end

    M.sln_path_abs = vim.fn.fnamemodify(sln_file_path, ":p"):gsub("\\", "/")
    M.sln_path_rel = vim.fn.fnamemodify(sln_file_path, ":~:.:p"):gsub("\\", "/")
    M.sln_name = vim.fn.fnamemodify(sln_file_path, ":t:r") .. ".sln"

    -- Read the file from disk, parse it and load the projects
    local sln_content = vim.fn.readfile(sln_file_path)
    if not sln_content or #sln_content == 0 then
        vim.api.nvim_echo({{"[Error] Solution file is empty or could not be read", "ErrorMsg"}}, true, {})
        return
    end

    -- Parse the solution file contents
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
                    name = project_name .. ".csproj",
                    guid = project_guid,
                    type = project_type.type,
                    path_rel = project_path:gsub("\\", "/"),
                    path_abs = vim.fn.fnamemodify(project_path, ":p"):gsub("\\", "/"),
                })
            end
        end
    end
    M.projects = projects

    return M
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

