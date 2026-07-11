-- Description: This module provides functionality to open a window for managing projects in a .NET solution.
-- It includes options to build, clean, restore, and delete projects.

local M = {}

local dotnet_manager = require "dotnet.manager"
local nuget = require "dotnet.nuget.project"
local cli = require "dotnet.manager.cli".get_cli()
local submenu = require "dotnet.manager.projects.submenu"

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

--- Finds the project file that contains the given file by walking up
--- the directory tree looking for a .csproj/.fsproj/.vbproj file.
--- @param file_path string The file to find the containing project for.
--- @return string|nil The project file path, or nil if none was found.
local function find_project_file(file_path)
    local matches = vim.fs.find(function(name)
        return name:match("%.csproj$") or name:match("%.fsproj$") or name:match("%.vbproj$")
    end, {
        path = vim.fs.dirname(file_path),
        upward = true,
        limit = 1,
    })
    return matches[1]
end

--- Resolves the project that contains the file in the current buffer.
--- Warns and returns nil when the buffer has no file or no project
--- exists in any directory above it.
--- @return table|nil The project ({ name, path_abs, path_rel }), or nil.
local function get_current_project()
    local file = vim.api.nvim_buf_get_name(0)
    if file == "" then
        vim.api.nvim_echo({{"[Warning] Current buffer is not a file", "WarningMsg"}}, true, {})
        return nil
    end

    local proj_file = find_project_file(file)
    if not proj_file then
        vim.api.nvim_echo({{"[Warning] No project found for " .. file, "WarningMsg"}}, true, {})
        return nil
    end

    return {
        name = vim.fn.fnamemodify(proj_file, ":t:r"),
        path_abs = vim.fs.normalize(vim.fn.fnamemodify(proj_file, ":p")),
        path_rel = vim.fn.fnamemodify(proj_file, ":."),
    }
end

--- Opens the build manager for the project that contains the file in
--- the current buffer. When a configuration is given, the build menu
--- is bypassed and the project builds immediately.
--- @param configuration string|nil "debug" or "release" (case-insensitive).
function M.build_current(configuration)
    local project = get_current_project()
    if not project then
        return
    end

    if configuration then
        local cfg = ({ debug = "Debug", release = "Release" })[configuration:lower()]
        if not cfg then
            vim.api.nvim_echo({{"[Warning] Invalid configuration: " .. configuration .. " (expected debug or release)", "WarningMsg"}}, true, {})
            return
        end
        cli:build(project.path_abs, cfg)
        return
    end

    require "dotnet.manager.projects.build".open(project)
end

--- Opens the nuget manager for the project that contains the file in
--- the current buffer.
function M.nuget_current()
    local project = get_current_project()
    if not project then
        return
    end
    nuget.open(project.path_abs)
end

--- Opens the references manager for the project that contains the file
--- in the current buffer. The solution is loaded so other solution
--- projects can be offered when adding a reference.
function M.references_current()
    local project = get_current_project()
    if not project then
        return
    end

    local sln = dotnet_manager.load_solution()
    if not sln then
        return
    end
    require "dotnet.manager.projects.references".open(sln, project)
end


function M.open()
    local sln_info = dotnet_manager.load_solution()
    if not sln_info then
        return
    end

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
                display = display .. "  " .. project.path_rel
            else
                display = display .. "  " .. project.path_abs
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
        prompt_title = sln_info.sln_name .. " projects",
        results_title = "(m)enu - (n)uget - (b)uild - (c)lean - (r)estore - (a)dd ref - (p)aths",
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
            map("n", "m", function(prompt_bufnr)
                local project = actions_state.get_selected_entry().value
                actions.close(prompt_bufnr)

                if not project then
                    return
                end
                submenu.open(sln_info, project)
            end)
            map("n", "<CR>", function(prompt_bufnr)
                local project = actions_state.get_selected_entry().value
                actions.close(prompt_bufnr)

                if not project then
                    return
                end
                submenu.open(sln_info, project)
            end)
            map("n", "n", function()
                local project = actions_state.get_selected_entry().value
                if not project then
                    return
                end
                nuget.open(project.path_abs)
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
            map("n", "a", function(prompt_bufnr)
                local project = actions_state.get_selected_entry().value
                if not project then
                    return
                end

                actions.close(prompt_bufnr)
                require "dotnet.manager.projects.references".add(sln_info, project)
            end)
            return true
        end,
    }):find()
end

return M
