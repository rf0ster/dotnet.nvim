-- Creates the compponents for updates tab of the nuget manager.
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

local M  = {}

local manager = require "dotnet.manager"
local utils = require "dotnet.utils"
local cli = require "dotnet.cli"
local config = require "dotnet.nuget.config"
local prompt = require "dotnet.nuget.prompt"
local picker = require "dotnet.nuget.picker"
local api_client = require "dotnet.nuget.api_client"

function M.open(proj_file)
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

    local packages

    M.search_bufnr, M.search_win = prompt.create({
        title = "Search",
        win_opts = {
            height = search_h,
            width = search_w,
            row = search_r,
            col = search_c,
            style = config.opts.ui.style,
            border = config.opts.ui.border,
        },
        on_change = function(_)
        end,
    })

    packages = picker.create({
        title = "Packages",
        values = {},
        win_opts = {
            height = pkgs_h,
            width = pkgs_w,
            row = pkgs_r,
            col = pkgs_c,
            style = config.opts.ui.style,
            border = config.opts.ui.border,
        },
        keymaps = {
            {
                key = "u",
                fn = function(pkg)
                    cli.remove_package(proj_file, pkg.id)
                end
            }
        },
        on_selection = function(val)
            if not val or not val.id then
                return
            end

            vim.schedule(function()
                -- Close the view window if it exists
                if M.view_win and vim.api.nvim_win_is_valid(M.view_win) then
                    local versions = api_client.get_versions(val.id) or {}
                    if #versions == 0 then
                        return
                    end

                    local latest_version = versions[#versions]
                    local pkg_info = {
                        id = val.id,
                        version = val.version,
                        latest_version = latest_version,
                        versions = versions,
                    }

                    -- Set the view buffer with package details
                    vim.api.nvim_buf_set_lines(M.view_bufnr, 0, -1, false, {
                        " Package: " .. pkg_info.id,
                        " Current Version: " .. pkg_info.version,
                        " Latest Version: " .. pkg_info.latest_version,
                        " Available Versions:",
                        ""
                    })

                    -- Print the versions in the view buffer in reverse order
                    for i = #pkg_info.versions, 1, -1 do
                        local version = pkg_info.versions[i]
                        vim.api.nvim_buf_set_lines(M.view_bufnr, -1, -1, false, { "   - " .. version })
                    end
                end
            end)
        end,
        display = function(pkg)
            if not pkg or not pkg.id then
                return ""
            end
            return " " .. pkg.id
        end,
    })

    M.pkgs_bufnr, M.pkgs_win = packages.bufnr, packages.win_id
    M.view_bufnr, M.view_win = utils.float_win("View", {
        height = view_h,
        width = view_w,
        row = view_r,
        col = view_c,
        style = config.opts.ui.style,
        border = config.opts.ui.border,
    })

    -- Asynchronously fetch the list of packages with updates
    vim.schedule(function()
        local outdated_pkgs = {}
        for _, pkg in ipairs(manager.get_nuget_pkgs(proj_file) or {}) do
            local versions = api_client.get_versions(pkg.id) or {}
            if #versions > 0 then
                local latest_version = versions[#versions]
                if pkg.version ~= latest_version then
                    table.insert(outdated_pkgs, {
                        id = pkg.id,
                        version = pkg.version,
                        latest_version = latest_version,
                        versions = versions,
                    })
                end
            end
        end
        packages.set_values(outdated_pkgs)
    end)

    -- Set Navigation Keymaps
    local nav_to = function(k, from, to)
        vim.keymap.set("n", k, function() vim.api.nvim_set_current_win(to) end, { buffer = from })
    end

    nav_to("fj", M.search_bufnr, M.pkgs_win)
    nav_to("fl", M.search_bufnr, M.view_win)
    nav_to("fk", M.pkgs_bufnr, M.search_win)
    nav_to("fl", M.pkgs_bufnr, M.view_win)
    nav_to("fh", M.view_bufnr, M.search_win)

    return {
        wins = { M.search_win, M.pkgs_win, M.view_win },
        bufs = { M.search_bufnr, M.pkgs_bufnr, M.view_bufnr },
        close = function()
            if M.search_win and vim.api.nvim_win_is_valid(M.search_win) then
                vim.api.nvim_win_close(M.search_win, true)
            end
            if M.pkgs_win and vim.api.nvim_win_is_valid(M.pkgs_win) then
                vim.api.nvim_win_close(M.pkgs_win, true)
            end
            if M.view_win and vim.api.nvim_win_is_valid(M.view_win) then
                vim.api.nvim_win_close(M.view_win, true)
            end
            if M.search_bufnr and vim.api.nvim_buf_is_valid(M.search_bufnr) then
                vim.api.nvim_buf_delete(M.search_bufnr, { force = true })
            end
            if M.pkgs_bufnr and vim.api.nvim_buf_is_valid(M.pkgs_bufnr) then
                vim.api.nvim_buf_delete(M.pkgs_bufnr, { force = true })
            end
            if M.view_bufnr and vim.api.nvim_buf_is_valid(M.view_bufnr) then
                vim.api.nvim_buf_delete(M.view_bufnr, { force = true })
            end
            M.search_bufnr = nil
            M.search_win = nil
            M.pkgs_bufnr = nil
            M.pkgs_win = nil
            M.view_bufnr = nil
            M.view_win = nil
        end
    }
end

return M
