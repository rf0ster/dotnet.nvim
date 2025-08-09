local M = {}

local sync = require "dotnet.nuget.api.sync"
local async = require "dotnet.nuget.api.async"
local cache = require "dotnet.nuget.api.cache"

--- Blocking function that fetches the package base for a specific package ID synchronously.
--- @param pkg_id string The ID of the package to fetch.
--- @return table|nil
--- @usage
--- local data = M.get_pkg_base("Newtonsoft.Json", handle_pkg_base)
--- if data then
---     for _, v in pairs(data.versions) do
---         print("Version: " .. v)
---     end
--- end
function M.get_pkg_base(pkg_id)
    local cached = cache.get_pkg_base(pkg_id)
    if cached then
        return cached
    end
end

--- Non-blocking function that fetches the package base for a specific package ID asynchronously.
--- @param pkg_id string The ID of the package to fetch.
--- @param callback function The callback function to handle the result.
--- The callback will receive two arguments: data (table) and error (string).
--- If the request is successful, data will be a table and error will be nil.
--- If the request fails, data will be nil and error will contain the error message.
--- @return nil
--- @usage
--- local function handle_pkg_base(data, err)
---     if err then
---         print("Error fetching package base: " .. err)
---     else
---         print("Package Base: " .. vim.inspect(data))
---         for _, v in pairs(data.versions) do
---             print("Version: " .. v)
---         end
---     end
--- end
--- M.get_pkg_base("Newtonsoft.Json", handle_pkg_base)
function M.get_pkg_base_async(pkg_id, callback)
    local cached = cache.get_pkg_base(pkg_id)
    if cached then
        callback(cached, nil)
        return
    end
    async.get_pkg_base(pkg_id, callback)
end

--- Blocking function that fetches the registration base for a specific package and version synchronously.
--- @param pkg_id string The ID of the package to fetch.
--- @param version string|nil The version of the package to fetch. If nil, defaults to "index".
--- @return table|nil
--- @usage
--- local data = M.get_pkg_registration("Newtonsoft.Json", "13.0.1", handle_registration)
--- if data then
---     print("Package ID: " .. data.id)
---     print("Package Version: " .. data.version)
---     print("Package Description: " .. data.description)
---     print("Package Authors: " .. (data.authors or "Unknown"))
---     print("Package Icon URL: " .. (data.iconUrl or "No icon"))
---     print("Package Project URL: " .. (data.projectUrl or "No project URL"))
---     print("Package License URL: " .. (data.licenseUrl or "No license URL"))
---     print("Package Dependencies: " .. vim.inspect(data.dependencies))
---     print("Package Tags: " .. vim.inspect(data.tags))
---     print("Package Versions: " .. vim.inspect(data.versions))
--- end
function M.get_pkg_registration(pkg_id, version)
    local cached = cache.get_pkg_registration(pkg_id, version)
    if cached then
        return cached
    end
    return sync.get_pkg_registration(pkg_id)
end

--- Non-blocking function that fetches the registration base for a specific package and version.
--- @param pkg_id string The ID of the package to fetch.
--- @param version string|nil The version of the package to fetch. If nil, defaults to "index".
--- @param callback function The callback function to handle the result.
--- The callback will receive two arguments: data (table) and error (string).
--- If the request is successful, data will be a table and error will be nil.
--- If the request fails, data will be nil and error will contain the error message.
--- @return nil
--- @usage
--- local function handle_registration(data, err)
---     if err then
---         print("Error fetching package registration: " .. err)
---     else
---         print("Package Registration: " .. vim.inspect(data))
---         print("ID: " .. data.id)
---         print("Description: " .. data.description)
---         print("Authors: " .. (data.authors or "Unknown"))
---         print("Icon URL: " .. (data.iconUrl or "No icon"))
---         print("Project URL: " .. (data.projectUrl or "No project URL"))
---         print("License URL: " .. (data.licenseUrl or "No license URL"))
---         print("Dependencies: " .. vim.inspect(data.dependencies))
---         print("Tags: " .. vim.inspect(data.tags))
---         print("Versions: " .. vim.inspect(data.versions))
---     end
--- end
--- M.get_pkg_registration("Newtonsoft.Json", "13.0.1", handle_registration)
function M.get_pkg_registration_async(pkg_id, version, callback)
    local cached = cache.get_pkg_registration(pkg_id, version)
    if cached then
        callback(cached, nil)
        return
    end
    async.get_pkg_registration(pkg_id, version, callback)
end

--- Blocking function that fetches the search query results for a specific query synchronously.
--- @param query string The search query string.
--- @param take integer The number of results to take. Defaults to 20.
--- @return table|nil
--- @usage
--- local data = M.get_search_query("Newtonsoft.Json", 20, true, handle_search)
--- if data then
---     for _, pkg in ipairs(data) do
---         print("Package ID: " .. pkg.id .. ", Version: " .. pkg.version
---     end
--- end
function M.get_search_query(query, take)
    return sync.get_search_query("TODO: Remove this", query, take, false)
end

--- Non-blocking function that fetches the search query results for a specific query asynchronously.
--- @param query string The search query string.
--- @param take integer The number of results to take. Defaults to 20.
--- @param callback function The callback function to handle the result.
--- The callback will receive two arguments: data (table) and error (string).
--- If the request is successful, data will be a table and error will be nil.
--- If the request fails, data will be nil and error will contain the error message.
--- @return nil
--- @usage
--- local function handle_search(data, err)
---     if err then
---         print("Error fetching search results: " .. err)
---     else
---         print("Search Results: " .. vim.inspect(data))
---         for _, pkg in ipairs(data) do
---             print("Package ID: " .. pkg.id .. ", Version: " .. pkg.version
---         end
---     end
--- end
--- M.get_search_query("Newtonsoft.Json", 20, true, handle_search)
function M.get_search_query_async(query, take, callback)
    async.get_search_query(query, take, false, callback)
end

return M
