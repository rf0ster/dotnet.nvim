local M = {}

-- TOOD: Learn how to properly use the NuGet API
local curl = require "plenary.curl"
local xml2lua = require("xml2lua")
local handler = require("xmlhandler.tree")


--- Query NuGet packages by name
---@param query string
---@param take number
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

--- Get the NuSpec file for a specific package and version
---@param package_id string
---@param version string
---@return table|nil
function M.get_nuspec(package_id, version)
    local id = package_id:lower()
    local ver = version:lower()
    local url = string.format("https://api.nuget.org/v3-flatcontainer/%s/%s/%s.nuspec", id, ver, id)

    local res = curl.get(url, { accept = "application/xml" })
    if res.status < 200 or 299 < res.status then
        print("Response status: " .. res.status)
        return nil
    end

    local tree_handler = handler:new()
    local parser = xml2lua.parser(tree_handler)
    parser:parse(res.body)

    return tree_handler.root

end

--- Get the service index for NuGet
--- @return table|nil
function M.get_service_index()
    local url = "https://api.nuget.org/v3/index.json"
    local res = curl.get(url, { accept = "application/json" })

    if res.status < 200 or 299 < res.status then
        print("Response status: " .. res.status)
        return nil
    end

    local data = vim.fn.json_decode(res.body)
    if not data or not data.resources then
        print("Invalid response format")
        return nil
    end

    return data.resources
end


return M
