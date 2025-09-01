--- Description: Module responsible for opening the NuGet package browsing interface.
--- It provides functionality to search for packages, view their details and install them.
local M = {}

local utils = require "dotnet.utils"
local buffer = require "dotnet.utils.buffer"
local window = require "dotnet.utils.window"
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

--- Maps package details to the view buffer.
--- @param pkg table package info to display.
--- @param view_buf number buffer to write the package details to.
--- @param view_win number window associated with the view buffer.
local function map_pkg_to_view(pkg, view_buf, view_win)
    local content = {
        " ID: " .. pkg.id,
        " Version: " .. pkg.version,
        " Authors: " .. (pkg.authors[1] or ""),
        " Project URL: " .. (pkg.project_url or ""),
        " Description: "
    }

    local view_w = window.get_dimensions(view_win).width
    local s = utils.split_smart(pkg.description or "", view_w, 3, 1)
    for _, line in ipairs(s) do
        table.insert(content, line)
    end

    buffer.write(view_buf, content)
end

--- Asynchronously fetches a package id verions and maps its details to the view buffer.
--- @param pkg table package with id and version to fetch details for.
--- @param view_buf number buffer to write the package details to.
--- @param view_win number window associated with the view buffer.
local function map_pkg_version_to_view(pkg, view_buf, view_win)
    vim.schedule(function()
        nuget_api.get_pkg_registration_async(pkg.id, pkg.version, function(pkg_info)
            map_pkg_to_view(pkg_info, view_buf, view_win)
        end)
    end)
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
        on_result_selected = function(selected)
            if not buffer.is_valid(view_bufnr) or not window.is_valid(view_win) then
                return
           end

            buffer.clear(view_bufnr)
            if not selected or not selected.value then
                return
            end

            local pkg = selected.value
            if pkg.is_package then
                map_pkg_to_view(pkg, view_bufnr, view_win)
            else
                map_pkg_version_to_view(pkg, view_bufnr, view_win)
            end
        end,
        map_to_results_async = map_results_async,
        keymaps = {
            {
                key = "<leader>i",
                callback = function(val)
                    local cli = nuget_cli.new(output_bufnr, output_win)
                    cli:add_package(proj_file, val.value.id, val.value.version)
                end
            }
        }
    })

    return {
        windows = { output_win, view_win, picker.results_win, picker.search_win },
        buffers = { output_bufnr, view_bufnr, picker.results_bufnr, picker.search_bufnr },
    }
end

return M
