-- Creates the compponents for browse tab of the nuget manager.
-- 
-- * header ***********************
-- * browse | installed | updated *
-- ********************************
-- * search     * view            *
-- **************                 *
-- * packages   *                 *
-- *            *                 *
-- *            *                 *
-- ********************************
-- * output                       *
-- ********************************

local M  = {}

local config = require "dotnet.nuget.config"
local utils = require "dotnet.utils"

function M.open()
    local d = utils.get_centered_win_dims(
        config.opts.ui.width,
        config.opts.ui.height
    )
    local header_h = config.defaults.ui.header_h

    -- Create search prompt dimensions
    local search_h = 1
    local search_w = math.floor(d.width / 2) - 2
    local search_r = d.row + header_h + 2
    local search_c = d.col

    -- Create packages picker dimensions
    local pkgs_h = d.height - header_h - search_h - 6
    local pkgs_w = search_w
    local pkgs_r = search_r + search_h + 2
    local pkgs_c = search_c

    -- Create view window for a single package
    local view_h = d.height - header_h - 4
    local view_w = math.floor(d.width / 2)
    local view_r = d.row + header_h + 2
    local view_c = d.col + search_w + 2

    M.search_bufnr, M.search_win = utils.float_win("Search", {
        height = search_h,
        width = search_w,
        row = search_r,
        col = search_c,
        style = config.opts.ui.style,
        border = config.opts.ui.border,
    })
    M.pkgs_bufnr, M.pkgs_win = utils.float_win("Packages", {
        height = pkgs_h,
        width = pkgs_w,
        row = pkgs_r,
        col = pkgs_c,
        style = config.opts.ui.style,
        border = config.opts.ui.border,
    })
    M.view_bufnr, M.view_win = utils.float_win("View", {
        height = view_h,
        width = view_w,
        row = view_r,
        col = view_c,
        style = config.opts.ui.style,
        border = config.opts.ui.border,
    })

    return {
        wins = { M.search_win, M.pkgs_win, M.view_win },
        bufs = { M.search_bufnr, M.pkgs_bufnr, M.view_bufnr },
    }
end

return M
