--- Description: Solution-level nuget manager.
--- Manages NuGet packages across every project in the solution with the
--- same tabbed floating-window UI as the project-level manager:
--- Browse, Installed, Updates, and Consolidate tabs.

local M = {}

local utils = require "dotnet.utils"
local window = require "dotnet.utils.window"
local buffer = require "dotnet.utils.buffer"

local nuget_header = require "dotnet.nuget.header"
local tab_browse = require "dotnet.nuget.solution.tab_browse"
local tab_installed = require "dotnet.nuget.solution.tab_installed"
local tab_updates = require "dotnet.nuget.solution.tab_updates"
local tab_consolidate = require "dotnet.nuget.solution.tab_consolidate"

--- Opens the solution nuget manager for the solution in the current directory.
function M.open()
    local sln = require "dotnet.manager".load_solution()
    if not sln then
        return
    end

    local tab
    local bufs
    local wins
    local knot
    local prerelease = false
    local current_tab = 0

    -- Called every time a tab is switched to with shift + b|i|u|c
    local function set_tab(opt)
        current_tab = opt

        -- Destroy all existing windows and buffers
        if knot then
            knot.untie()
            knot = nil
        end
        window.destroy(wins)
        buffer.destroy(bufs)

        -- Create new header
        local header = nuget_header.open({
            title = "NugetManager  -  " .. sln.sln_name,
            tabs = {
                { key = "B", label = "Browse" },
                { key = "I", label = "Installed" },
                { key = "U", label = "Updates" },
                { key = "C", label = "Consolidate" },
            },
            prerelease = prerelease,
        })
        wins = { header.win }
        bufs = { header.bufnr }

        -- Load the tab that was selected
        if opt == 0 then
            header.tab(0)
            tab = tab_browse.new(sln, { prerelease = prerelease })
        elseif opt == 1 then
            header.tab(1)
            tab = tab_installed.open(sln)
        elseif opt == 2 then
            header.tab(2)
            tab = tab_updates.open(sln)
        elseif opt == 3 then
            header.tab(3)
            tab = tab_consolidate.open(sln, { prerelease = prerelease })
        end

        -- Create a knot of all the windows so that if
        -- one is closed, all are closed
        for _, win in ipairs(tab.windows) do
            table.insert(wins, win)
        end
        knot = utils.create_knot(wins)

        -- Set keymaps in all buffers to switch tabs
        for _, buf in ipairs(tab.buffers) do
            table.insert(bufs, buf)
        end
        utils.set_keymaps(bufs, {
            { mode = "n", key = "B", callback = function() set_tab(0) end },
            { mode = "n", key = "I", callback = function() set_tab(1) end },
            { mode = "n", key = "U", callback = function() set_tab(2) end },
            { mode = "n", key = "C", callback = function() set_tab(3) end },
            {
                mode = "n",
                key = "P",
                callback = function()
                    prerelease = not prerelease
                    set_tab(current_tab)
                end
            },
        })
    end

    -- Initialize with the browse tab
    set_tab(0)
end

return M
