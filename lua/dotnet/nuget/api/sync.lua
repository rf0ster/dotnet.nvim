-- Description: Synschronous api for interacting with the NuGet.
local curl = require "plenary.curl"
local cache = require "dotnet.nuget.api.cache"
local endpoints = require "dotnet.nuget.api.endpoints"

local M = {}

local function decode_json(response)
    if response and response.body and response.code == 200 then
        return vim.json.decode(response.body)
    end
    return nil
end

--- Gets the service index for NuGet.
--- @return table|nil
local function get_service_index()
    local cached = cache.get_service_index()
    if cached then
        return cached
    end

    local res = decode_json(curl.get("https://api.nuget.org/v3/index.json", { accept = "application/json" }))
    cache.set_service_index(res)
    return res
end

--- Gets the service resource for a specific resource type.
--- @param resource string The resource type to search for (e.g., "RegistrationsBaseUrl", "SearchQueryService", etc.)
--- @return string|nil The service resource URL if found, nil otherwise.
local function get_service_resource(resource)
    local cached = cache.get_service_resource(resource)
    if cached then
        return cached
    end

    local service_index = get_service_index()
    if not service_index or not service_index.resources then
        return nil
    end

    for _, res in ipairs(service_index.resources) do
        if res["@type"] == resource then
            local r = res["@id"]
            cache.set_service_resource(resource, r)
            return r
        end
    end

    return nil
end

--- Searches for packages on NuGet.
--- @param url string Service URL for the search query from the service index
--- @param query string Search query string
--- @param take integer Number of results to take
--- @param prerelease boolean Include prerelease packages in the search
--- @return table|nil
function M.get_search_query(url, query, take, prerelease)
    local service_url = get_service_resource(endpoints.resources.search_query)
    if not service_url then
        return nil
    end

    url = url .. "?q=" .. query .. "&take=" .. (take or 20)
    if prerelease then
        url = url .. "&prerelease=true"
    end

    return decode_json(curl.get(url, { accept = "application/json" }))
end

--- Gets the package registration for the specified package ID and version.
--- @param pkg_id string The ID of the package to fetch.
--- @return table|nil
function M.get_pkg_registration(pkg_id, version)
    local service_url = get_service_resource(endpoints.resources.reg_base_url)
    if not service_url then
        return nil
    end

    local url = service_url .. pkg_id
    if version then
        url = url .. "/" .. version
    else
        url = url .. "/index"
    end

    return decode_json(curl.get(url, { accept = "application/json" }))
end

--- Gets the package base address for the specified package ID.
--- @param pkg_id string The ID of the package to fetch.
--- @return table|nil
function M.get_pkg_base(pkg_id)
    local service_url = get_service_resource(endpoints.resources.pkg_base_addr)
    if not service_url then
        return nil
    end

    local url = service_url .. "/" .. pkg_id
    return decode_json(curl.get(url, { accept = "application/json" }))
end

return M
