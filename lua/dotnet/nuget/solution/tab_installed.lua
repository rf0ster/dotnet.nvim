--- Description: Installed tab for the solution-level nuget manager.
--- Lists packages aggregated across all solution projects and allows
--- uninstalling a package from a chosen subset of projects.
local M = {}

local utils = require "dotnet.utils"
local fuzzy = require "dotnet.nuget.fuzzy"
local nuget_win = require "dotnet.nuget.windows"
local nuget_cli = require "dotnet.nuget.cli"
local packages = require "dotnet.nuget.solution.packages"
local sln_display = require "dotnet.nuget.solution.display"
local project_select = require "dotnet.nuget.project_select"
local NugetPicker = require "dotnet.nuget.picker"

--- Formats an aggregated package as a picker row.
local function to_display(agg)
    local version = ""
    if not agg.has_conflict then
        version = "@" .. agg.distinct_versions[1]
    end
    local count = #agg.entries
    local suffix = count == 1 and " project)" or " projects)"
    return agg.id .. version .. "  (" .. count .. suffix
end

--- Fuzzy-filters the aggregated packages and maps them to picker results.
local function map_to_results(search_term, aggs)
    local filtered = fuzzy.filter(aggs or {}, search_term, function(agg) return agg.id end)

    local results = {}
    for _, agg in ipairs(filtered or {}) do
        table.insert(results, {
            display = to_display(agg),
            value = agg,
        })
    end
    return results
end

--- Prompts for target projects and uninstalls the package from each.
local function uninstall_keymap(val, output_bufnr, output_win, on_exit)
    if not val or not val.value then
        return
    end
    local agg = val.value
    local projects, preselected = packages.containing_projects(agg)

    project_select.open({
        title = "Uninstall " .. agg.id .. " from",
        projects = projects,
        preselected = preselected,
        on_confirm = function(selected)
            local cmds = {}
            for _, project in ipairs(selected) do
                table.insert(cmds, "dotnet remove " .. project.path_abs .. " package " .. agg.id)
            end
            nuget_cli.new(output_bufnr, output_win, on_exit):run_cmd(table.concat(cmds, " && "))
        end,
    })
end

--- Opens the installed tab for the solution.
--- @param sln table The loaded solution.
--- @return table The tab object containing windows and buffers.
function M.open(sln)
    local d = nuget_win.get_dimensions()
    local aggs = packages.aggregate(sln.projects)

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

    picker = NugetPicker:new({
        results_title = "Packages",
        height = d.picker.height,
        width = d.picker.width,
        row = d.picker.row,
        col = d.picker.col,
        map_to_results = function(search_term) return map_to_results(search_term, aggs) end,
        on_result_selected = function(val)
            if val and val.value then
                sln_display.package(val.value, view_bufnr, view_win)
            end
        end,
        keymaps = {
            {
                key = "<leader>u",
                callback = function(val) uninstall_keymap(val, output_bufnr, output_win, refresh_pkgs) end
            }
        }
    })

    return {
        windows = { view_win, output_win, picker.results_win, picker.search_win },
        buffers = { view_bufnr, output_bufnr, picker.results_bufnr, picker.search_bufnr }
    }
end

return M
