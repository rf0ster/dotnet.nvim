-- Description: Module that provides runtime selection functionality
-- for build and publish operations.

local M = {}

local pickers = require "telescope.pickers"
local finders = require "telescope.finders"
local actions = require "telescope.actions"
local actions_state = require "telescope.actions.state"

-- Common runtime identifiers
local runtime_options = {
    { name = "Framework-dependent (no runtime)", runtime = nil },
    { name = "Windows x64", runtime = "win-x64" },
    { name = "Windows x86", runtime = "win-x86" },
    { name = "Windows ARM64", runtime = "win-arm64" },
    { name = "Linux x64", runtime = "linux-x64" },
    { name = "Linux ARM", runtime = "linux-arm" },
    { name = "Linux ARM64", runtime = "linux-arm64" },
    { name = "macOS x64", runtime = "osx-x64" },
    { name = "macOS ARM64", runtime = "osx-arm64" },
    { name = "Alpine x64", runtime = "alpine-x64" },
    { name = "Alpine ARM64", runtime = "alpine-arm64" },
}

--- Opens runtime selection picker
--- @param project table The project information
--- @param configuration string The build configuration (Debug/Release)
--- @param operation string The operation type ("Build" or "Publish")
function M.open(project, configuration, operation)
    if not project or not configuration or not operation then
        return
    end

    local cli = require "dotnet.manager.cli".get_cli()

    local finder = finders.new_table {
        results = runtime_options,
        entry_maker = function(entry)
            return {
                value = entry,
                display = entry.name,
                ordinal = entry.name,
            }
        end,
    }

    pickers.new({}, {
        prompt_title = "Select Runtime for " .. configuration .. " " .. operation,
        initial_mode = "normal",
        finder = finder,
        layout_strategy = "vertical",
        layout_config = {
            prompt_position = "top",
            width = 0.5,
            height = 0.5,
        },
        attach_mappings = function(_, map)
            map("n", "<CR>", function(prompt_bufnr)
                local selection = actions_state.get_selected_entry()
                actions.close(prompt_bufnr)

                if operation == "Build" then
                    cli:build(project.path_abs, configuration, selection.value.runtime)
                elseif operation == "Publish" then
                    cli:publish(project.path_abs, configuration, selection.value.runtime)
                end
            end)
            return true
        end,
    }):find()
end

return M
