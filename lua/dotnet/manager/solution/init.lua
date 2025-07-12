-- Description: This module provides functions to create a window for managing a .NET solution.
-- The window includes options to build, clean, restore, and test the solution.
-- It also allows adding new projects to the solution.

local M = {}

function M.open()
    local sln_info = require("dotnet.manager").load_solution()
    if not sln_info then
        return
    end

    local dotnet_cli = require("dotnet.cli")
    local commands = {
        { name = "Build",        on_execute = function() dotnet_cli.build(sln_info.file) end },
        { name = "Clean",        on_execute = function() dotnet_cli.clean(sln_info.file) end },
        { name = "Restore",      on_execute = function() dotnet_cli.restore(sln_info.file) end },
        { name = "Test",         on_execute = function() dotnet_cli.mstest(sln_info.file) end },
        { name = "Add project",  on_execute = function() print("Add project") end },
        { name = "New console",  on_execute = function() dotnet_cli.new_console(vim.fn.input("Project name: ")) end },
        { name = "New classlib", on_execute = function() dotnet_cli.new_classlib(vim.fn.input("Project name: ")) end },
    }

    local finders = require "telescope.finders"
    local pickers = require "telescope.pickers"
    local sorters = require "telescope.sorters"
    local actions = require "telescope.actions"
    local actions_state = require "telescope.actions.state"

    pickers.new({}, {
        initial_mode = "normal",
        prompt_title = sln_info.sln_name,
        results_title = "Solution Commands",
        finder = finders.new_table {
            results = vim.tbl_map(function(cmd)
                return cmd.name
            end, commands),
        },
        sorter = sorters.get_generic_fuzzy_sorter(),
        sorting_strategy = "ascending",
        layout_strategy = "vertical",
        layout_config = {
            prompt_position = "top",
            width = 0.5,
            height = 0.5,
        },
        attach_mappings = function(_, map)
            map("n", "<CR>", function(prompt_bufnr)
                local selection = actions_state.get_selected_entry().value
                for _, command in ipairs(commands) do
                    if command.name == selection then
                        command.on_execute()
                        break
                    end
                end
                pcall(actions.close, prompt_bufnr)
            end)
            return true
        end,
    }):find()
end

return M
