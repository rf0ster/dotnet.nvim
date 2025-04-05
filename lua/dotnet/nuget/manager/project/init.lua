-- Creates nuget manager
-- 
-- * header ***********************
-- * browse | installed | updates *
-- ********************************
-- * search     * view            *
-- **************                 *
-- * packages   *                 *
-- *            *                 *
-- *            *                 *
-- ********************************
-- * output                       *
-- ********************************
local M = {}

local header = require "dotnet.nuget.manager.project.header"
local tab_b = require "dotnet.nuget.manager.project.browse"
local tab_i = require "dotnet.nuget.manager.project.installed"
local tab_u = require "dotnet.nuget.manager.project.updates"
local utils = require "dotnet.utils"

-- opens the nuget manager
function M.open(proj_file)
    M.close()
    M.header = header.open(proj_file)
    M.proj_file = proj_file
    M.open_tab(0)
end

-- closes the nuget manager
function M.close()
    M.close_tab()
    if M.header then
        local win = M.header.win
        local buf = M.header.bufnr
        if win and vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_close(win, true)
        end
        if buf and vim.api.nvim_buf_is_valid(buf) then
            vim.api.nvim_buf_delete(buf, { force = true })
        end
    end
    M.header = nil
    M.proj_file = nil
end

-- closes the current tab
function M.close_tab()
    if M.knot then
        M.knot.untie()
        M.knot = nil
    end

    if M.tab then
        for _, win in ipairs(M.tab.wins or {}) do
            if win ~= nil and vim.api.nvim_win_is_valid(win) then
                vim.api.nvim_win_close(win, true)
            end
        end
        for _, buf in ipairs(M.tab.bufs or {}) do
            if buf ~= nil and vim.api.nvim_buf_is_valid(buf) then
                vim.api.nvim_buf_delete(buf, { force = true })
            end
        end
        M.tab = nil
    end
end

-- selects the tab to be opened
function M.open_tab(opt)
    if not M.header or not M.proj_file then
        return
    end

    if opt < 0 or opt > 2 then
        return
    end

    M.close_tab()
    M.header.tab(opt)

    if opt == 0 then
        M.tab = tab_b.open(M.proj_file)
    elseif opt == 1 then
        M.tab = tab_i.open(M.proj_file)
    elseif opt == 2 then
        M.tab = tab_u.open()
    end

    local bufs = {M.header.bufnr}
    if M.tab and M.tab.bufs then
        for _, buf in ipairs(M.tab.bufs) do
            if buf ~= nil and vim.api.nvim_buf_is_valid(buf) then
                table.insert(bufs, buf)
            end
        end
    end

    -- set each buffer to map shift commands to switch tabs
    utils.set_keymaps(bufs, {
        { mode = "n", key = "B", callback = function() M.open_tab(0) end },
        { mode = "n", key = "I", callback = function() M.open_tab(1) end },
        { mode = "n", key = "U", callback = function() M.open_tab(2) end },
    })

    -- Create a knot for all the new windows in the tab.
    -- This makes sure that when one of the windows is closed, all are closed.
    local wins = {M.header.win}
    if M.tab and M.tab.wins then
        for _, win in ipairs(M.tab.wins) do
            if win ~= nil and vim.api.nvim_win_is_valid(win) then
                table.insert(wins, win)
            end
        end
    end
    -- print wins
    M.knot = utils.create_knot(wins)

    -- set foucus on the first window
    if M.tab and M.tab.wins and #M.tab.wins > 0 then
        vim.api.nvim_set_current_win(M.tab.wins[1])
    else
        vim.api.nvim_set_current_win(M.header.win)
    end
end

return M
