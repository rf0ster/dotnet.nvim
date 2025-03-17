local M = {}

local utils = require "dotnet.utils"

local function open_proj(file)
    local mgr_win_opts = utils.center_win_width(.8, {
        height = 3,
        row = 5,
    })
    local mgr_buf, mgr_win = utils.float_win("NuGet Manager", mgr_win_opts)
    vim.api.nvim_buf_set_lines(mgr_buf, 0, -1, false, {
        " Project: " .. file,
        "",
        " Search  --  Installed  --  Update"
    })

    -- get x, y, width, height of window
    local mgr_win_config = vim.api.nvim_win_get_config(mgr_win)
    local r, c = mgr_win_config.row, mgr_win_config.col
    local w, h = mgr_win_config.width, mgr_win_config.height

    local half_w = math.floor(w / 2)
    local sub_r = r + h + 2
    local search_bufnr, search_win = utils.float_win("Search", {
        width = half_w - 2,
        height = 3,
        row = sub_r,
        col = c
    })

    local results_bufnr, results_win = utils.float_win("Results", {
        width = half_w,
        height = 3,
        row = sub_r,
        col = c + half_w
    })

    local win_enter_cmd
    local win_close_cmd
    local function close_all()
        -- close all windows if they exist
        if vim.api.nvim_win_is_valid(search_win) then
            vim.api.nvim_win_close(search_win, true)
        end
        if vim.api.nvim_win_is_valid(results_win) then
            vim.api.nvim_win_close(results_win, true)
        end
        if vim.api.nvim_win_is_valid(mgr_win) then
            vim.api.nvim_win_close(mgr_win, true)
        end

        -- remove cmds from nvim_create_autocmd
        if win_enter_cmd then
            vim.api.nvim_del_autocmd(win_enter_cmd)
        end
        if win_close_cmd then
            vim.api.nvim_del_autocmd(win_close_cmd)
        end
    end

    win_enter_cmd = vim.api.nvim_create_autocmd("WinEnter", {
        callback = function()
            -- get focused window and bufnr
            local win_id = vim.api.nvim_get_current_win()
           if win_id ~= search_win and win_id ~= results_win and win_id ~= mgr_win then
                close_all()
            end

        end,
    })
    win_close_cmd = vim.api.nvim_create_autocmd("WinClosed", {
        pattern = mgr_win .. "," .. search_win .. "," .. results_win,
        callback = function()
            close_all()
        end,
    })
    -- set keymap to close each window on <esc>
    vim.api.nvim_buf_set_keymap(search_bufnr, "n", "<esc>", ":q!<cr>", { noremap = true, silent = true })
    vim.api.nvim_buf_set_keymap(results_bufnr, "n", "<esc>", ":q!<cr>", { noremap = true, silent = true })
    vim.api.nvim_buf_set_keymap(mgr_buf, "n", "<esc>", ":q!<cr>", { noremap = true, silent = true })

    local function set_focus_to_mgr()
        vim.api.nvim_set_current_win(mgr_win)
    end
    local function set_focus_to_search()
        vim.api.nvim_set_current_win(search_win)
    end
    local function set_focus_to_results()
        vim.api.nvim_set_current_win(results_win)
    end
    vim.keymap.set("n", "gk", set_focus_to_mgr, { noremap = true, silent = true, buffer = search_bufnr })
    vim.keymap.set("n", "gk", set_focus_to_mgr, { noremap = true, silent = true, buffer = results_bufnr })
    vim.keymap.set("n", "gj", set_focus_to_search, { noremap = true, silent = true, buffer = mgr_buf })
    vim.keymap.set("n", "gh", set_focus_to_search, { noremap = true, silent = true, buffer = results_bufnr })
    vim.keymap.set("n", "gl", set_focus_to_results, { noremap = true, silent = true, buffer = search_bufnr })
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
