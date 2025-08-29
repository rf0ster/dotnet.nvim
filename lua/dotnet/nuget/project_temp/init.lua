local M = {}

local nuget_api = require "dotnet.nuget.api"
local buffer = require "dotnet.utils.buffer"
local window = require "dotnet.utils.window"
local utils = require "dotnet.utils"

function M.new()
    require "dotnet.nuget.windows".create({
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
        on_result_selected = function(val, view_buf, view_win, _, _, _)
            if not buffer.is_valid(view_buf) or not window.is_valid(view_win) then
                return
            end

            buffer.clear(view_buf)
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

                local view_w = window.get_dimensions(view_win).width
                local s = utils.split_smart(pkg.description or "", view_w, 3, 1)
                for _, line in ipairs(s) do
                    table.insert(content, line)
                end

                buffer.write(view_buf, content)
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

                        local view_w = window.get_dimensions(view_win).width
                        local s = utils.split_smart(pkg_info.description or "", view_w, 3, 1)
                        for _, line in ipairs(s) do
                            table.insert(content, line)
                        end

                        buffer.write(view_buf, content)
                    end)
                end)
            end
        end
    })
end

return M
