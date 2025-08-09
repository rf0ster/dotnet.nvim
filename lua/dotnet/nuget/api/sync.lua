-- Description: Synschronous api for interacting with the NuGet.
local curl = require "plenary.curl"

local M = {}

--- Gets the service index for NuGet.
--- @return table|nil
local function get_service_index()
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

--- Get the service resource for a specific package and version.
--- @param service_url string Service URL for the package resource
--- @param package_id string Package ID
--- @param version string|nil Package version
function M.get_service_resource(service_url, package_id, version)
    local url = service_url .. package_id:lower() .. "/" .. (version or "index") .. ".json"
    return curl.get(url, { accept = "application/json" })
end

--- Get the flat container index for a specific package.
--- @param package_id string Package ID
--- @return table|nil
function M.get_flat_container_index(package_id)
    local url = "https://api.nuget.org/v3-flatcontainer/" .. package_id:lower() .. "/index.json"
    return curl.get(url, { accept = "application/json" })
end

--- Get the flat container nuspec for a specific package.
--- @param package_id string Package ID
--- @return table|nil
function M.get_flat_container_nuspec(package_id, version)
    local url = "https://api.nuget.org/v3-flatcontainer/" .. package_id:lower() .. "/" .. (version or "index") .. ".nuspec"
    return curl.get(url, { accept = "application/xml" })
end


return M
