--- Description: Module responsible for opening the NuGet package browsing interface.
--- It provides functionality to search for packages, view their details and install them.
local M = {}

local utils = require "dotnet.utils"
local buffer = require "dotnet.utils.buffer"
local window = require "dotnet.utils.window"
local display = require "dotnet.nuget.project.display"
local nuget_api = require "dotnet.nuget.api"
local nuget_win = require "dotnet.nuget.windows"
local nuget_cli = require "dotnet.nuget.cli"
local NugetPicker = require "dotnet.nuget.picker_temp"

--- Asynchronously maps a search term to NuGet package results.
-- @param search_term The search term to query.
-- @param callback The callback function to handle the results.
local function map_results_async(search_term, callback)
    if not search_term or search_term == "" then
        callback({})
        return
    end

    local query = string.match(search_term, "%S+")
    if not query then
        callback({})
        return
    end

    nuget_api.get_search_query_async(query, 20, function(pkgs, err)
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

local showing_versions = false
--- Keymap to switch between showing package versions or latest packages.
--- @param val table The current selected value from the picker.
--- @param picker table The picker instance to refresh or update results.
local function toggle_show_versions(val, picker)
    if showing_versions then
        showing_versions = false
        picker:refresh_results()
        return
    end

    showing_versions = true
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
            value =  { id = pkg.id, version = v.version, is_package = false },
            display = "   - " .. v.version,
        })
    end
    picker:set_display_values(new_results)
end

--- Maps the selected package to its detailed view.
--- @param selected table selected package from the picker.
--- @param view_bufnr number buffer number of the view window.
--- @param view_win number window ID of the view window.
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

--- Initializes and opens the NuGet package browsing interface.
-- It sets up the necessary callbacks for searching and selecting packages.
-- @param proj_file The full project file path.
function M.new(proj_file)
    local dimensions = nuget_win.get_dimensions()

    local output_bufnr, output_win = utils.float_win("Output", dimensions.output)
    local view_bufnr, view_win = utils.float_win("View", dimensions.view)

    local picker
    picker = NugetPicker:new({
        results_title = "Packages",
        height = dimensions.picker.height,
        width = dimensions.picker.width,
        row = dimensions.picker.row,
        col = dimensions.picker.col,
        map_to_results_async = map_results_async,
        on_result_selected = function(selected) on_result_selected(selected, view_bufnr, view_win) end,
        keymaps = {
            {
                key = "<leader>i",
                callback = function(val)
                    local cli = nuget_cli.new(output_bufnr, output_win)
                    cli:add_package(proj_file, val.value.id, val.value.version)
                end
            },
            {
                key = "<leader>v",
                callback = function(val) toggle_show_versions(val, picker) end
            }
        }
    })

    return {
        windows = { output_win, view_win, picker.results_win, picker.search_win },
        buffers = { output_bufnr, view_bufnr, picker.results_bufnr, picker.search_bufnr },
    }
end

return M
