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

    local subcommands = {
        solution   = function() require "dotnet.manager.solution".open() end,
        projects   = function() require "dotnet.manager.projects".open() end,
        proj_build = function(configuration) require "dotnet.manager.projects".build_current(configuration) end,
        proj_nuget = function() require "dotnet.manager.projects".nuget_current() end,
        proj_ref   = function() require "dotnet.manager.projects".references_current() end,
        nuget      = function() require "dotnet.nuget.solution".open() end,
        tests      = function() require "dotnet.test_runner".open() end,
        history    = function() require "dotnet.manager.history".open() end,
        last_cmd   = function() require "dotnet.manager.history".run_last_cmd() end,
    }

    -- Completions for a subcommand's optional second argument
    local subcommand_args = {
        proj_build = { "debug", "release" },
    }

    vim.api.nvim_create_user_command("Dotnet", function(opts)
        local subcommand = subcommands[opts.fargs[1]]
        if subcommand then
            subcommand(opts.fargs[2])
        else
            vim.api.nvim_echo({{"[Warning] Unknown Dotnet command: " .. opts.fargs[1], "WarningMsg"}}, true, {})
        end
    end, {
        nargs = "+",
        complete = function(arglead, cmdline)
            -- Completing the second argument when the subcommand has one
            local subcommand = cmdline:match("^%s*Dotnet%s+(%S+)%s")
            local candidates = subcommand and (subcommand_args[subcommand] or {})
                or vim.tbl_keys(subcommands)

            return vim.tbl_filter(function(c)
                return vim.startswith(c, arglead)
            end, candidates)
        end,
    })
end

return M
