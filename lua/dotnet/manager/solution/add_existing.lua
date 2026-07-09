-- Description: Module that scans the solution directory for project files
-- that are not yet part of the solution and lets the user add one.

local M = {}

local dotnet_confirm = require "dotnet.confirm"
local dotnet_manager = require "dotnet.manager"
local manager_cli = require "dotnet.manager.cli"

--- Finds project files on disk under the solution directory that are
--- not already part of the solution.
--- @param sln table The loaded solution.
--- @return table candidates A list of { path_abs, path_rel } entries.
local function find_candidates(sln)
    local sln_dir = vim.fn.fnamemodify(sln.sln_path_abs, ":h")

    local in_sln = {}
    for _, project in ipairs(sln.projects or {}) do
        in_sln[vim.fs.normalize(project.path_abs)] = true
    end

    local candidates = {}
    for _, ext in ipairs({ "csproj", "fsproj", "vbproj" }) do
        local files = vim.fn.globpath(sln_dir, "**/*." .. ext, false, true)
        for _, file in ipairs(files) do
            local path_abs = vim.fs.normalize(vim.fn.fnamemodify(file, ":p"))
            if not in_sln[path_abs] then
                table.insert(candidates, {
                    path_abs = path_abs,
                    path_rel = path_abs:sub(#vim.fs.normalize(sln_dir) + 2),
                })
            end
        end
    end

    return candidates
end

--- Opens a picker listing on-disk projects that can be added to the solution.
--- @param sln table The loaded solution.
function M.open(sln)
    if not sln then
        return
    end

    local candidates = find_candidates(sln)
    if #candidates == 0 then
        vim.api.nvim_echo({{"[Info] No projects found on disk that are not already in the solution", "None"}}, true, {})
        return
    end

    local finders = require "telescope.finders"
    local pickers = require "telescope.pickers"
    local sorters = require "telescope.sorters"
    local actions = require "telescope.actions"
    local actions_state = require "telescope.actions.state"

    pickers.new({}, {
        initial_mode = "normal",
        prompt_title = "Add existing project to " .. sln.sln_name,
        results_title = "Projects on disk",
        finder = finders.new_table {
            results = candidates,
            entry_maker = function(entry)
                return {
                    value = entry,
                    display = entry.path_rel,
                    ordinal = entry.path_rel,
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
                if not selection then
                    return
                end

                local candidate = selection.value
                dotnet_confirm.open({
                    prompt_title = "Add Project",
                    prompt = { "Add " .. candidate.path_rel .. " to " .. sln.sln_name .. "?" },
                    on_confirm = function()
                        manager_cli.get_cli():sln_add(sln.sln_path_abs, candidate.path_abs)
                        dotnet_manager.load_solution()
                    end,
                })
            end)
            return true
        end,
    }):find()
end

return M
