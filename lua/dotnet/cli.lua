local M = {}

-- Tracks a history of commands that have been run for a single session.
local history = {}

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
local function run_cmd(cmd)
    table.insert(history, 1, cmd)
    require "dotnet.output".run_cmd(cmd)
end

function M.restore(target)
    return run_cmd("dotnet restore" .. add_target(target))
end

function M.build(target)
    return run_cmd("dotnet build" .. add_target(target))
end

function M.clean(target)
    return run_cmd("dotnet clean" .. add_target(target))
end

function M.mstest(target)
    return run_cmd("dotnet test" .. add_target(target))
end

-- Opens a picker with the command history.
function M.open_history()
    local sln = require "dotnet.solution".get_solution()
    if not sln then
        return
    end

    require "dotnet.picker".picker({
        prompt_title = sln.name,
        results_title = "History",
        items = history,
        maps = {
            {
                mode = "n",
                key = "<CR>",
                fn = function(prompt_bufnr)
                    local selection = require "telescope.actions.state".get_selected_entry()
                    require "telescope.actions".close(prompt_bufnr)
                    require "dotnet.output".run_cmd(selection.value)
                end
            }
        }
    })
end

-- Runs the last command in the history.
function M.run_last_cmd()
    if history[1] then
        require "dotnet.output".run_cmd(history[1])
    end
end

return M
