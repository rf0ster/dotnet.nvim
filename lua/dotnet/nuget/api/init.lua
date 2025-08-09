local M = {}

local sync = require "dotnet.nuget.api.sync"
local async = require "dotnet.nuget.api.async"
local cache = require "dotnet.nuget.api.cache"

function M.get_pkg_base(pkg_id)
    local cached = cache.get_pkg_base(pkg_id)
    if cached then
        return cached
    end
end

function M.get_pkg_base_async(pkg_id, callback)
    local cached = cache.get_pkg_base(pkg_id)
    if cached then
        callback(cached, nil)
        return
    end
    async.get_pkg_base(pkg_id, callback)
end

function M.get_pkg_registration(pkg_id, version)
    local cached = cache.get_pkg_registration(pkg_id, version)
    if cached then
        return cached
    end
    return sync.get_pkg_registration(pkg_id)
end

function M.get_pkg_registration_async(pkg_id, version, callback)
    local cached = cache.get_pkg_registration(pkg_id, version)
    if cached then
        callback(cached, nil)
        return
    end
    async.get_pkg_registration(pkg_id, version, callback)
end

function M.get_search_query(search_term, take)
    return sync.get_search_query("TODO: Remove this", search_term, take, false)
end

function M.get_search_query_async(search_term, take, callback)
    async.get_search_query(search_term, take, false, callback)
end

return M
