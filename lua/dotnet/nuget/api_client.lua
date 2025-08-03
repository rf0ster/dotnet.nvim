--- Description: A module to interact with NuGet APIs.
--- Provides caching of service index and search urls.
--- Decodes JSON responses from the NuGet APIs.

local M = {
    service_index = nil,
    service_url = {}
}

local curl = require "plenary.curl"
local api = require "dotnet.nuget.api"

--- Decodes an http response from Nuget APIs that return JSON data.
--- @param res table|nil
local function decode(res)
    if not res or res.status < 200 or 299 < res.status then
        return nil
    end

    local data = vim.fn.json_decode(res.body)
    return data
end

--- Gets the service index for NuGet.
--- If the service index has already
--- been fetched, it returns the cached 
--- value.
--- @return table|nil
function M.get_service_index()
    if M.service_index then
        return M.service_index
    end

    M.service_index = decode(api.get_service_index())
    return M.service_index
end


--- Get the service url for a given resource @id.
--- @param type string
--- @return string|nil
function M.get_service_url(type)
    if M.service_url[type] then
        return M.service_url[type]
    end

    local service_index = M.get_service_index()
    if not service_index then
        return nil
    end

    for _, resource in ipairs(service_index.resources) do
        if resource["@type"] == type then
            M.service_url[type] = resource["@id"]
            return M.service_url[type]
        end
    end
    return nil
end

--- Searches for packages on NuGet.
--- @param query string
--- @param take integer
--- @param prerelease boolean
--- @return table|nil
function M.get_search_query(query, take, prerelease)
    local url = M.get_service_url("SearchQueryService")
    if not url then
        return nil
    end

    local res = decode(api.get_search_query(url, query, take, prerelease))
    if not res then
        return {}
    end

    local results = {}
    for _, item in ipairs(res.data) do
        local pkg = {
            id = item.id,
            version = item.version,
            description = item.description,
            authors = item.authors,
            icon_url = item.iconUrl,
            project_url = item.projectUrl,
            license_url = item.licenseUrl,
        }
        table.insert(results, pkg)
    end

    return results
end

--- Get the NuSpec file for a specific package and version.
--- @param package_id string ID of the package
--- @return table|nil
function M.get_registration_base(package_id, version)
    local service_url = M.get_service_url("RegistrationsBaseUrl")
    if not service_url then
        return nil
    end
    return decode(api.get_registration_base(service_url, package_id, version))
end

--- Get versions for a specific package.
--- @param package_id string ID of the package
--- @return table|nil 
function M.get_versions(package_id)
    local service_url = M.get_service_url("PackageBaseAddress/3.0.0")
    if not service_url then
        return nil
    end

    local res = decode(api.get_service_resource(service_url, package_id))
    if not res or not res.versions then
        return {}
    end

    return res.versions
end

--- Get versions for a specific package.
--- @param package_id string ID of the package
--- @return table|nil 
function M.get_pkg_info(package_id, version)
    local service_url = M.get_service_url("RegistrationsBaseUrl")
    if not service_url then
        return nil
    end

    local res = decode(api.get_registration_base(service_url, package_id, version))
    if not res then
        return nil
    end

    local pkg_info = res.catalogEntry
    if type(pkg_info) == "string" then
        pkg_info = decode(curl.get(res.catalogEntry, { accept = "application/json" }))
    end

    if not pkg_info then
        return nil
    end

    return {
        id = pkg_info.id,
        version = pkg_info.version,
        description = pkg_info.description or "",
        authors = pkg_info.authors or "",
        icon_url = pkg_info.iconUrl or "",
        project_url = pkg_info.projectUrl or "",
        license_url = pkg_info.licenseUrl or "",
    }
end

return M
