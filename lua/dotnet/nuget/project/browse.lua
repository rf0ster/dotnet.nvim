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

local api_client = require "dotnet.nuget.api_client"
local config = require "dotnet.nuget.config"
local utils = require "dotnet.utils"
local cli = require "dotnet.cli"
local nuget_picker = require "dotnet.nuget.nuget_picker"

function M.open(proj_file)
    local d = utils.get_centered_win_dims(
        config.opts.ui.width,
        config.opts.ui.height
    )
    local header_h = config.defaults.ui.header_h

    local picker_h = d.height - header_h - 4
    local picker_w = math.floor(d.width / 2) - 2
    local picker_r = d.row + header_h + 2
    local picker_c = d.col

    -- Create view window for a single package
    local view_h = d.height - header_h - 4
    local view_w = math.floor(d.width / 2)
    local view_r = d.row + header_h + 2
    local view_c = d.col + picker_w + 2

    local pkgs_picker = nuget_picker.create({
        row = picker_r,
        col = picker_c,
        width = picker_w,
        height = picker_h,
        debounce = 300,
        map_to_results = function(val)
            if not val or val == "" then
                return {}
            end

            local query = string.match(val, "%S+")
            if not query then
                return {}
            end

            -- Fetch packages from the API api_client
            local pkgs = api_client.get_search_query(query, picker_h * 2, true) or {}

            local results = {}
            for _, pkg in ipairs(pkgs) do
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
            if not M.view_bufnr then
                return
            end
            if not val then
                vim.api.nvim_buf_set_option(M.view_bufnr, "modifiable", true)
                vim.api.nvim_buf_set_lines(M.view_bufnr, 0, -1, false, {})
                vim.api.nvim_buf_set_option(M.view_bufnr, "modifiable", false)
                return
            end

            vim.api.nvim_buf_set_option(M.view_bufnr, "modifiable", true)
            vim.api.nvim_buf_set_lines(M.view_bufnr, 0, -1, false, {})
            vim.api.nvim_buf_set_lines(M.view_bufnr, 0, 0, false, {
                " ID: " .. val.value.id,
                " Version: " .. val.value.version,
                " Description: ",
            })

            local w = vim.api.nvim_win_get_width(M.view_win)
            local s = utils.split_smart(val.value.description, w, 3, 1)
            vim.api.nvim_buf_set_lines(M.view_bufnr, 3, -1, false, s)
            vim.api.nvim_buf_set_option(M.view_bufnr, "modifiable", false)
        end,
        keymaps = {
            {
                key = "<CR>",
                callback = function(val)
                    print("Selected package: " .. val.value.id .. "@" .. val.value.version)
                    cli.add_package(proj_file, val.value.id, val.value.version)
                end
            }
        }
    })

    M.search_bufnr = pkgs_picker.search_bufnr
    M.search_win = pkgs_picker.search_win
    M.results_bufnr = pkgs_picker.results_bufnr
    M.results_win = pkgs_picker.results_win

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

    return {
        wins = { M.search_win, M.results_win, M.view_win },
        bufs = { M.search_bufnr, M.results_bufnr, M.view_bufnr },
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
            if M.search_bufnr and vim.api.nvim_buf_is_valid(M.search_bufnr) then
                vim.api.nvim_buf_delete(M.search_bufnr, { force = true })
            end
            if M.results_bufnr and vim.api.nvim_buf_is_valid(M.results_bufnr) then
                vim.api.nvim_buf_delete(M.results_bufnr, { force = true })
            end
            if M.view_bufnr and vim.api.nvim_buf_is_valid(M.view_bufnr) then
                vim.api.nvim_buf_delete(M.view_bufnr, { force = true })
            end
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
