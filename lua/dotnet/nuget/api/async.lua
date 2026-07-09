local M = {}

local cache = require "dotnet.nuget.api.cache"
local endpoints = require "dotnet.nuget.api.endpoints"

--- Async function to fetch data from a URL using curl.
--- @param url string The URL to fetch data from.
--- @param callback function The callback function to handle the result.
--- The callback will receive two arguments: data (table) and error (string).
--- If the request is successful, data will be a table and error will be nil.
--- If the request fails, data will be nil and error will contain the error message.
--- @return nil
--- @usage
--- local function handle_result(data, err)
---     if err then
---         print("Error fetching data: " .. err)
---     else
---         print("Data fetched successfully: " .. vim.inspect(data))
---     end
--- end
--- get("https://api.nuget.org/v3/index.json", handle_result)
local function get(url, callback)
    require "plenary.job":new({
        command = "curl",
        args = { "-s", url },
        on_exit = function(job, code)
            local result = job:result()
            vim.schedule(function()
                if code == 0 then
                    local data = vim.fn.json_decode(result)
                    callback(data)
                else
                    callback(nil, "Failed to fetch data from " .. url)
                end
            end)
        end,
    }):start()
end

--- Fetches the NuGet service index asynchronously.
--- @param callback function The callback function to handle the result.
--- The callback will receive two arguments: data (table) and error (string).
--- If the request is successful, data will be a table and error will be nil.
--- If the request fails, data will be nil and error will contain the error message.
--- @return nil
--- @usage
--- local function handle_index(data, err)
---     if err then
---         print("Error fetching service index: " .. err)
---     else
---         print("Service Index: " .. vim.inspect(data))
---     end
--- end
--- get_serivce_index(handle_index)
local function get_serivce_index(callback)
    local cached = cache.get_service_index()
    if cached then
        callback(cached)
        return
    end

    get(endpoints.uris.service_index, function(data, err)
        if err then
            callback(nil, err)
            return
        end

        if not data or not data.resources then
            callback(nil, "Invalid service index format")
            return
        end

        cache.set_service_index(data)
        callback(data)
    end)
end

--- Gets the service resource URL for a specific type.
--- @param type string The type of the service resource to fetch.
--- @param callback function The callback function to handle the result.
--- The callback will receive two arguments: url (string) and error (string).
--- If the request is successful, url will be a string and error will be nil.
--- If the request fails, url will be nil and error will contain the error message.
--- @return nil
--- @usage
--- local function handle_resource(url, err)
---     if err then
---         print("Error fetching service resource: " .. err)
---     else
---         print("Service Resource URL: " .. url)
---     end
--- end
--- get_service_resource("SearchQueryService", handle_resource)
local function get_service_resource(type, callback)
    local cached = cache.get_service_resource(type)
    if cached then
        callback(cached)
        return
    end

    get_serivce_index(function(data, err)
        if err then
            callback(nil, err)
            return
        end

        if not data or not data.resources then
            callback(nil, "Invalid service index format")
            return
        end

        for _, resource in ipairs(data.resources) do
            if resource["@type"] == type then
                cache.set_service_resource(type, resource["@id"])
                callback(resource["@id"])
                return
            end
        end

        callback(nil, "Resource type not found: " .. type)
    end)
end

--- Fetches the registration base for a specific package and version.
--- @param package_id string The ID of the package to fetch.
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
function M.get_pkg_registration(package_id, version, callback)
    if not package_id or package_id == "" then
        return nil
    end

    local sceduled_callback = vim.schedule_wrap(callback)
    get_service_resource(endpoints.resources.reg_base_url, function(registration_url, registration_err)
        if registration_err then
            sceduled_callback(nil, registration_err)
            return
        end

        if not registration_url then
            sceduled_callback(nil, "RegistrationBaseUrl not found")
            return
        end

        local url = registration_url .. package_id:lower() .. "/" .. (version or "index") .. ".json"
        get(url, function(data, err)
            if err then
                sceduled_callback(nil, err)
                return
            end
            if not data then
                sceduled_callback(nil, "Failed to fetch registration base for " .. package_id)
                return
            end

            local pkg_info = data.catalogEntry
            if type(pkg_info) ~= "string" then
                sceduled_callback(pkg_info)
            end

            -- If the catalogEntry is a URL, fetch it
            get(pkg_info, function(r, e)
                if e then
                    sceduled_callback(nil, e)
                    return
                end
                if not r then
                    sceduled_callback(nil, "Failed to fetch catalog entry for " .. package_id)
                    return
                end
                cache.set_pkg_registration(package_id, version, r)
                sceduled_callback(r)
            end)
        end)
    end)
end

--- Fetches the package base address for a specific package ID.
--- @param package_id string The ID of the package to fetch.
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
function M.get_pkg_base(package_id, callback)
    if not package_id or package_id == "" then
        return nil
    end

    local sceduled_callback = vim.schedule_wrap(callback)
    get_service_resource(endpoints.resources.pkg_base_addr, function(base_url, base_err)
        if base_err then
            sceduled_callback(nil, base_err)
            return
        end

        if not base_url then
            sceduled_callback(nil, "PackageBaseAddress not found")
            return
        end

        local url = base_url .. package_id:lower() .. "/index.json"
        get(url, function(data, err)
            if err then
                sceduled_callback(nil, err)
                return
            end
            if not data then
                sceduled_callback(nil, "Failed to fetch package base for " .. package_id)
                return
            end

            cache.set_pkg_base(package_id, data)
            sceduled_callback(data)
        end)
    end)
end

--- Fetches the search query results for a specific query.
--- @param query string The search query string.
--- @param take integer The number of results to take. Defaults to 20.
--- @param prerelease boolean Whether to include prerelease packages. Defaults to false.
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
function M.get_search_query(query, take, prerelease, callback)
    if not query or query == "" then
        return nil
    end

    local sceduled_callback = vim.schedule_wrap(callback)
    get_service_resource(endpoints.resources.search_query, function(search_url, search_err)
        if search_err then
            sceduled_callback(nil, search_err)
            return
        end

        if not search_url then
            sceduled_callback(nil, "SearchQueryService not found")
            return
        end

        local url = search_url .. "?q=" .. query .. "&take=" .. (take or 20)
        if prerelease then
            url = url .. "&prerelease=true"
        end

        get(url, function(data, err)
            if err then
                sceduled_callback(nil, err)
                return
            end
            if not data then
                sceduled_callback(nil, "Failed to fetch search results for " .. query)
                return
            end

            sceduled_callback(data.data or {})
        end)
    end)
end

return M
