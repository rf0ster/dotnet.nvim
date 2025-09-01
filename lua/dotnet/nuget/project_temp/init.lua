local M = {}

local utils = require "dotnet.utils"
local window = require "dotnet.utils.window"
local buffer = require "dotnet.utils.buffer"

local nuget_header = require "dotnet.nuget.project_temp.header"
local nuget_browse = require "dotnet.nuget.project_temp.tab_browse"
local nuget_install = require "dotnet.nuget.project_temp.tab_install"
local nuget_update = require "dotnet.nuget.project_temp.tab_update"

--- Opens a .csproj file in the dotnet package manager UI.
--- @param csproj_file string File path to the .csproj file to open.
function M.open(csproj_file)
    if not csproj_file or csproj_file == "" then
        return
    end

    local tab
    local bufs
    local wins
    local knot

    -- Called every time a tab is switched to with shift + b|i|u
    local function set_tab(opt)
        -- Destroy all existing windows and buffers
        if knot then
            knot.untie()
            knot = nil
        end
        window.destroy(wins)
        buffer.destroy(bufs)

        -- Create new header
        local header = nuget_header.open(csproj_file)
        wins = { header.win }
        bufs = { header.bufnr }

        -- Load the tab that was selected
        if opt == 0 then
            header.tab(0)
            tab = nuget_browse.new(csproj_file)
        elseif opt == 1 then
            header.tab(1)
            tab = nuget_install.open(csproj_file)
        elseif opt == 2 then
            header.tab(2)
            tab = nuget_update.open(csproj_file)
        end

        -- Create a knot of all the windows so that if
        -- one is closed, all are closed
        for _, win in ipairs(tab.windows) do
            table.insert(wins, win)
        end
        utils.create_knot(wins)

        -- Set keymaps in all buffers to switch tabs
        for _, buf in ipairs(tab.buffers) do
            table.insert(bufs, buf)
        end
        utils.set_keymaps(bufs, {
            { mode = "n", key = "B", callback = function() set_tab(0) end },
            { mode = "n", key = "I", callback = function() set_tab(1) end },
            { mode = "n", key = "U", callback = function() set_tab(2) end },
        })
    end

    -- Initialize with the browse tab
    set_tab(0)
end

return M
