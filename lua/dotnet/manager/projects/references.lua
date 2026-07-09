-- Description: Module for managing project-to-project references.
-- Lists the current references of a project and allows adding
-- references to other solution projects or removing existing ones.

local M = {}

local pickers = require "telescope.pickers"
local finders = require "telescope.finders"
local sorters = require "telescope.sorters"
local actions = require "telescope.actions"
local actions_state = require "telescope.actions.state"

local dotnet_confirm = require "dotnet.confirm"
local manager_cli = require "dotnet.manager.cli"

--- Lists the current project references by running `dotnet list reference`.
--- @param project table The project to list references for.
--- @return table references A list of reference paths (as printed by the CLI).
local function get_references(project)
    local cli = manager_cli.get_cli()
    local lines = cli:list_reference(project.path_abs) or {}

    -- Output starts with a two-line header ("Project reference(s)" / "----"),
    -- or a single message line when there are no references.
    local references = {}
    local in_list = false
    for _, line in ipairs(lines) do
        if in_list then
            local ref = line:gsub("^%s+", ""):gsub("%s+$", "")
            if ref ~= "" then
                table.insert(references, ref)
            end
        elseif line:match("^%-%-") then
            in_list = true
        end
    end
    return references
end

--- Opens a picker of solution projects that can be added as a reference.
--- Excludes the project itself and projects already referenced.
--- @param sln table The loaded solution.
--- @param project table The project to add a reference to.
--- @param references table The project's current reference paths.
local function add_reference(sln, project, references)
    local referenced = {}
    for _, ref in ipairs(references) do
        -- Reference paths are printed relative to the project directory
        -- with platform separators; compare by file name to stay simple.
        referenced[vim.fn.fnamemodify(ref:gsub("\\", "/"), ":t")] = true
    end

    local candidates = {}
    for _, p in ipairs(sln.projects or {}) do
        local file_name = vim.fn.fnamemodify(p.path_abs, ":t")
        if p.path_abs ~= project.path_abs and not referenced[file_name] then
            table.insert(candidates, p)
        end
    end

    if #candidates == 0 then
        vim.api.nvim_echo({{"[Info] No other solution projects available to reference", "None"}}, true, {})
        return
    end

    pickers.new({}, {
        initial_mode = "normal",
        prompt_title = "Add reference to " .. project.name,
        results_title = "Solution projects",
        finder = finders.new_table {
            results = candidates,
            entry_maker = function(entry)
                return {
                    value = entry,
                    display = entry.name .. " " .. entry.path_rel,
                    ordinal = entry.name,
                }
            end,
        },
        sorter = sorters.get_generic_fuzzy_sorter(),
        sorting_strategy = "ascending",
        layout_strategy = "vertical",
        layout_config = {
            prompt_position = "top",
            width = 0.5,
            height = 0.5,
        },
        attach_mappings = function(_, map)
            map("n", "<CR>", function(prompt_bufnr)
                local selection = actions_state.get_selected_entry()
                pcall(actions.close, prompt_bufnr)
                if selection then
                    manager_cli.get_cli():add_reference(project.path_abs, selection.value.path_abs)
                end
            end)
            return true
        end,
    }):find()
end

--- Opens the add-reference picker for a project directly, skipping
--- the references list.
--- @param sln table The loaded solution.
--- @param project table The project to add a reference to.
function M.add(sln, project)
    if not project then
        return
    end
    add_reference(sln, project, get_references(project))
end

--- Opens the references manager for a project.
--- @param sln table The loaded solution.
--- @param project table The project to manage references for.
function M.open(sln, project)
    if not project then
        return
    end

    local references = get_references(project)

    pickers.new({}, {
        initial_mode = "normal",
        prompt_title = "References: " .. project.name,
        results_title = "(a)dd - (d)elete",
        finder = finders.new_table {
            results = references,
            entry_maker = function(entry)
                return {
                    value = entry,
                    display = entry,
                    ordinal = entry,
                }
            end,
        },
        sorter = sorters.get_generic_fuzzy_sorter(),
        sorting_strategy = "ascending",
        layout_strategy = "vertical",
        layout_config = {
            prompt_position = "top",
            width = 0.5,
            height = 0.5,
        },
        attach_mappings = function(_, map)
            map("n", "a", function(prompt_bufnr)
                pcall(actions.close, prompt_bufnr)
                add_reference(sln, project, references)
            end)
            map("n", "d", function(prompt_bufnr)
                local selection = actions_state.get_selected_entry()
                if not selection then
                    return
                end
                pcall(actions.close, prompt_bufnr)

                local ref = selection.value
                dotnet_confirm.open({
                    prompt_title = "Remove Reference",
                    prompt = { "Remove reference " .. ref .. " from " .. project.name .. "?" },
                    on_confirm = function()
                        -- Normalize separators so backslashes survive the shell;
                        -- dotnet matches references regardless of separator style.
                        manager_cli.get_cli():remove_reference(project.path_abs, ref:gsub("\\", "/"))
                    end,
                })
            end)
            return true
        end,
    }):find()
end

return M
