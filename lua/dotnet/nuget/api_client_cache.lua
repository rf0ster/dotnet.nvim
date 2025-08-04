local M = {
    cached_pkgs = {}
}

local api_client = require("dotnet.nuget.api_client")

--- Retrieves package information from the cache or API.
--- @param package_id string The ID of the package.
--- @param version string|nil The version of the package. Defaults to "latest".
--- @return table|nil Returns package information if found, otherwise nil.
function M.get_pkg_info(package_id, version)
    if not package_id or package_id == "" then
        return nil
    end
    if not version or version == "" then
        return nil
    end

    if not M.cached_pkgs[package_id] then
        M.cached_pkgs[package_id] = {}
    end

    if M.cached_pkgs[package_id][version] then
        return M.cached_pkgs[package_id][version]
    end

    local pkg_info = api_client.get_pkg_info(package_id, version)
    if pkg_info then
        M.cached_pkgs[package_id][version] = pkg_info
    end

    return pkg_info
end

function M.get_pkg_versions(package_id)
    if not package_id or package_id == "" then
        return {}
    end

    if not M.cached_pkgs[package_id] then
        M.cached_pkgs[package_id] = {}
    end

    if M.cached_pkgs[package_id].versions then
        return M.cached_pkgs[package_id].versions
    end

    local versions = api_client.get_versions(package_id)
    if versions then
        M.cached_pkgs[package_id].versions = versions
    end

    return versions
end

return M
