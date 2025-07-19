-- Description: Module for interacting with the NuGet API.
-- Contains bare bones api logic and does not handle decoding or error handling.
local curl = require "plenary.curl"

local M = {}

--- Gets the service index for NuGet.
--- @return table|nil
function M.get_service_index()
    return curl.get("https://api.nuget.org/v3/index.json", { accept = "application/json" })
end

--- Searches for packages on NuGet.
--- @param url string Service URL for the search query from the service index
--- @param query string Search query string
--- @param take integer Number of results to take
--- @param prerelease boolean Include prerelease packages in the search
--- @return table|nil
function M.get_search_query(url, query, take, prerelease)
    url = url .. "?q=" .. query .. "&take=" .. (take or 20)
    if prerelease then
        url = url .. "&prerelease=true"
    end

    return curl.get(url, { accept = "application/json" })
end

--- Get the NuSpec file for a specific package and version.
--- @param url string Service URL for the package metadata from the service index
--- @param package_id string Package ID
--- @param version string Package version
--- @return table|nil
function M.get_registration_base(url, package_id, version)
    url = url .. package_id:lower() .. "/" .. version:lower() .. ".json"
    return curl.get(url, { accept = "application/json" })
end

--- Get the service resource for a specific package and version.
--- @param service_url string Service URL for the package resource
--- @param package_id string Package ID
--- @param version string Package version
function M.get_service_resource(service_url, package_id, version)
    local pkg = package_id:lower()
    local ver = (version or "index") .. ".json"

    return curl.get(service_url .. pkg .. "/" .. ver, { accept = "application/json" })
end


return M
