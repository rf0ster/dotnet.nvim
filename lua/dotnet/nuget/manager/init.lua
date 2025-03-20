local M = {}

local utils = require "dotnet.utils"
local prompt = require "dotnet.nuget.prompt"
local picker = require "dotnet.nuget.picker"

function M.open(proj_file)
    M.mgr_dim = utils.center_win(0.8, 0.8)

    -- NugetManager header layout
    -- ********************************
    -- * browse | installed | updates *
    -- ********************************
    M.header_dim = {
        height = 1,
        width = M.mgr_dim.width,
        row = M.mgr_dim.row,
        col = M.mgr_dim.col,
    }
    local header_bufnr, header_win_id = utils.float_win("NugetManager  " .. proj_file, M.header_dim)

    -- write to header
    vim.api.nvim_buf_set_lines(header_bufnr, 0, -1, false, {"  (B)rowse  |  (I)nstalled  |  (U)pdates"})
    vim.api.nvim_buf_set_option(header_bufnr, "modifiable", false)

    M.header_bufnr = header_bufnr
    M.header_win_id = header_win_id

    M.browse()
end

function M.browse()
    -- NugetManager browser layout
    -- ***************************
    -- * header                  *
    -- ***************************
    -- * search     * view       *
    -- **************            *
    -- * packages   **************
    -- *            * install   *
    -- *            *            *
    -- ***************************

    local search_h = 1
    local search_w = math.floor(M.mgr_dim.width / 2)
    local search_r = M.header_dim.row + M.header_dim.height + 2
    local search_c = M.header_dim.col

    local search = prompt.create({
        title = "Search",
        win_opts = {
            height = search_h,
            width = search_w,
            row = search_r,
            col = search_c,
        },
        on_change = function(_)
        end
    })

    local pkgs_h = M.mgr_dim.height - M.header_dim.height - search_h - 2
    local pkgs_w = math.floor(M.mgr_dim.width / 2)
    local pkgs_r = search_r + search_h + 2
    local pkgs_c = search_c

    local packages = picker.create({
        title = "Packages",
        win_opts = {
            height = pkgs_h,
            width = pkgs_w,
            row = pkgs_r,
            col = pkgs_c,
        },
        on_change = function(_) end
    })

    -- set cursor to search
    vim.api.nvim_set_current_win(search.win_id)
end

return M
