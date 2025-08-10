local M = {}

local dotnet_utils = require "dotnet.utils"
local dotnet_window = require "dotnet.utils.window"
local dotnet_buffer = require "dotnet.utils.buffer"

local nuget_window = require "dotnet.nuget.window"
local nuget_config = require "dotnet.nuget.config"
local nuget_api = require "dotnet.nuget.api"
local nuget_cli = require "dotnet.nuget.cli"

local NugetPicker = require "dotnet.nuget.picker_temp"

local function search_pkgs(search_term, callback)
end

function M.open(proj_file)
    local d = nuget_window.get_dimensions()
    local header_h = nuget_config.defaults.ui.header_h

    -- Define output window height before creating the picke
    -- so that it can be used in the picker and view dimensions.
    local output_h = 6
    local output_w = d.width

    local picker_h = d.height - header_h - output_h - 4
    local picker_w = math.floor(d.width / 2) - 2
    local picker_r = d.row + header_h + 2
    local picker_c = d.col

    -- Create view window for a single package
    local view_h = d.height - header_h - output_h - 4
    local view_w = math.floor(d.width / 2)
    local view_r = d.row + header_h + 2
    local view_c = d.col + picker_w + 2

    -- Define the rest of the output window dimensions
    -- based on the picker and view dimensions.
    local output_r = picker_r + picker_h + 2
    local output_c = d.col

    M.output_bufnr, M.output_win = dotnet_utils.float_win("Output", {
        height = output_h,
        width = output_w,
        row = output_r,
        col = output_c,
        style = nuget_config.opts.ui.style,
        border = nuget_config.opts.ui.border,
    })

    M.view_bufnr, M.view_win = dotnet_utils.float_win("View", {
        height = view_h,
        width = view_w,
        row = view_r,
        col = view_c,
        style = nuget_config.opts.ui.style,
        border = nuget_config.opts.ui.border,
    })

    local showing_versions = false
    M.picker = NugetPicker:new({
        row = picker_r,
        col = picker_c,
        width = picker_w,
        height = picker_h,
        results_title = "  leader + (i)nstall | (v)ersions",
        map_to_results_async = function(search_term, callback)
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
        end,
        on_result_selected = function(val)
            if not M.view_bufnr or not vim.api.nvim_buf_is_valid(M.view_bufnr) then
                return
            end

            dotnet_buffer.clear(M.view_bufnr)
            if not val or not val.value then
                return
            end

            local pkg = val.value
            if pkg.is_package then
                local content = {
                    " ID: " .. pkg.id,
                    " Version: " .. pkg.version,
                    " Authors: " .. (pkg.authors[1] or ""),
                    " Project URL: " .. (pkg.project_url or ""),
                    " Description: "
                }

                local s = dotnet_utils.split_smart(pkg.description or "", view_w, 3, 1)
                for _, line in ipairs(s) do
                    table.insert(content, line)
                end

                dotnet_buffer.write(M.view_bufnr, content)
            else
                vim.schedule(function()
                    nuget_api.get_pkg_registration_async(pkg.id, pkg.version, function(pkg_info)
                        local content = {
                            " ID: " .. pkg_info.id,
                            " Version: " .. pkg_info.version,
                            " Authors: " .. (pkg_info.authors[1] or ""),
                            " Project URL: " .. (pkg_info.project_url or ""),
                            " Description: "
                        }

                        local s = dotnet_utils.split_smart(pkg_info.description or "", view_w, 3, 1)
                        for _, line in ipairs(s) do
                            table.insert(content, line)
                        end

                        dotnet_buffer.write(M.view_bufnr, content)
                    end)
                end)
            end
        end,
        keymaps = {
            {
                key = "<leader>i",
                callback = function(val)
                    if not val or not val.value then
                        return
                    end

                    local cli = nuget_cli.new(M.output_bufnr, M.output_win)
                    cli:add_package(proj_file, val.value.id, val.value.version)
                end
            },
            {
                key = "<leader>v",
                callback = function(val)
                    if showing_versions then
                        showing_versions = false
                        M.picker:refresh_results()
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
                    M.picker:set_display_values(new_results)
                end
            }
        }
    })

    M.search_bufnr = M.picker.search_bufnr
    M.search_win = M.picker.search_win

    M.results_bufnr = M.picker.results_bufnr
    M.results_win = M.picker.results_win

    return {
        wins = { M.search_win, M.results_win, M.view_win, M.output_win },
        bufs = { M.search_bufnr, M.results_bufnr, M.view_bufnr, M.output_bufnr },
        close = function()
            dotnet_window.close(M.search_win)
            dotnet_window.close(M.results_win)
            dotnet_window.close(M.view_win)
            dotnet_window.close(M.output_win)

            dotnet_buffer.delete(M.search_bufnr)
            dotnet_buffer.delete(M.results_bufnr)
            dotnet_buffer.delete(M.view_bufnr)
            dotnet_buffer.delete(M.output_bufnr)

            M.picker:close()
            M.search_bufnr = nil
            M.results_bufnr = nil
            M.view_bufnr = nil
            M.output_bufnr = nil
        end
    }
end

return M
