-- Description: Step-by-step wizard that walks the user through the
-- dotnet build settings for a project: configuration, runtime,
-- verbosity, flags, target framework, and output directory. The
-- assembled command is shown for final edits before it runs.

local M = {}

local pickers = require "telescope.pickers"
local finders = require "telescope.finders"
local actions = require "telescope.actions"
local actions_state = require "telescope.actions.state"

local runtime_selector = require "dotnet.manager.projects.runtime"
local multi_select = require "dotnet.multi_select"
local manager_cli = require "dotnet.manager.cli"

local verbosity_options = {
    { name = "Default",    verbosity = nil },
    { name = "Quiet",      verbosity = "quiet" },
    { name = "Minimal",    verbosity = "minimal" },
    { name = "Normal",     verbosity = "normal" },
    { name = "Detailed",   verbosity = "detailed" },
    { name = "Diagnostic", verbosity = "diagnostic" },
}

local flag_options = {
    { display = "--no-restore       Skip the implicit restore",          value = "--no-restore" },
    { display = "--no-dependencies  Skip project-to-project references", value = "--no-dependencies" },
    { display = "--no-incremental   Force a full rebuild",               value = "--no-incremental" },
    { display = "--force            Force dependencies to be resolved",  value = "--force" },
    { display = "--self-contained   Publish the runtime with the app",   value = "--self-contained" },
}

--- Opens a house-style telescope picker for one wizard step.
--- @param title string The picker title.
--- @param options table List of entries with a `name` field.
--- @param on_choice function Called with the selected entry.
local function pick(title, options, on_choice)
    pickers.new({}, {
        prompt_title = title,
        initial_mode = "normal",
        finder = finders.new_table {
            results = options,
            entry_maker = function(entry)
                return {
                    value = entry,
                    display = entry.name,
                    ordinal = entry.name,
                }
            end,
        },
        layout_strategy = "vertical",
        layout_config = {
            prompt_position = "top",
            width = 0.5,
            height = 0.5,
        },
        attach_mappings = function(_, map)
            map("n", "<CR>", function(prompt_bufnr)
                local selection = actions_state.get_selected_entry()
                pcall(actions.close, prompt_bufnr)
                if selection then
                    on_choice(selection.value)
                end
            end)
            return true
        end,
    }):find()
end

--- Assembles the dotnet build command from the wizard selections.
--- @param project table The project to build.
--- @param state table The wizard selections:
---   configuration, runtime, verbosity, framework, output, flags.
--- @return string cmd The dotnet build command.
function M.build_cmd(project, state)
    local cmd = "dotnet build " .. project.path_abs
    if state.configuration then
        cmd = cmd .. " -c " .. state.configuration
    end
    if state.runtime then
        cmd = cmd .. " -r " .. state.runtime
    end
    if state.framework and state.framework ~= "" then
        cmd = cmd .. " -f " .. state.framework
    end
    if state.output and state.output ~= "" then
        cmd = cmd .. " -o " .. state.output
    end
    if state.verbosity then
        cmd = cmd .. " -v " .. state.verbosity
    end
    for _, flag in ipairs(state.flags or {}) do
        cmd = cmd .. " " .. flag
    end
    return cmd
end

--- Final step: optional framework/output inputs, then an editable
--- command line. Enter runs the command; an empty line cancels.
local function finish(project, state)
    vim.schedule(function()
        state.framework = vim.fn.input("Target framework (empty to skip): ")
        state.output = vim.fn.input("Output dir (empty to skip): ")

        local cmd = vim.fn.input("Run: ", M.build_cmd(project, state))
        if cmd ~= "" then
            manager_cli.get_cli():run_cmd(cmd)
        end
    end)
end

--- Opens the custom build wizard for a project.
--- @param project table The project to build.
function M.open(project)
    if not project then
        return
    end

    local state = {}
    pick("Configuration for " .. project.name, {
        { name = "Debug" },
        { name = "Release" },
    }, function(cfg)
        state.configuration = cfg.name

        pick("Runtime", runtime_selector.runtime_options, function(rt)
            state.runtime = rt.runtime

            pick("Verbosity", verbosity_options, function(v)
                state.verbosity = v.verbosity

                multi_select.open({
                    title = "Build flags",
                    items = flag_options,
                    on_confirm = function(flags)
                        state.flags = flags
                        finish(project, state)
                    end,
                })
            end)
        end)
    end)
end

return M
