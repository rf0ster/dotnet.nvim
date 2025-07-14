-- Description: This module provides functionality to manage and retrieve information about a solution file.
-- It includes methods to load the solution from disk, store its file information, and load the corresponding
-- projects and tests associated with the solution.

local M = {
    -- The full path to the solution file with the file name and extension
    sln_file = nil,

    -- The name of the solution without the file extension
    sln_name = nil,

    -- A table to store the projects associated with the solution.
    -- Each project is represented as a table with the following keymaps
    -- name: The name of the project
    -- path: The absolute path to the project file
    -- guid: The unique identifier for the project
    projects = {}
}

local guid = require("dotnet.manager.guid")

-- Function to load ths solution from disk.
-- @param sln_file_path The path to the solution file
-- If the path does not include the file name, it will search for the first solution file in the current directory.
-- If no path is provided, it will search for the first solution file in the current directory.
function M.load_solution(sln_file_path)
    sln_file_path = sln_file_path or vim.fn.getcwd()

    -- If the path is a file, use it directly
    if vim.fn.filereadable(sln_file_path) == 1 then
        -- Ensure the file is a solution file
        if not sln_file_path:match("%.sln$") then
            -- If the file does not have a .sln extension, print to the user and returns
            vim.api.nvim_echo({{"[Warning] Invalid solution file", "WarningMsg"}}, true, {})
            return
        end
    else
        -- Otherwise, search for the first solution file in the directory
        local files = vim.fn.globpath(sln_file_path, "*.sln", false, true)
        if #files > 0 then
            sln_file_path = files[1]
        else
            vim.api.nvim_echo({{"[Warning] Invalid solution file", "WarningMsg"}}, true, {})
            return
        end
    end

    M.sln_file = sln_file_path
    M.sln_name = vim.fn.fnamemodify(sln_file_path, ":t:r")

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
                    name = project_name,
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
    print("Solution File: " .. (M.sln_file or ""))
    print("Solution Name: " .. (M.sln_name or ""))

    print("Projects:")
    for _, project in ipairs(M.projects) do
        print("  - GUID:     " .. (project.guid or ""))
        print("  - Name:     " .. (project.name or ""))
        print("  - Path Rel: " .. (project.path_rel or ""))
        print("  - Path Rel: " .. (project.path_abs or ""))
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

