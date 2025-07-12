local M = {}

-- TOOD: Learn how to properly use the NuGet API
local curl = require "plenary.curl"

-- Function to search NuGet packages
function M.query(query, take)
    local uri = "https://api-v2v3search-0.nuget.org"
	local res = curl.get(uri .. "/query?q=" .. query .. "&take=" .. take)

	local packages = {}
	if res.status == 200 then
		local data = vim.fn.json_decode(res.body)
		for _, item in ipairs(data.data) do
			packages[#packages + 1] = {
				id = item.id,
				version = item.version,
				description = item.description,
			}
		end
	end

	return packages
end

--- Get dependencies of a NuGet package given ID and version
---@param package_id string
---@param version string
---@return table|nil
function M.get_dependencies(package_id, version)
    local uri = "https://api.nuget.org/v3/registration5-semver1";
    local url = string.format(uri .. "/%s/%s.json", package_id:lower(), version:lower())

    print(url)
    local res = curl.get(url)
    print(res.status)
    if res.status ~= 200 then
        print("Failed to fetch .nuspec for " .. package_id .. "@" .. version)
        return nil
    end

    -- Print the response body for debugging using the inspect
    print(vim.inspect(res.body))

    local deps = {}
    local dependencies_block = res.body:match("<dependencies.->(.-)</dependencies>")
    if not dependencies_block then
        return deps
    end

    for dep_id, dep_ver in dependencies_block:gmatch('<dependency id="(.-)" version="(.-)"') do
        table.insert(deps, { id = dep_id, version = dep_ver })
    end

    return deps
end

return M
