local M = {}

-- TOOD: Learn how to properly use the NuGet API
local uri = "https://api-v2v3search-0.nuget.org"
local curl = require "plenary.curl"

-- Function to search NuGet packages
function M.query(query, take)
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

return M
