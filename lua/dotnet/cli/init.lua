local M = {}

-- Tracks a history of commands that have been run for a single session.
local history = {}

local cli_output = require "dotnet.cli.output"

-- Helper function to run a shell command and capture the output
-- Using a wrapper function because I am have played around with different ways to run shell commands.
local function shell_command(cmd)
    return vim.fn.systemlist(cmd)
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

function M.new_solution(name)
    return shell_command("dotnet new sln -n " .. name)
end

function M.sln_list(sln_file)
    return shell_command("dotnet sln " .. sln_file .. " list")
end

function M.sln_add(sln_file, project_file)
    return shell_command("dotnet sln " .. sln_file .. " add " .. project_file)
end

function M.sln_remove(sln_file, project_file)
    return shell_command("dotnet sln " .. sln_file .. " remove " .. project_file)
end

function M.new_classlib(name, output)
    return shell_command("dotnet new classlib -n " .. name .. add_flag("-o", output))
end

function M.new_console(name, output)
    return shell_command("dotnet new console -n " .. name .. add_flag("-o", output))
end

function M.new_mstest(name, output)
    return shell_command("dotnet new mstest -n " .. name .. add_flag("-o", output))
end

function M.new_web(name, output)
    return shell_command("dotnet new web -n " .. name.. add_flag("-o", output))
end

function M.new_mvc(name, output)
    return shell_command("dotnet new mvc -n " .. name .. add_flag("-o", output))
end

function M.test_list_all(target)
    return shell_command("dotnet test --list-tests" .. add_target(target))
end

-- Runs a command and displays the output in a new window.
-- Stores the command in the history.
-- param cmd: The command to run.
function M.run_cmd(cmd)
    table.insert(history, 1, cmd)
    cli_output.run_cmd(cmd)
end

function M.restore(target)
    return M.run_cmd("dotnet restore" .. add_target(target))
end

function M.build(target, configuration)
    return M.run_cmd("dotnet build" .. add_target(target) .. add_flag("-c", configuration))
end

function M.clean(target)
    return M.run_cmd("dotnet clean" .. add_target(target))
end

function M.mstest(target, filter, logger)
    return M.run_cmd("dotnet test" .. add_target(target) .. add_param("filter", filter) .. add_param("logger", logger))
end

-- Runs the last command in the history.
function M.run_last_cmd()
    if history[1] then
        M.run_cmd(history[1])
    end
end

-- Adds a package to the given project.
function M.add_package(project, package, version)
    return M.run_cmd("dotnet add " .. project .. " package " .. package .. add_param("version", version))
end

-- Removes a package from the given project.
-- @param project string The project file path.
-- @param package string The package name to remove.
function M.remove_package(project, package)
    return M.run_cmd("dotnet remove " .. project .. " package " .. package)
end

function M.get_history()
    return history
end

return M
