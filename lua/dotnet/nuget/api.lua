local M = {}

-- Function to search NuGet packages
function M.query(query)
	local curl = require "plenary.curl"
	local res = curl.get("https://api-v2v3search-0.nuget.org/query?q=" .. query .. "&take=10")

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
