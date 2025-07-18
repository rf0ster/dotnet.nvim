
local M = {}

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
--- @param package_id string
--- @return table|nil
function M.get_registration_base(package_id, version)
    local service_url = M.get_service_url("RegistrationsBaseUrl")
    if not service_url then
        return nil
    end
    return decode(api.get_registration_base(service_url, package_id, version))
end

--- Put back the test function I had a little while ago
function M.test(package_id, take)
    local search_query = M.get_search_query(package_id, take, true)
    if search_query == nil then
        return
    end

    print("Search results for " .. package_id .. ":")
    local pkg = nil
    for _, item in ipairs(search_query.data) do
        print("  " .. item.id .. " version: " .. item.version)
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
