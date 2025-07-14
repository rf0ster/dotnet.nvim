
local curl = require "plenary.curl"
local xml2lua = require("xml2lua")
local handler = require("xmlhandler.tree")

local M = {}

--- Decodes an http response from Nuget APIs that return JSON data.
--- @param res table
local function decode_json_response(res)
    if res.status < 200 or 299 < res.status then
        return nil
    end

    local data = vim.fn.json_decode(res.body)
    return data
end

--- Gets the service index for NuGet.
--- @return table|nil
function M.get_service_index()
    if M.service_index then
        return M.service_index
    end

    local url = "https://api.nuget.org/v3/index.json"
    local res = curl.get(url, { accept = "application/json" })

    M.service_index = decode_json_response(res)
    return M.service_index
end


--- Get the service url for a given resource @id.
--- @param type string
--- @return string|nil
function M.get_service_url(type)
    local service_index = M.get_service_index()
    if not service_index then
        return nil
    end

    for _, resource in ipairs(service_index.resources) do
        if resource["@type"] == type then
            return resource["@id"]
        end
    end
    return nil
end

--- Searches for packages on NuGet.
--- @param query string
--- @param take integer
--- @param prerelease boolean
--- @return table|nil
function M.search_query(query, take, prerelease)
    local url = M.get_service_url("SearchQueryService")
    if not url then
        return nil
    end

    local uri = url .. "?q=" .. query .. "&take=" .. (take or 20)
    if prerelease then
        uri = uri .. "&prerelease=true"
    end

    local res = curl.get(uri, { accept = "application/json" })
    return decode_json_response(res)
end

--- Get the NuSpec file for a specific package and version.
--- @param package_id string
--- @return table|nil
function M.get_registration_base(package_id, version)
    local service_url = M.get_service_url("RegistrationsBaseUrl")
    if not service_url then
        return nil
    end

    local url = service_url .. package_id:lower() .. "/" .. version:lower() .. ".json"
    local res = curl.get(url, { accept = "application/json" })

    return decode_json_response(res)
end

--- Put back the test function I had a little while ago
function M.test(package_id, take)
    local search_query = M.search_query(package_id, take, true)
    if search_query == nil then
        return
    end

    local pkg = nil
    for _, item in ipairs(search_query.data) do
        if item.id == package_id then
            pkg = item
            break
        end
    end

    if pkg == nil then
        return
    end
    print("Found package: " .. pkg.id .. " version: " .. pkg.version)

    local nuspec = M.get_registration_base(pkg.id, pkg.version)
    if nuspec == nil then
        return
    end
    print("Nuspec for " .. pkg.id .. " version " .. pkg.version .. ":")
    print(vim.inspect(nuspec))
end
return M
