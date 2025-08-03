local M = {
    cached_pkgs = {}
}

local api_client = require("dotnet.nuget.api_client")

function M.get_pkg_info(package_id, version)
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

return M
