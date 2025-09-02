--- Description: Module for managing the update of NuGet packages for a .csproj file.
local M = {}

local display = require "dotnet.nuget.project.display"
local buffer = require "dotnet.utils.buffer"
local window = require "dotnet.utils.window"
local utils = require "dotnet.utils"
local fuzzy = require "dotnet.nuget.fuzzy"
local api = require "dotnet.nuget.api"
local cli = require "dotnet.nuget.cli"

--- To handle async search results correctly
--- we keep track of the last search term
--- so that we only update results for the 
--- latest search in case of out-of-order responses.
local last_search_term

--- Given a search term, filters through the list of installed packages
--- and maps the results to a format suitable for display in the picker.
--- @param search_term string The term to filter packages by.
--- @param pkgs table The list of installed packages to filter.
--- @return table A list of packages that match the search term.
local function map_to_results_async(search_term, pkgs, callback)
    last_search_term = search_term
    local sync_callback = function(vals, t)
        if t == last_search_term then
            callback(vals)
        end
    end

    local filtered_pkgs = fuzzy.filter(pkgs or {}, search_term, function(pkg)
        return pkg.id .. "@" .. pkg.version
    end)

    local outdated_pkgs = {}
    for _, pkg in ipairs(filtered_pkgs or {}) do
        api.get_pkg_base_async(pkg.id, function(data, err)
            if err then
                sync_callback(outdated_pkgs, search_term)
                return
            end

            local versions = data.versions or {}
            if versions and #versions > 0 and versions[#versions] ~= pkg.version then
                table.insert(outdated_pkgs, {
                    display = pkg.id .. "@" .. pkg.version .. " -> " .. versions[#versions],
                    value = {
                        id = pkg.id,
                        version = pkg.version,
                        latest_version = versions[#versions],
                    }
                })
            end
            sync_callback(outdated_pkgs, search_term)
        end)
    end
end

--- Handles the event when a package is selected from the picker.
--- Selection means to move the cursor over the item.
--- @param val table The selected value from the picker.
--- @param view_bufnr number The buffer number of the view window.
--- @param view_win number The window ID of the view window.
local function on_result_selected(val, view_bufnr, view_win)
    if not buffer.is_valid(view_bufnr) or not window.is_valid(view_win) then
        return
    end
    buffer.clear(view_bufnr)

    if not val then
        return
    end

    -- Fetch detailed package info and display in view window
    api.get_pkg_registration_async(val.value.id, val.value.version, function(pkg)
        -- This function is async, make sure buffer and window are still valid
        if not buffer.is_valid(view_bufnr) or not window.is_valid(view_win) then
            return
        end
        buffer.write(view_bufnr, {})

        if not pkg or not pkg.id or not pkg.version then
            buffer.write(view_bufnr, {
                "Failed to fetch package information."
            })
        else
            display.package(pkg, view_bufnr, view_win)
        end
    end)
end

--- Opens the tab for updating packages for a .csproj file.
--- @param proj_file string File path to the .csproj file to open.
--- @return table The tab object containing windows and buffers.
function M.open(proj_file)
    local d = require "dotnet.nuget.windows".get_dimensions()
    local pkgs = require "dotnet.manager".get_nuget_pkgs(proj_file) or {}

    local view_bufnr, view_win = utils.float_win("View", d.view)
    local output_bufnr, output_win = utils.float_win("Output", d.output)

    local picker
    picker = require "dotnet.nuget.picker_temp":new({
        results_title = "Packages",
        height = d.picker.height,
        width = d.picker.width,
        row = d.picker.row,
        col = d.picker.col,
        map_to_results_async = function(search_term, callback) map_to_results_async(search_term, pkgs, callback) end,
        on_result_selected = function(val) on_result_selected(val, view_bufnr, view_win) end,
        keymaps = {
            {
                key = "<leader>u",
                callback = function(val)
                    cli.new(output_bufnr):add_package(proj_file, val.value.id, val.value.latest_version)
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
