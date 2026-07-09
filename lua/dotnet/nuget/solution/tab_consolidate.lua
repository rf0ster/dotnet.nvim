--- Description: Consolidate tab for the solution-level nuget manager.
--- Lists packages installed with mismatched versions across projects and
--- sets every project that contains the package to one chosen version.
local M = {}

local utils = require "dotnet.utils"
local fuzzy = require "dotnet.nuget.fuzzy"
local api = require "dotnet.nuget.api"
local confirm = require "dotnet.confirm"
local nuget_win = require "dotnet.nuget.windows"
local nuget_cli = require "dotnet.nuget.cli"
local packages = require "dotnet.nuget.solution.packages"
local sln_display = require "dotnet.nuget.solution.display"
local select_modal = require "dotnet.nuget.select"
local NugetPicker = require "dotnet.nuget.picker"

--- Filters the aggregated packages to those with version conflicts
--- and maps them to picker results.
local function map_to_results(search_term, aggs)
    local conflicted = {}
    for _, agg in ipairs(aggs or {}) do
        if agg.has_conflict then
            table.insert(conflicted, agg)
        end
    end

    local filtered = fuzzy.filter(conflicted, search_term, function(agg) return agg.id end)

    local results = {}
    for _, agg in ipairs(filtered or {}) do
        table.insert(results, {
            display = agg.id .. ": " .. table.concat(agg.distinct_versions, " / "),
            value = agg,
        })
    end
    return results
end

--- Consolidates every project containing the package to the given version.
local function consolidate_to(agg, version, output_bufnr, output_win, on_exit)
    confirm.open({
        prompt_title = "Consolidate",
        prompt = { "Set " .. agg.id .. " to " .. version .. " in " .. #agg.entries .. " project(s)?" },
        on_confirm = function()
            local cmds = {}
            for _, entry in ipairs(agg.entries) do
                table.insert(cmds, "dotnet add " .. entry.project.path_abs
                    .. " package " .. agg.id
                    .. " --version " .. version)
            end
            nuget_cli.new(output_bufnr, output_win, on_exit):run_cmd(table.concat(cmds, " && "))
        end,
    })
end

--- Opens the version picker for a conflicted package.
--- Lists all published versions (newest first) with installed ones marked.
local function consolidate_keymap(val, prerelease, output_bufnr, output_win, on_exit)
    if not val or not val.value then
        return
    end
    local agg = val.value

    local installed = {}
    for _, version in ipairs(agg.distinct_versions) do
        installed[version] = true
    end

    api.get_pkg_base_async(agg.id, function(data, err)
        local versions = (not err and data and data.versions) or {}

        local items = {}
        for i = #versions, 1, -1 do
            local version = versions[i]
            local is_prerelease = version:find("-", 1, true) ~= nil
            if not is_prerelease or prerelease or installed[version] then
                table.insert(items, {
                    display = version .. (installed[version] and "  (installed)" or ""),
                    value = version,
                })
            end
        end

        -- Fall back to the installed versions when the API has nothing
        if #items == 0 then
            for i = #agg.distinct_versions, 1, -1 do
                table.insert(items, {
                    display = agg.distinct_versions[i] .. "  (installed)",
                    value = agg.distinct_versions[i],
                })
            end
        end

        vim.schedule(function()
            select_modal.open({
                title = "Consolidate " .. agg.id .. " to",
                items = items,
                on_select = function(version)
                    consolidate_to(agg, version, output_bufnr, output_win, on_exit)
                end,
            })
        end)
    end)
end

--- Opens the consolidate tab for the solution.
--- @param sln table The loaded solution.
--- @param opts table Options table: prerelease (boolean).
--- @return table The tab object containing windows and buffers.
function M.open(sln, opts)
    opts = opts or {}
    local d = nuget_win.get_dimensions()
    local aggs = packages.aggregate(sln.projects)

    local view_bufnr, view_win = utils.float_win("View", d.view)
    local output_bufnr, output_win = utils.float_win("Output", d.output)

    local picker
    -- Re-aggregates the packages and refreshes the picker after a mutation,
    -- so consolidated packages drop off the list.
    local refresh_pkgs = vim.schedule_wrap(function()
        aggs = packages.aggregate(sln.projects)
        if picker then
            picker:refresh_results()
        end
    end)

    picker = NugetPicker:new({
        results_title = "Version Conflicts",
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
                key = "<leader>c",
                callback = function(val)
                    consolidate_keymap(val, opts.prerelease, output_bufnr, output_win, refresh_pkgs)
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
