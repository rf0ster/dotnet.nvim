-- Description: A multi-select modal for choosing solution projects.
-- Thin wrapper over the generic multi-select modal; used by the
-- solution-level nuget manager to pick which projects an operation
-- applies to. Confirming with no projects selected counts as a cancel.

local M = {}

local multi_select = require "dotnet.multi_select"

--- Opens a multi-select modal over the current UI.
--- @param opts table Options:
---   - title (string): The window title.
---   - projects (table): List of solution projects to choose from.
---   - preselected (table|nil): Set of project names to preselect, e.g. { ["App"] = true }.
---   - on_confirm (function): Called with the list of selected projects.
---   - on_cancel (function|nil): Called when the modal is dismissed.
function M.open(opts)
    opts = opts or {}
    local preselected = opts.preselected or {}
    local on_confirm = opts.on_confirm or function(_) end
    local on_cancel = opts.on_cancel or function() end

    local items = {}
    for _, project in ipairs(opts.projects or {}) do
        table.insert(items, {
            display = project.name,
            value = project,
            checked = preselected[project.name] or false,
        })
    end

    multi_select.open({
        title = opts.title or "Select Projects",
        items = items,
        on_cancel = on_cancel,
        on_confirm = function(selected)
            if #selected == 0 then
                on_cancel()
            else
                on_confirm(selected)
            end
        end,
    })
end

return M
