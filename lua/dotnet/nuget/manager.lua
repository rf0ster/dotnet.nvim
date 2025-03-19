local M = {}

local utils = require "dotnet.utils"
local api = require "dotnet.nuget.api"
local cli = require "dotnet.cli"

local function open_proj(file)
    -- NugetManager window dimensions
    -- ***************************
    -- * header                  *
    -- ***************************
    -- * search     * view       *
    -- **************            *
    -- * results    *            *
    -- *            *            *
    -- *            *            *
    -- ***************************

    -- Calculate window dimensions
    local win_dim = utils.center_win(0.8, 0.8)
    local w_half = math.floor(win_dim.width / 2)

    local header_h = 1
    local header_w = win_dim.width
    local header_r = win_dim.row
    local header_c = win_dim.col

    local search_h = 1
    local search_w = w_half - 2
    local search_r = header_r + header_h + 2
    local search_c = win_dim.col

    local results_h = win_dim.height - header_h - search_h - 4
    local results_w = w_half - 2
    local results_r = search_r + search_h + 2
    local results_c = win_dim.col

    local view_h = win_dim.height - header_h - 2
    local view_w = w_half
    local view_r = header_r + header_h + 2
    local view_c = win_dim.col + w_half

    local header_bufnr, header_win = utils.float_win("NuGet Manager  " .. file, {
        width = header_w,
        height = header_h,
        row = header_r,
        col = header_c,
    })

    local search_bufnr, search_win = utils.float_win("Search", {
        width = search_w,
        height = search_h,
        row = search_r,
        col = search_c,
    })

    local results_bufnr, results_win = utils.float_win("Results", {
        width = results_w,
        height = results_h,
        row = results_r,
        col = results_c,
    })

    local view_bufnr, view_win = utils.float_win("View", {
        width = view_w,
        height = view_h,
        row = view_r,
        col = view_c,
    })

    -- setup header buffer
    vim.api.nvim_buf_set_option(header_bufnr, "buftype", "nofile")
    vim.api.nvim_buf_set_lines(header_bufnr, 0, -1, false, {
        "  (S)earch  |  (I)nstalled  |  (U)pdate"
    })

    -- setup search buffer
    vim.api.nvim_buf_set_option(search_bufnr, "buftype", "nofile")
    vim.api.nvim_buf_set_option(search_bufnr, "modifiable", true)
    vim.api.nvim_buf_set_keymap(search_bufnr, 'i', '<CR>', '<NOP>', { noremap = true, silent = true })
    vim.api.nvim_buf_set_keymap(search_bufnr, 'n', 'o', '<NOP>', { noremap = true, silent = true })
    vim.api.nvim_buf_set_keymap(search_bufnr, 'n', 'O', '<NOP>', { noremap = true, silent = true })
    vim.api.nvim_buf_set_keymap(search_bufnr, 'n', 'p', '<NOP>', { noremap = true, silent = true })
    vim.api.nvim_buf_set_keymap(search_bufnr, 'n', 'P', '<NOP>', { noremap = true, silent = true })

    -- setup results buffer
    vim.api.nvim_buf_set_option(results_bufnr, "buftype", "nofile")
    vim.api.nvim_buf_set_option(results_bufnr, "modifiable", false)
    vim.api.nvim_buf_set_option(results_bufnr, "cursorline", true)

    local autocmds = {}
    local function close_all()
        -- close all windows if they exist
        if vim.api.nvim_win_is_valid(header_win) then
            vim.api.nvim_win_close(header_win, true)
        end
        if vim.api.nvim_win_is_valid(search_win) then
            vim.api.nvim_win_close(search_win, true)
        end
        if vim.api.nvim_win_is_valid(results_win) then
            vim.api.nvim_win_close(results_win, true)
        end
        if vim.api.nvim_win_is_valid(view_win) then
            vim.api.nvim_win_close(view_win, true)
        end

        for _, id in ipairs(autocmds) do
            vim.api.nvim_del_autocmd(id)
        end
    end

    local apply_win_leave = function(bufnr)
        local id = vim.api.nvim_create_autocmd("WinLeave", {
            buffer = bufnr,
            callback = function()
                local win_id = vim.api.nvim_get_current_win()
                if win_id ~= search_win and win_id ~= view_win and win_id ~= header_win and win_id ~= results_win then
                    close_all()
                end
            end,
        })
        table.insert(autocmds, id)
    end
    apply_win_leave(header_bufnr)
    apply_win_leave(search_bufnr)
    apply_win_leave(results_bufnr)
    apply_win_leave(view_bufnr)

    table.insert(autocmds, vim.api.nvim_create_autocmd("WinClosed", {
        pattern = header_win .. "," .. search_win .. "," .. results_win .. "," .. view_win,
        callback = close_all,
    }))

    local packages = {}
    local debounce_timer = nil
    table.insert(autocmds, vim.api.nvim_create_autocmd("TextChangedI", {
        buffer = search_bufnr,
        callback = function()
            if debounce_timer then
                vim.fn.timer_stop(debounce_timer)
            end

            debounce_timer = vim.fn.timer_start(500, function()
                local function clear()
                    vim.api.nvim_buf_set_option(results_bufnr, "modifiable", true)
                    vim.api.nvim_buf_set_lines(results_bufnr, 0, -1, false, {})
                    vim.api.nvim_buf_set_option(results_bufnr, "modifiable", false)
                end

                local search_val = vim.api.nvim_buf_get_lines(search_bufnr, 0, -1, false)
                if not search_val or #search_val == 0 then
                    clear()
                    return
                end

                local query = string.match(search_val[1], "%S+") or ""
                if not query or query == "" then
                    clear()
                    return
                end

                packages = api.query(query, results_h)
                local pkg_list = {}
                if package and #packages > 0 then
                    for _, result in ipairs(packages) do
                        table.insert(pkg_list, " " .. result.id)
                    end
                end

                vim.api.nvim_buf_set_option(results_bufnr, "modifiable", true)
                vim.api.nvim_buf_set_lines(results_bufnr, 0, -1, false, {})
                vim.api.nvim_buf_set_lines(results_bufnr, 0, 0, false, pkg_list)
                vim.api.nvim_buf_set_option(results_bufnr, "modifiable", false)
                vim.api.nvim_win_set_cursor(results_win, { 1, 0 })
                debounce_timer = nil
            end)
        end,
    }))

    table.insert(autocmds, vim.api.nvim_create_autocmd("CursorMoved", {
        buffer = results_bufnr,
        callback = function()
            local line = vim.api.nvim_get_current_line()
            if not line or line == "" then
                return
            end

            local id = string.match(line, "%S+")
            if not id or id == "" then
                return
            end

            local package = nil
            for _, result in ipairs(packages) do
                if result.id == id then
                    package = result
                    break
                end
            end

            vim.api.nvim_buf_set_option(view_bufnr, "modifiable", true)
            if not package then
                vim.api.nvim_buf_set_lines(view_bufnr, 0, -1, false, {})
            else
                local desc_lines = {}
                for l in package.description:gmatch("[^\r\n]+") do
                    table.insert(desc_lines, "  " .. l)
                end

                vim.api.nvim_buf_set_lines(view_bufnr, 0, -1, false, {
                    "ID: " .. package.id,
                    "Version: " .. package.version,
                    "Description: "
                })
                vim.api.nvim_buf_set_lines(view_bufnr, -1, -1, false, desc_lines)
            end

            vim.api.nvim_buf_set_option(view_bufnr, "modifiable", false)
        end
    }))

    -- set keymap to close each window on <esc>
    vim.api.nvim_buf_set_keymap(search_bufnr, "n", "<esc>", ":q!<cr>", { noremap = true, silent = true })
    vim.api.nvim_buf_set_keymap(view_bufnr, "n", "<esc>", ":q!<cr>", { noremap = true, silent = true })
    vim.api.nvim_buf_set_keymap(header_bufnr, "n", "<esc>", ":q!<cr>", { noremap = true, silent = true })
    vim.api.nvim_buf_set_keymap(results_bufnr, "n", "<esc>", ":q!<cr>", { noremap = true, silent = true })

    local function set_focus_header()
        vim.api.nvim_set_current_win(header_win)
    end
    local function set_focus_search()
        vim.api.nvim_set_current_win(search_win)
    end
    local function set_focus_results()
        vim.api.nvim_set_current_win(results_win)
    end
    local function set_focus_view()
        vim.api.nvim_set_current_win(view_win)
    end

    -- keymaps for header
    vim.keymap.set("n", "gj", set_focus_search, { noremap = true, silent = true, buffer = header_bufnr })

    -- keymaps for search
    vim.keymap.set("n", "gk", set_focus_header, { noremap = true, silent = true, buffer = search_bufnr })
    vim.keymap.set("n", "gj", set_focus_results, { noremap = true, silent = true, buffer = search_bufnr })
    vim.keymap.set("n", "gl", set_focus_view, { noremap = true, silent = true, buffer = search_bufnr })

    -- keymaps for results
    vim.keymap.set("n", "gk", set_focus_search, { noremap = true, silent = true, buffer = results_bufnr })
    vim.keymap.set("n", "gl", set_focus_view, { noremap = true, silent = true, buffer = results_bufnr })
    vim.keymap.set("n", "i", function()
        local line = vim.api.nvim_get_current_line()
        if not line or line == "" then
            return
        end

        local id = string.match(line, "%S+")
        if not id or id == "" then
            return
        end

        local package = nil
        for _, result in ipairs(packages) do
            if result.id == id then
                package = result
                break
            end
        end

        if not package then
            return
        end

        cli.add_package(file, package.id, package.version)
    end, { noremap = true, silent = true, buffer = results_bufnr })

    -- keymaps for view
    vim.keymap.set("n", "gk", set_focus_header, { noremap = true, silent = true, buffer = view_bufnr })
    vim.keymap.set("n", "gh", set_focus_search, { noremap = true, silent = true, buffer = view_bufnr })

    vim.api.nvim_set_current_win(search_win)
end

local function open_sln(file)
    print("Opening solution: " .. file)
end

-- Function to open nuget manager window.
-- @param file string: The full path to the solution or project file.
function M.open(file)
    -- TOOD: Remove this
    if not file then
        file = "HelloWorld/HelloWorld.csproj"
    end
    if file:match("%.sln$") then
        open_sln(file)
    elseif file:match("%.csproj$") then
        open_proj(file)
    end
end

return M
