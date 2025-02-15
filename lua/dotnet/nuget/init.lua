local M = {}

function M.NugetManager()
	local nuget = require "nuget.api"

	local buf = vim.api.nvim_create_buf(false, true)
	local pkgs = nuget.query("Microsoft")
	for _, pkg in ipairs(pkgs) do
		local details = string.format("%s %s", pkg.id, pkg.version)
		---buffer.append(buf, {details})
	end

	--M.window = window.create(0.8, 0.8, buf)
end

function M.close()
	return M.window.close()
end

return M
