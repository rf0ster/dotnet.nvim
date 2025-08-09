-- Creates the compponents for installed tab of the nuget manager.
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

local manager = require "dotnet.manager"
local config = require "dotnet.nuget.config"
local utils = require "dotnet.utils"
local nuget_picker = require "dotnet.nuget.nuget_picker"
local fuzzy = require "dotnet.nuget.fuzzy"
local window = require "dotnet.nuget.window"
local nuget_api = require "dotnet.nuget.api"

function M.open(proj_file)
    local d = window.get_dimensions()
    local pkgs = manager.get_nuget_pkgs(proj_file)

    local header_h = config.defaults.ui.header_h

    -- Define output window height before creating the picke
    -- so that it can be used in the picker and view dimensions.
    local output_h = 6
    local output_w = d.width

    -- Create the package picker dimensions
    local picker_h = d.height - header_h - output_h - 4
    local picker_w = math.floor(d.width / 2) - 2
    local picker_r = d.row + header_h + 2
    local picker_c = d.col

    -- Create view window for a single package
    local view_h = d.height - header_h - output_h - 4
    local view_w = math.floor(d.width / 2)
    local view_r = d.row + header_h + 2
    local view_c = d.col + picker_w + 2

    -- Define the rest of the output window dimensions
    -- based on the picker and view dimensions.
    local output_r = picker_r + picker_h + 2
    local output_c = d.col

    local output_bufnr, output_win = utils.float_win("Output", {
        height = output_h,
        width = output_w,
        row = output_r,
        col = output_c,
        style = config.opts.ui.style,
        border = config.opts.ui.border,
    })

    local pkgs_picker = nuget_picker.create({
        row = picker_r,
        col = picker_c,
        width = picker_w,
        height = picker_h,
        values = { nil },
        map_to_results = function(val)
            local filtered_pkgs = fuzzy.filter(pkgs or {}, val, function(pkg) return pkg.id end)

            local results = {}
            for _, pkg in ipairs(filtered_pkgs or {}) do
                if pkg and pkg.id and pkg.version then
                    table.insert(results, {
                        display = pkg.id .. "@" .. pkg.version,
                        value = pkg,
                    })
                end
            end
            return results
        end,
        on_selected = function(val)
            if not M.view_bufnr or not vim.api.nvim_buf_is_valid(M.view_bufnr) then
                return
            end

            vim.api.nvim_buf_set_option(M.view_bufnr, "modifiable", true)
            vim.api.nvim_buf_set_lines(M.view_bufnr, 0, -1, false, {})
            vim.api.nvim_buf_set_option(M.view_bufnr, "modifiable", false)

            if not val then
                return
            end

            nuget_api.get_pkg_registration_async(val.value.id, val.value.version, function(pkg)
                if not vim.api.nvim_buf_is_valid(M.view_bufnr) then
                    return
                end

                vim.api.nvim_buf_set_option(M.view_bufnr, "modifiable", true)
                vim.api.nvim_buf_set_lines(M.view_bufnr, 0, -1, false, {})

                if not pkg or not pkg.id or not pkg.version then
                    vim.api.nvim_buf_set_lines(M.view_bufnr, 0, -1, false, {
                        "No package information available."
                    })
                else
                    vim.api.nvim_buf_set_lines(M.view_bufnr, 0, 0, false, {
                        " ID: " .. pkg.id,
                        " Version: " .. pkg.version,
                        " Authors: " .. (pkg.authors or "Unknown"),
                        " Description: ",
                    })
                    local w = vim.api.nvim_win_get_width(M.view_win)
                    local s = utils.split_smart(pkg.description, w, 3, 1)

                    local last_line = vim.api.nvim_buf_line_count(M.view_bufnr)
                    vim.api.nvim_buf_set_lines(M.view_bufnr, last_line - 1, -1, false, s)
                end

                vim.api.nvim_buf_set_option(M.view_bufnr, "modifiable", false)
            end)
        end,
        keymaps = {
            {
                key = "u",
                callback = function(val)
                    local DotnetCli = require "dotnet.cli.cli"
                    local options = require "dotnet.cli.cli_opts"

                    local opts = options.smart_output_opts(output_bufnr, output_win)
                    local cli = DotnetCli:new(opts)

                    cli:remove_package(proj_file, val.value.id)
                end
            }
        }
    })

    M.search_bufnr = pkgs_picker.search_bufnr
    M.search_win = pkgs_picker.search_win
    M.results_bufnr = pkgs_picker.results_bufnr
    M.results_win = pkgs_picker.results_win
    M.output_bufnr = output_bufnr
    M.output_win = output_win

    M.view_bufnr, M.view_win = utils.float_win("View", {
        height = view_h,
        width = view_w,
        row = view_r,
        col = view_c,
        style = config.opts.ui.style,
        border = config.opts.ui.border,
    })

    -- Set Navigation Keymaps
    vim.keymap.set("n", "fl", function() vim.api.nvim_set_current_win(M.view_win) end, { buffer = M.search_bufnr })
    vim.keymap.set("n", "fh", function() vim.api.nvim_set_current_win(M.search_win) end, { buffer = M.view_bufnr })
    vim.keymap.set("n", "fj", function() vim.api.nvim_set_current_win(M.output_win) end, { buffer = M.search_bufnr })
    vim.keymap.set("n", "fj", function() vim.api.nvim_set_current_win(M.output_win) end, { buffer = M.view_bufnr })
    vim.keymap.set("n", "fk", function() vim.api.nvim_set_current_win(M.search_win) end, { buffer = M.output_bufnr })


    return {
        wins = { M.search_win, M.results_win, M.view_win, M.output_win },
        bufs = { M.search_bufnr, M.results_bufnr, M.view_bufnr, M.output_bufnr },
        close = function()
            if M.search_win and vim.api.nvim_win_is_valid(M.search_win) then
                vim.api.nvim_win_close(M.search_win, true)
            end
            if M.results_win and vim.api.nvim_win_is_valid(M.results_win) then
                vim.api.nvim_win_close(M.results_win, true)
            end
            if M.view_win and vim.api.nvim_win_is_valid(M.view_win) then
                vim.api.nvim_win_close(M.view_win, true)
            end
            if M.output_win and vim.api.nvim_win_is_valid(M.output_win) then
                vim.api.nvim_win_close(M.output_win, true)
            end
            if M.search_bufnr and vim.api.nvim_buf_is_valid(M.search_bufnr) then
                vim.api.nvim_buf_delete(M.search_bufnr, { force = true })
            end
            if M.results_bufnr and vim.api.nvim_buf_is_valid(M.results_bufnr) then
                vim.api.nvim_buf_delete(M.results_bufnr, { force = true })
            end
            if M.view_bufnr and vim.api.nvim_buf_is_valid(M.view_bufnr) then
                vim.api.nvim_buf_delete(M.view_bufnr, { force = true })
            end
            if M.output_bufnr and vim.api.nvim_buf_is_valid(M.output_bufnr) then
                vim.api.nvim_buf_delete(M.output_bufnr, { force = true })
            end
            M.output_bufnr = nil
            M.output_win = nil
            M.search_bufnr = nil
            M.search_win = nil
            M.results_bufnr = nil
            M.results_win = nil
            M.view_bufnr = nil
            M.view_win = nil
        end
    }
end

return M
