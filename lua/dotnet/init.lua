local M = {}

local setup_luarocks = function()
    local luarocks_path = vim.fn.systemlist("luarocks path --lr-path")[1]
    local luarocks_cpath = vim.fn.systemlist("luarocks path --lr-cpath")[1]

    if luarocks_path then
        package.path = package.path .. ";" .. luarocks_path
    end
    if luarocks_cpath then
        package.cpath = package.cpath .. ";" .. luarocks_cpath
    end
end

M.setup = function(config)
    setup_luarocks()
    require "dotnet.config".setup(config)

    vim.api.nvim_create_user_command("Dotnet", function(opts)
        if opts == nil then
            return
        end

        if opts.args == "solution" then
            require "dotnet.solution.manager".open()
        elseif opts.args == "projects" then
            require "dotnet.solution.manager".open_projects()
        elseif opts.args == "tests" then
            require "dotnet.test_runner".open()
        end
    end, { nargs = 1 })
end

return M
