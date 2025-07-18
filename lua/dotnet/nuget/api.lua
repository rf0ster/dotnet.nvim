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
--- @param package_id string
--- @return table|nil
function M.get_registration_base(url, package_id, version)
    url = url .. package_id:lower() .. "/" .. version:lower() .. ".json"
    return curl.get(url, { accept = "application/json" })
end

return M
