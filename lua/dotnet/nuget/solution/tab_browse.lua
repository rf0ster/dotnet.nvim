--- Description: Browse tab for the solution-level nuget manager.
--- Searches the NuGet API and installs a package into a chosen
--- subset of the solution's projects.
local M = {}

local utils = require "dotnet.utils"
local buffer = require "dotnet.utils.buffer"
local window = require "dotnet.utils.window"
local display = require "dotnet.nuget.project.display"
local nuget_api = require "dotnet.nuget.api"
local nuget_win = require "dotnet.nuget.windows"
local nuget_cli = require "dotnet.nuget.cli"
local project_select = require "dotnet.nuget.project_select"
local NugetPicker = require "dotnet.nuget.picker"

--- Asynchronously maps a search term to NuGet package results.
local function map_results_async(search_term, prerelease, callback)
    if not search_term or search_term == "" then
        callback({})
        return
    end

    local query = string.match(search_term, "%S+")
    if not query then
        callback({})
        return
    end

    nuget_api.get_search_query_async(query, 20, prerelease, function(pkgs, err)
        if err then
            callback({})
            return
        end

        local results = vim.tbl_map(function(pkg)
            pkg.is_package = true
            return {
                value = pkg,
                display = pkg.id .. "@" .. pkg.version,
            }
        end, pkgs or {})
        callback(results)
    end)
end

--- Keymap to switch between showing package versions or latest packages.
local function toggle_show_versions(val, picker, state)
    if state.showing_versions then
        state.showing_versions = false
        picker:refresh_results()
        return
    end

    state.showing_versions = true
    if not val or not val.value then
        return
    end
    local pkg = val.value
    local new_results = {
        {
            value = pkg,
            display = pkg.id .. "@" .. pkg.version,
        }
    }
    for i = #pkg.versions - 1, 1, -1 do
        local v = pkg.versions[i]
        table.insert(new_results, {
            value = { id = pkg.id, version = v.version, is_package = false },
            display = "   - " .. v.version,
        })
    end
    picker:set_display_values(new_results)
end

--- Maps the selected package to its detailed view.
local function on_result_selected(selected, view_bufnr, view_win)
    if not buffer.is_valid(view_bufnr) or not window.is_valid(view_win) then
        return
    end

    buffer.clear(view_bufnr)
    if not selected or not selected.value then
        return
    end

    local pkg = selected.value
    if pkg.is_package then
        display.package(pkg, view_bufnr, view_win)
    else
        vim.schedule(function()
            nuget_api.get_pkg_registration_async(pkg.id, pkg.version, function(pkg_info)
                display.package(pkg_info, view_bufnr, view_win)
            end)
        end)
    end
end

--- Prompts for target projects and installs the package into each.
local function install_keymap(val, sln, output_bufnr, output_win)
    if not val or not val.value then
        return
    end
    local pkg = val.value

    project_select.open({
        title = "Install " .. pkg.id .. "@" .. pkg.version .. " into",
        projects = sln.projects or {},
        on_confirm = function(selected)
            -- Chain the installs into one shell command so they run
            -- sequentially and stream into the output pane.
            local cmds = {}
            for _, project in ipairs(selected) do
                table.insert(cmds, "dotnet add " .. project.path_abs
                    .. " package " .. pkg.id
                    .. " --version " .. pkg.version)
            end
            nuget_cli.new(output_bufnr, output_win):run_cmd(table.concat(cmds, " && "))
        end,
    })
end

--- Opens the browse tab for the solution.
--- @param sln table The loaded solution.
--- @param opts table Options table: prerelease (boolean).
--- @return table The tab object containing windows and buffers.
function M.new(sln, opts)
    opts = opts or {}
    local dimensions = nuget_win.get_dimensions()
    local state = { showing_versions = false }

    local output_bufnr, output_win = utils.float_win("Output", dimensions.output)
    local view_bufnr, view_win = utils.float_win("View", dimensions.view)

    local picker
    picker = NugetPicker:new({
        results_title = "Packages",
        height = dimensions.picker.height,
        width = dimensions.picker.width,
        row = dimensions.picker.row,
        col = dimensions.picker.col,
        map_to_results_async = function(search_term, callback)
            map_results_async(search_term, opts.prerelease, callback)
        end,
        on_result_selected = function(selected) on_result_selected(selected, view_bufnr, view_win) end,
        keymaps = {
            {
                key = "<leader>i",
                callback = function(val) install_keymap(val, sln, output_bufnr, output_win) end
            },
            {
                key = "<leader>v",
                callback = function(val) toggle_show_versions(val, picker, state) end
            }
        }
    })

    return {
        windows = { output_win, view_win, picker.results_win, picker.search_win },
        buffers = { output_bufnr, view_bufnr, picker.results_bufnr, picker.search_bufnr },
    }
end

return M
