local M = { }

local use_cache = true -- Whether to use caching for service index and package data
local cache = {
    service_index = nil, -- Cache for the NuGet service index
    service_resources = {}, -- Cache for service resources
    pkg_registrations = {}, -- Cache for package registations
    pkg_bases = {}, -- Cache for package base addresses
}

function M.setup(opts)
    if opts and opts.use_cache ~= nil then
        use_cache = opts.use_cache
    else
        use_cache = true
    end
end

function M.clear_cache()
    cache.service_index = nil
    cache.service_resources = {}
    cache.pkg_registrations = {}
    cache.pkg_bases = {}
end

function M.get_service_index()
    if use_cache and cache.service_index then
        return cache.service_index
    end
    return nil
end

function M.set_service_index(index)
    if use_cache then
        cache.service_index = index
    end
end

function M.get_service_resource(resource)
    if use_cache and cache.service_resources[resource] then
        return cache.service_resources[resource]
    end
    return nil
end

function M.set_service_resource(resource, value)
    if use_cache then
        cache.service_resources[resource] = value
    end
    return nil
end

local function get_cache_key(pkg_id, version)
    return pkg_id:lower() .. "@" .. (version or "index")
end

function M.get_pkg_registration(pkg_id, version)
    if not use_cache then
        return nil
    end

    if not pkg_id or pkg_id == "" then
        return nil
    end
    if not version or version == "" then
        return nil
    end

    local cache_key = get_cache_key(pkg_id, version)
    return cache.pkg_registrations[cache_key]
end

function M.set_pkg_registration(pkg_id, version, data)
    if not use_cache then
        return nil
    end

    if not pkg_id or pkg_id == "" then
        return nil
    end
    if not version or version == "" then
        return nil
    end

    local cache_key = get_cache_key(pkg_id, version)
    cache.pkg_registrations[cache_key] = data
end

function M.get_pkg_base(pkg_id)
    if not use_cache then
        return nil
    end

    if not pkg_id or pkg_id == "" then
        return nil
    end

    return cache.pkg_bases[pkg_id:lower()]
end

function M.set_pkg_base(pkg_id, data)
    if not use_cache then
        return nil
    end

    if not pkg_id or pkg_id == "" then
        return nil
    end

    cache.pkg_bases[pkg_id:lower()] = data
end

return M
