local M = {}

local buffer = require "dotnet.utils.buffer"
local window = require "dotnet.utils.window"
local utils = require "dotnet.utils"
local fuzzy = require "dotnet.nuget.fuzzy"
local api = require "dotnet.nuget.api"
local confirm = require "dotnet.confirm"
local cli = require "dotnet.nuget.cli"

--- Given a search term, filters through the list of installed packages
--- and maps the results to a format suitable for display in the picker.
--- @param search_term string The term to filter packages by.
--- @param pkgs table The list of installed packages to filter.
--- @return table A list of packages that match the search term.
local function map_to_results(search_term, pkgs)
    -- Fuzzy filter on the package id
    local filtered_pkgs = fuzzy.filter(
        pkgs or {}, search_term, function(pkg) return pkg.id end)

    -- Results expected by picker
    local results = {}
    for _, pkg in ipairs(filtered_pkgs or {}) do
        if pkg and pkg.id and pkg.version then
            table.insert(results, {
                display = pkg.id .. "@" .. pkg.version,
                value = pkg,
            })
        end
    end
    return results
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
            buffer.write(view_bufnr, {
                "Package Information",
                "===================",
                "",
                " ID: " .. pkg.id,
                " Version: " .. pkg.version,
                " Authors: " .. (pkg.authors or "Unknown"),
                " Description: ",
            })

            local w = window.get_dimensions(view_win).width
            local s = utils.split_smart(pkg.description, w, 3, 1)

            buffer.append_lines(view_bufnr,  s)
        end
    end)
end

--- Keymap to uninstall a package from the project.
--- Prompts for confirmation before proceeding.
--- @param val table The selected package value from the picker.
--- @param proj_file string The .csproj file path to uninstall from.
--- @param output_bufnr number The buffer number for output messages.
local function uninstall_keymap(val, proj_file, output_bufnr)
    confirm.open({
        prompt_title = "Remove Reference",
        prompt = {
            "Remove " .. val.value.id .. " v" .. val.value.version,
            "from " .. proj_file .. "?"
        },
        on_confirm = function()
            cli.new(output_bufnr):remove_package(proj_file, val.value.id)
        end
    })
end

--- Opens the tab for installing a package into a .csproj file.
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
        map_to_results = function(search_term) return map_to_results(search_term, pkgs) end,
        on_result_selected = function(val) on_result_selected(val, view_bufnr, view_win) end,
        keymaps = {
            {
                key = "<leader>u",
                callback = function(val) uninstall_keymap(val, proj_file, output_bufnr) end
            }
        }
    })

    return {
        windows = { view_win, output_win, picker.results_win, picker.search_win },
        buffers = { view_bufnr, output_bufnr, picker.results_bufnr, picker.search_bufnr }
    }
end
return M
