--- Description: Updates tab for the solution-level nuget manager.
--- Lists aggregated packages with a newer version available and updates
--- them across every project that contains them.
local M = {}

local utils = require "dotnet.utils"
local fuzzy = require "dotnet.nuget.fuzzy"
local api = require "dotnet.nuget.api"
local confirm = require "dotnet.confirm"
local nuget_win = require "dotnet.nuget.windows"
local nuget_cli = require "dotnet.nuget.cli"
local packages = require "dotnet.nuget.solution.packages"
local sln_display = require "dotnet.nuget.solution.display"

--- To handle async search results correctly we keep track of the last
--- search term so that we only update results for the latest search
--- in case of out-of-order responses.
local last_search_term

--- Filters the aggregated packages to those with a newer version available.
--- @param search_term string The term to filter packages by.
--- @param aggs table The aggregated packages.
--- @param state table Per-tab state; state.outdated tracks the latest outdated list.
local function map_to_results_async(search_term, aggs, state, callback)
    last_search_term = search_term
    local sync_callback = function(vals, t)
        if t == last_search_term then
            state.outdated = vals
            callback(vals)
        end
    end

    local filtered = fuzzy.filter(aggs or {}, search_term, function(agg) return agg.id end)

    -- No packages match: clear the results instead of leaving stale ones,
    -- since no async callback will fire below.
    if not filtered or #filtered == 0 then
        sync_callback({}, search_term)
        return
    end

    local outdated = {}
    for _, agg in ipairs(filtered or {}) do
        api.get_pkg_base_async(agg.id, function(data, err)
            if err then
                sync_callback(outdated, search_term)
                return
            end

            local versions = (data and data.versions) or {}
            local latest = versions[#versions]
            local needs_update = false
            if latest then
                for _, entry in ipairs(agg.entries) do
                    if entry.version ~= latest then
                        needs_update = true
                        break
                    end
                end
            end

            if needs_update then
                local lowest = agg.distinct_versions[1]
                local count = #agg.entries
                local suffix = count == 1 and " project)" or " projects)"
                table.insert(outdated, {
                    display = agg.id .. "  " .. lowest .. " -> " .. latest .. "  (" .. count .. suffix,
                    value = { agg = agg, latest_version = latest },
                })
            end
            sync_callback(outdated, search_term)
        end)
    end
end

--- Builds the chained update command for one outdated entry.
local function update_cmds(entry)
    local cmds = {}
    for _, pkg_entry in ipairs(entry.value.agg.entries) do
        table.insert(cmds, "dotnet add " .. pkg_entry.project.path_abs
            .. " package " .. entry.value.agg.id
            .. " --version " .. entry.value.latest_version)
    end
    return cmds
end

--- Opens the updates tab for the solution.
--- @param sln table The loaded solution.
--- @return table The tab object containing windows and buffers.
function M.open(sln)
    local d = nuget_win.get_dimensions()
    local aggs = packages.aggregate(sln.projects)
    local state = { outdated = {} }

    local view_bufnr, view_win = utils.float_win("View", d.view)
    local output_bufnr, output_win = utils.float_win("Output", d.output)

    local picker
    -- Re-aggregates the packages and refreshes the picker after a mutation.
    local refresh_pkgs = vim.schedule_wrap(function()
        aggs = packages.aggregate(sln.projects)
        if picker then
            picker:refresh_results()
        end
    end)

    picker = require "dotnet.nuget.picker":new({
        results_title = "Packages",
        height = d.picker.height,
        width = d.picker.width,
        row = d.picker.row,
        col = d.picker.col,
        map_to_results_async = function(search_term, callback)
            map_to_results_async(search_term, aggs, state, callback)
        end,
        on_result_selected = function(val)
            if val and val.value then
                sln_display.package(val.value.agg, view_bufnr, view_win)
            end
        end,
        keymaps = {
            {
                key = "<leader>u",
                callback = function(val)
                    if not val or not val.value then
                        return
                    end
                    nuget_cli.new(output_bufnr, output_win, refresh_pkgs)
                        :run_cmd(table.concat(update_cmds(val), " && "))
                end
            },
            {
                key = "<leader>a",
                callback = function()
                    local outdated = state.outdated or {}
                    if #outdated == 0 then
                        return
                    end

                    confirm.open({
                        prompt_title = "Update All",
                        prompt = { "Update " .. #outdated .. " package(s) across the solution?" },
                        on_confirm = function()
                            local cmds = {}
                            for _, entry in ipairs(outdated) do
                                for _, cmd in ipairs(update_cmds(entry)) do
                                    table.insert(cmds, cmd)
                                end
                            end
                            nuget_cli.new(output_bufnr, output_win, refresh_pkgs)
                                :run_cmd(table.concat(cmds, " && "))
                        end,
                    })
                end
            }
        }
    })

    return {
        windows = { view_win, output_win, picker.results_win, picker.search_win },
        buffers = { view_bufnr, output_bufnr, picker.results_bufnr, picker.search_bufnr }
    }
end

return M
