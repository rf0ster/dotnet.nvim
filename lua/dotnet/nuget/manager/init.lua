local M = {}

local utils = require "dotnet.utils"
local prompt = require "dotnet.nuget.prompt"
local picker = require "dotnet.nuget.picker"
local api = require "dotnet.nuget.api"
local cli = require "dotnet.cli"

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

    M.open_browse_tab(proj_file)
end

function M.open_browse_tab(proj_file)
    -- NugetManager browser layout
    -- ***************************
    -- * header                  *
    -- ***************************
    -- * search     * view       *
    -- **************            *
    -- * packages   **************
    -- *            * install    *
    -- *            *            *
    -- ***************************
    -- * output                  *
    -- ***************************

    -- Create search prompt dimensions
    local search_h = 1
    local search_w = math.floor(M.mgr_dim.width / 2) - 2
    local search_r = M.header_dim.row + M.header_dim.height + 2
    local search_c = M.mgr_dim.col

    -- Create packages picker
    local pkgs_h = M.mgr_dim.height - M.header_dim.height - search_h - 6
    local pkgs_w = search_w
    local pkgs_r = search_r + search_h + 2
    local pkgs_c = M.mgr_dim.col

    -- Create preview window for a single package
    local preview_h = M.mgr_dim.height - M.header_dim.height - 4
    local preview_w = search_w + 2
    local preview_r = search_r
    local preview_c = M.mgr_dim.col + search_w + 2


    -- create package preview window
    local preview_bufnr, preview_win_id = utils.float_win("Preview", {
        height = preview_h,
        width = preview_w,
        row = preview_r,
        col = preview_c,
    })
    vim.api.nvim_buf_set_option(preview_bufnr, "buftype", "nofile")
    vim.api.nvim_buf_set_option(preview_bufnr, "modifiable", false)

    -- create package picker window
    local packages = picker.create({
        title = "Packages",
        win_opts = {
            height = pkgs_h,
            width = pkgs_w,
            row = pkgs_r,
            col = pkgs_c,
        },
        display = function(pkg)
            return pkg.id
        end,
        keymaps = {
            { key = "i", fn = function(pkg) cli.add_package(proj_file, pkg.id, pkg.version) end },
        },
        on_change = function(pkg)
            vim.api.nvim_buf_set_option(preview_bufnr, "modifiable", true)
            vim.api.nvim_buf_set_lines(preview_bufnr, 0, -1, false, {})
            if pkg then
                vim.api.nvim_buf_set_lines(preview_bufnr, 0, 0, false, {
                    " ID: " .. pkg.id,
                    " Version: " .. pkg.version,
                    " Description: ",
                })

                local w = vim.api.nvim_win_get_width(preview_win_id)
                local s = utils.smart_split(pkg.description, w, 3, 1)
                vim.api.nvim_buf_set_lines(preview_bufnr, 3, -1, false, s)
                return
            end
            vim.api.nvim_buf_set_option(preview_bufnr, "modifiable", false)
        end
    })

    -- create search prompt window
    local search = prompt.create({
        title = "Search",
        win_opts = {
            height = search_h,
            width = search_w,
            row = search_r,
            col = search_c,
        },
        on_change = function(val)
            if not val or val == "" then
                packages.set_values({})
                return
            end

            local query = string.match(val, "%S+")
            if not query then
                packages.set_values({})
                return
            end

            local take = 2 * pkgs_h
            local pkg_list = api.query(query, take) or {}
            packages.set_values(pkg_list)
        end
    })

    -- tie windows together on close
    local knot = utils.create_knot({ M.header_win_id, search.win_id, packages.win_id, preview_win_id })

    -- navigation keymaps for header
    local header_opts = { buffer = M.header_bufnr }
    vim.keymap.set("n", "gj", function() vim.api.nvim_set_current_win(search.win_id) end, header_opts)

    -- navigation keymaps for search
    local search_opts = { buffer = search.bufnr }
    vim.keymap.set("n", "gk", function() vim.api.nvim_set_current_win(M.header_win_id) end, search_opts)
    vim.keymap.set("n", "gj", function() vim.api.nvim_set_current_win(packages.win_id) end, search_opts)
    vim.keymap.set("n", "gl", function() vim.api.nvim_set_current_win(preview_win_id) end, search_opts)

    -- navigation keymaps for results
    local packages_opts = { buffer = packages.bufnr }
    vim.keymap.set("n", "gk", function() vim.api.nvim_set_current_win(search.win_id) end, packages_opts)
    vim.keymap.set("n", "gl", function() vim.api.nvim_set_current_win(preview_win_id) end, packages_opts)

    -- navigation keymaps for preview
    local preview_opts = { buffer = preview_bufnr }
    vim.keymap.set("n", "gk", function() vim.api.nvim_set_current_win(M.header_win_id) end, preview_opts)
    vim.keymap.set("n", "gh", function() vim.api.nvim_set_current_win(search.win_id) end, preview_opts)

    -- set cursor to search
    vim.api.nvim_set_current_win(search.win_id)

    -- set mode to insert
    vim.api.nvim_command("startinsert")
end

return M
