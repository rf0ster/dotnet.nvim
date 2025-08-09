-- Description: This module provides functionality to open a window for managing projects in a .NET solution.
-- It includes options to build, clean, restore, and delete projects.

local M = {}

local dotnet_nuget_project = require "dotnet.nuget.project"
local dotnet_manager = require "dotnet.manager"
local dotnet_confirm = require "dotnet.confirm"
local cli_output = require "dotnet.cli.cli_output"
local DotnetCli = require "dotnet.cli.cli"

local finders = require "telescope.finders"
local pickers = require "telescope.pickers"
local sorters = require "telescope.sorters"
local actions = require "telescope.actions"
local actions_state = require "telescope.actions.state"

local function pad(str, length)
    if #str >= length then
        return str
    end
    return str .. string.rep(" ", length - #str)
end

function M.open()
    local sln_info = dotnet_manager.load_solution()
    if not sln_info then
        return
    end

    local opts = cli_output.singleton_window()
    opts = cli_output.add_toggleterm(opts)

    local cli = DotnetCli:singleton(opts)

    local display_rel = true

    -- Function to get the maximum length of project names
    -- to ensure consistent padding in the display.
    local function get_max_project_name_length()
        local max_length = 0
        for _, project in ipairs(sln_info.projects or {}) do
            if #project.name > max_length then
                max_length = #project.name
            end
        end
        return max_length
    end

    -- Function to get the display results for the picker.
    -- It formats the project names and paths based on the
    -- the users preference for relative or absolute paths.
    local function get_results_display()
        local max_length = get_max_project_name_length()
        local results = {}
        for _, project in ipairs(sln_info.projects or {}) do
            local display = pad(project.name, max_length)
            if display_rel then
                display = display .. " " .. project.path_rel
            else
                display = display .. " " .. project.path_abs
            end
            table.insert(results, {
                value = project,
                display = display,
                ordinal = project.name,
            })
        end

        return results
    end

    -- Function to create an entry for each project in the picker.
    local function entry_maker(entry)
        return {
            value = entry.value,
            display = entry.display,
            ordinal = entry.ordinal,
        }
    end

    -- Function to reload the picker after the user toggles
    -- the display mode between relative and absolute paths.
    local function reload_picker(prompt_bufnr)
        actions_state.get_current_picker(prompt_bufnr):refresh(
            finders.new_table {
                results = get_results_display(),
                entry_maker = entry_maker,
            },
            { reset_prompt = true }
        )
    end

    pickers.new({}, {
        prompt_title = sln_info.sln_name,
        results_title = "Projects (n)uget - (b)uild - (c)lean - (r)estore - (d)elete",
        finder = finders.new_table {
            results = get_results_display(),
            entry_maker = entry_maker,
        },
        sorter = sorters.get_generic_fuzzy_sorter(),
        initial_mode = "normal",
        sorting_strategy = "ascending",
        layout_strategy = "vertical",
        layout_config = {
            prompt_position = "top",
            width = 0.5,
            height = 0.5,
        },
        attach_mappings = function(_, map)
            map("n", "p", function(prompt_bufnr)
                display_rel = not display_rel
                reload_picker(prompt_bufnr)
            end)
            map("n", "<CR>", function(prompt_buffrn)
                local project = actions_state.get_selected_entry().value
                actions.close(prompt_buffrn)

                if not project then
                    return
                end
                vim.api.nvim_command("e " .. project.path_abs)
            end)
            map("n", "n", function()
                local project = actions_state.get_selected_entry().value
                if not project then
                    return
                end
                dotnet_nuget_project.open(project.path_abs)
            end)
            map("n", "b", function()
                local project = actions_state.get_selected_entry().value
                if not project then
                    return
                end
                require "dotnet.manager.projects.build".open(project)
            end)
            map("n", "c", function()
                local project = actions_state.get_selected_entry().value
                if not project then
                    return
                end
                cli:clean(project.path_abs)
            end)
            map("n", "r", function()
                local project = actions_state.get_selected_entry().value
                if not project then
                    return
                end
                cli:restore(project.path_abs)
            end)
            map("n", "p", function(prompt_bufnr)
                local project = actions_state.get_selected_entry().value
                if not project then
                    return
                end

                actions.close(prompt_bufnr)
                vim.schedule(function() cli:run_project(project.path_abs) end)
            end)
            map("n", "d", function()
                local project = actions_state.get_selected_entry().value
                if not project then
                    return
                end

                dotnet_confirm.open({
                    prompt_title = "Delete Project",
                    prompt = {"Delete " .. project.path_rel ..  " from " .. sln_info.sln_name .. "?"},
                    on_confirm = function()
                        cli:sln_remove(sln_info.sln_path_abs, project.path_abs)
                        dotnet_manager.load_solution()
                    end
                })
            end)
            return true
        end,
    }):find()
end

return M
