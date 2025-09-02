--- and handle command history.
local DotnetCli = {}
DotnetCli.__index = DotnetCli

--- Singleton instance of the DotnetCli class if needed.
local singleton_instance = nil

local CMD_TYPE_CMD = "cmd"
local CMD_TYPE_INTERACTIVE = "interactive"

--- Creates a new instance of the DotnetCli class.
--- @param opts table Options for the DotnetCli instance.
function DotnetCli:new(opts)
    local instance = setmetatable({}, self)

    instance.history = {}
    instance.on_cmd_start = opts.on_cmd_start or function() end
    instance.on_cmd_exit = opts.on_cmd_exit or function() end
    instance.on_cmd_stdout = opts.on_cmd_stdout or function() end
    instance.on_cmd_stderr = opts.on_cmd_stderr or function() end

    instance.interactive_cmd = opts.interactive_cmd or function() end
    instance.on_interactive_start = opts.on_interactive_start or function() end
    instance.on_interactive_exit = opts.on_interactive_exit or function() end

    instance.on_background_start = opts.on_background_start or function() end
    instance.on_background_exit = opts.on_background_exit or function() end

    return instance
end

--- Creates a singleton instance of the DotnetCli class.
--- Good for configuring a single cli class once and never
--- having to create a new instance.
function DotnetCli:singleton(opts)
    singleton_instance = singleton_instance or self:new(opts)
    return singleton_instance
end

local function add_flag(flag, value)
    if value == nil then
        return ""
    end
    return " " .. flag .. " " .. value
end

local function add_target(target)
    if target == nil then
        return ""
    end
    return " " .. target
end

local function add_param(name, value)
    if value ~= nil and value ~= "" then
        return " --" .. name .. " " .. value
    else
        return ""
    end
end


--- Inserts a command into the history if it is not already present.
function DotnetCli:insert_history(cmd, cmd_type)
    if not cmd or cmd == "" then
        return
    end

    -- If the command is already in history, do not insert it again
    -- but move it to the front.
    for i, entry in ipairs(self.history) do
        if entry.cmd == cmd and entry.cmd_type == cmd_type then
            table.remove(self.history, i)
            table.insert(self.history, 1, entry)
            return
        end
    end

    -- Insert the command into history
    table.insert(self.history, 1, { cmd = cmd, cmd_type = cmd_type })
end

--- Runs a command using the .NET CLI.
--- @param cmd string The command to run.
function DotnetCli:run_cmd(cmd)
    self:insert_history(cmd, CMD_TYPE_CMD)
    vim.schedule(function()
        self.on_cmd_start(cmd)
        vim.fn.jobstart(cmd, {
            on_stdout = self.on_cmd_stdout,
            on_stderr = self.on_cmd_stderr,
            on_exit = self.on_cmd_exit,
        })
    end)
end

--- Runs a command using the .NET CLI in an interactive terminal.
--- @param cmd string The command to run.
function DotnetCli:run_interactive_cmd(cmd)
    self:insert_history(cmd, CMD_TYPE_INTERACTIVE)
    if self.interactive_cmd then
        self.on_interactive_start()
        self.interactive_cmd(cmd)
        self.on_interactive_exit()
    end
end

--- Runs a .NET command in the background.
--- Background commands are not stored in history.
--- @param cmd string The command to run.
--- @return table The result of the command execution.
function DotnetCli:run_background_cmd(cmd)
    self.on_background_start()
    local res = vim.fn.systemlist(cmd)
    self.on_background_exit()
    return res
end

--- Returns the history of commands run by the DotnetCli instance.
--- @return table The history of commands.
function DotnetCli:get_history()
    return self.history
end

--- Runs the last command from the history.
function DotnetCli:run_last_cmd()
    if #self.history == 0 then
        return
    end

    local last_cmd = self.history[1]
    if last_cmd.cmd_type == CMD_TYPE_CMD then
        self:run_cmd(last_cmd.cmd)
    elseif last_cmd.cmd_type == CMD_TYPE_INTERACTIVE then
        self:run_interactive_cmd(last_cmd.cmd)
    end
end

--- Builds a .NET project or solution.
--- @param target string|nil The path to the project or solution file. Builds from local directory if nil.
--- @param configuration string|nil The build configuration (e.g., "Debug", "Release"). Defaults to "Debug" if nil
function DotnetCli:build(target, configuration)
    self:run_cmd("dotnet build" .. add_target(target) .. add_flag("-c", configuration))
end

--- Restores a .NET project or solution.
--- @param target string|nil The path to the project or solution file. Restores from local directory if nil.
function DotnetCli:restore(target)
    self:run_cmd("dotnet restore" .. add_target(target))
end

--- Cleans a .NET project or solution.
--- @param target string|nil The path to the project or solution file. If nil it cleans from current directory.
function DotnetCli:clean(target)
    self:run_cmd("dotnet clean" .. add_target(target))
end

--- Adds a package to the given project.
--- @param project string The project file path.
--- @param package string The package name to add.
--- @param version string|nil The package version to add. If nil, the latest version
function DotnetCli:add_package(project, package, version)
    self:run_cmd("dotnet add " .. project .. " package " .. package .. add_param("version", version))
end

-- Removes a package from the given project.
-- @param project string The project file path.
-- @param package string The package name to remove.
function DotnetCli:remove_package(project, package)
    self:run_cmd("dotnet remove " .. project .. " package " .. package)
end

--- Runs tests for a .NET project or solution.
--- @param target string|nil The path to the project or solution file. Runs tests from local directory if nil.
--- @param filter string|nil The test filter expression. If nil, no filter is applied.
--- @param logger string|nil The logger to use for test results.
function DotnetCli:test(target, filter, logger)
    self:run_cmd("dotnet test" .. add_target(target) .. add_param("filter", filter) .. add_param("logger", logger))
end

--- Creates a new .NET solution.
--- @param name string The name of the solution to create.
--- @return table A table containing the result of the command execution.
function DotnetCli:new_solution(name)
    return self:run_background_cmd("dotnet new sln -n " .. name)
end

--- Lists all projects in a .NET solution.
--- @param sln_file string The path to the solution file.
--- @return table A table containing the list of projects.
function DotnetCli:sln_list(sln_file)
    return self:run_background_cmd("dotnet sln " .. sln_file .. " list")
end

--- Adds a project to a .NET solution.
--- @param sln_file string The path to the solution file.
--- @param project_file string The path to the project file to add.
--- @return table A table containing the result of the command execution.
function DotnetCli:sln_add(sln_file, project_file)
    return self:run_background_cmd("dotnet sln " .. sln_file .. " add " .. project_file)
end

--- Removes a project from a .NET solution.
--- @param sln_file string The path to the solution file.
--- @param project_file string The path to the project file to remove.
--- @return table A table containing the result of the command execution.
function DotnetCli:sln_remove(sln_file, project_file)
    return self:run_background_cmd("dotnet sln " .. sln_file .. " remove " .. project_file)
end

--- Creates a new .NET library project.
--- @param name string The name of the library project.
--- @param output string|nil The output directory for the project. If nil, uses the current directory.
--- @return table A table containing the result of the command execution.
function DotnetCli:new_classlib(name, output)
    return self:run_background_cmd("dotnet new classlib -n " .. name .. add_flag("-o", output))
end

--- Creates a new .NET console application.
--- @param name string The name of the console application.
--- @param output string|nil The output directory for the application. If nil, uses the current directory.
--- @return table A table containing the result of the command execution.
function DotnetCli:new_console(name, output)
    return self:run_background_cmd("dotnet new console -n " .. name .. add_flag("-o", output))
end

--- Creates a new .NET MSTest project.
--- @param name string The name of the MSTest project.
--- @param output string|nil The output directory for the project. If nil, uses the current directory.
--- @return table A table containing the result of the command execution.
function DotnetCli:new_mstest(name, output)
    return self:run_background_cmd("dotnet new mstest -n " .. name .. add_flag("-o", output))
end

--- Creates a new .NET web application.
--- @param name string The name of the web application.
--- @param output string|nil The output directory for the application. If nil, uses the current directory.
--- @return table A table containing the result of the command execution.
function DotnetCli:new_web(name, output)
    return self:run_background_cmd("dotnet new web -n " .. name.. add_flag("-o", output))
end

--- Creates a new .NET MVC application.
--- @param name string The name of the MVC application.
--- @param output string|nil The output directory for the application. If nil, uses the current directory.
--- @return table A table containing the result of the command execution.
function DotnetCli:new_mvc(name, output)
    return self:run_background_cmd("dotnet new mvc -n " .. name .. add_flag("-o", output))
end

--- Lists all tests in a .NET project or solution.
--- @param target string|nil The path to the project or solution file. Lists tests from local directory if nil.
--- @return table A table containing the list of tests.
function DotnetCli:test_list_all(target)
    return self:run_background_cmd("dotnet test --list-tests " .. add_target(target))
end

--- Runs a .NET project or solution.
--- @param target string|nil The path to the project or solution file. Runs from local
function DotnetCli:run_project(target)
    self:run_interactive_cmd("dotnet run " .. add_param("project", target))
end

--- Runs tests for a .NET project or solution using MSTest.
--- @param target string|nil The path to the project or solution file. Runs tests from local directory if nil.
--- @param filter string|nil The test filter expression. If nil, no filter is applied.
--- @param logger string|nil The logger to use for test results.
function DotnetCli:mstest(target, filter, logger)
    return self:run_cmd("dotnet test" .. add_target(target) .. add_param("filter", filter) .. add_param("logger", logger))
end

return DotnetCli
