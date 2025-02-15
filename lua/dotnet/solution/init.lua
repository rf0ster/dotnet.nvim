local M = {}

local sln_file = nil
local sln_name = nil
local sln_projects = nil

-- Locates a file on disk based on a pattern
-- @param match The pattern to match
-- @param depth The depth to search
-- @return The path to the file
local function locate_file(match, depth)
    local file = nil

    require "plenary.scandir".scan_dir('.', {
        hidden = false,
        add_dirs = false,
        depth = depth or nil,
        on_insert = function(entry)
            if entry:match(match) then
                file = entry
                return true
            end
        end
    })

    return file
end

-- Load the solution file 
-- @param sln_file_path The path to the solution file
function M.load_solution(sln_file_path)
    if sln_file_path then
        sln_file = locate_file(sln_file_path)
    else
        sln_file = locate_file('%.sln$', 1)
    end

    if sln_file then
        sln_name = sln_file:match("([^/\\]+%.sln)$")
    end

    return {
        name = sln_name,
        file = sln_file,
    }
end

-- Loads the projects for the solution.
-- If there is no solution loaded in the module, it will load the solution first.
function M.load_projects()
    if not sln_file then
        M.load_solution()
    end

    if not sln_file then
        return
    end

    local result = require "dotnet.cli".sln_list(sln_file)
    if result == nil then
        return
    end

    local projects = {}
    for _, project_file in ipairs(result) do
        local project_name = project_file:match("([^/\\]+%.csproj)$")
        if project_name then
            table.insert(projects, {
                file = project_file,
                name = project_name,
            })
        end
    end
    sln_projects = projects

    return sln_projects
end

-- Loads the tests for all projects in the solution.
-- If there are no projects loaded in the module, it will load the projects first.
function M.load_tests_all()
    if not sln_projects then
        M.load_projects()
    end

    if not sln_projects then
        return
    end

    for _, project in ipairs(sln_projects) do
        project.tests = M.load_tests(project.file)
    end

    return sln_projects
end

-- Returns a table of the list of tests found in a given project files.
-- @param project_file The path to the project file
-- @return A table of the list of tests found in the project file
function M.load_tests(project_file)
    local output = require "dotnet.cli".test_list_all(project_file)
    if not output then
        return {}
    end

    local tests = {}
    local test_capture_start = false
    for _, line in ipairs(output) do
        if line:find('The following Tests are available') then
            test_capture_start = true
        elseif test_capture_start and line ~= '' then
            table.insert(tests, line:match("^%s*(.-)%s*$"))
        end
    end

    return tests
end

-- Returns the solution information.
-- If there is no solution loaded in the module, it will load the solution first.
-- @return The solution information
-- @field name The name of the solution
-- @field file The path to the solution file
function M.get_solution()
    if not sln_file then
        M.load_solution()
    end

    if not sln_file then
        return nil
    end

    return {
        name = sln_name,
        file = sln_file,
    }
end

-- Returns the projects for the solution.
-- If there are no projects loaded in the module, it will load the projects first.
-- @return A table of the projects for the solution
function M.get_projects()
    if not sln_projects then
        M.load_projects()
    end

    return sln_projects
end

return M
