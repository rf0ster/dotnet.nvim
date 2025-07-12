
local M = {}

-- Creates a floating window with the given title and options.
function M.float_win(title, opts)
    local win_opts = {
        relative = "editor",
        style = "minimal",
        border = "double",
        title = title,
    }

    opts = opts or {}
    for k, v in pairs(opts) do
        win_opts[k] = v
    end

    local bufnr = vim.api.nvim_create_buf(false, true)
    local win_id = vim.api.nvim_open_win(bufnr, true, win_opts)

    return bufnr, win_id
end

-- Calculates the dimensions of a centered window based
-- on the given percentages of the screen width and height.
function M.get_centered_win_dims(w_perc, h_perc)
    local h_dims = M.get_centered_win_height_dims(h_perc)
    local w_dims = M.get_centered_win_width_dims(w_perc)

    return {
        height = h_dims.height,
        width = w_dims.width,
        row = h_dims.row,
        col = w_dims.col,
    }
end

-- Calculates the height dimensions of a centered window based
-- on the given percentages of the screen height.
function M.get_centered_win_height_dims(h_perc)
    local h = math.floor(vim.o.lines * h_perc)
    local r = math.floor((vim.o.lines - h) / 2)

    return {
        height = h,
        row = r,
    }
end

-- Calculates the width dimensions of a centered window based
-- on the given percentages of the screen width.
function M.get_centered_win_width_dims(w_perc)
    local w = math.floor(vim.o.columns * w_perc)
    local c = math.floor((vim.o.columns - w) / 2)

    return {
        width = w,
        col = c,
    }
end

-- TODO: Remove these in favor of dimension methods
function M.center_win(w_perc, h_perc, opts)
    opts = opts or {}

    opts.relative = opts.relative or "editor"
    opts.style = opts.style or "minimal"
    opts.border = opts.border or "double"

    M.center_win_width(w_perc, opts)
    M.center_win_height(h_perc, opts)

    return opts
end

-- TODO: Remove these in favor of dimension methods
function M.center_win_width(w_perc, opts)
    local w = math.floor(vim.o.columns * w_perc)
    local c = math.floor((vim.o.columns - w) / 2)

    opts = opts or {}
    opts.width = w
    opts.col = c

    return opts
end

-- TODO: Remove these in favor of dimension methods
function M.center_win_height(h_perc, opts)
    local h = math.floor(vim.o.lines * h_perc)
    local r = math.floor((vim.o.lines - h) / 2)

    opts = opts or {}
    opts.height = h
    opts.row = r

    return opts
end

-- Given a single string, splits it into a table of strings
-- based on the newline character. 
function M.smart_split(str, width, pad_left, pad_right)
    pad_left = pad_left or 0
    pad_right = pad_right or 0
    local padded_width = width - pad_left - pad_right

    local function pad(s)
        return string.rep(" ", pad_left) .. s .. string.rep(" ", pad_right)
    end

    local function indent(s, len)
        return string.rep(" ", len) .. s
    end

    local newline_splits = {}
    for line in str:gmatch("[^\r\n]+") do
        table.insert(newline_splits, line)
    end

    -- Remove leading and trailing whitespace from each line
    for i, line in ipairs(newline_splits) do
        newline_splits[i] = line:gsub("^%s+", ""):gsub("%s+$", "")
    end

    local lines = {}
    for _, line in ipairs(newline_splits) do
        if #line < padded_width then
            table.insert(lines, pad(line))
            goto continue
        end

        for i = 1, #line, padded_width do
            local pw = padded_width
            local indent_w = 0
            if i > 1 then
                pw = padded_width + pad_left
                indent_w = pad_left
            end
            local l = pad(line:sub(i, i + pw - 1))
            l = indent(l, indent_w)

            table.insert(lines, l)
        end

        ::continue::
    end

    return lines
end

-- Sets all the given keymaps for the given buffer numbers.
-- Each keymap is a table with the following keys:
-- - mode: The mode in which the keymap should be set (e.g. "n", "i", "v").
-- - key: The key to be mapped.
-- - fn: The function to be called when the key is pressed.
function M.set_keymaps(bufnrs, keymaps)
    for _, bufnr in ipairs(bufnrs) do
        for _, km in ipairs(keymaps) do
            vim.api.nvim_buf_set_keymap(bufnr, km.mode, km.key, "", {
                noremap = true,
                silent = true,
                callback = km.callback
            })
        end
    end
end

function M.create_knot(win_ids)
    -- Convert window IDs to a lookup set for fast access
    local win_set = {}
    for _, id in ipairs(win_ids) do
      win_set[id] = true
    end

    -- Create a unique augroup so we can clear it later
    local augroup_name = "GroupedWindowAutoClose_" .. tostring(vim.fn.reltime()[2])
    local group_id = vim.api.nvim_create_augroup(augroup_name, { clear = true })

    local function untie()
        -- run command and igore any errors
        pcall(function() vim.api.nvim_del_augroup_by_id(group_id) end)
    end

    -- Function to close all the windows and clear the autocmds
    local function close_all()
      for _, win in ipairs(win_ids) do
        if vim.api.nvim_win_is_valid(win) then
          vim.api.nvim_win_close(win, true)
        end
      end
      untie()
    end

    -- Autocmd: If focus shifts to a non-managed window
    vim.api.nvim_create_autocmd("WinEnter", {
      group = group_id,
      callback = function()
        local current = vim.api.nvim_get_current_win()
        if not win_set[current] then
          close_all()
        end
      end,
    })

    -- Autocmd: If any of the managed windows are closed
    vim.api.nvim_create_autocmd("WinClosed", {
      group = group_id,
      callback = function(args)
        local closed_win = tonumber(args.match)
        if win_set[closed_win] then
          close_all()
        end
      end,
    })

    for _, win in ipairs(win_ids) do
        local bufnr = vim.api.nvim_win_get_buf(win)
        vim.api.nvim_buf_set_keymap(bufnr, "n", "<Esc>", ":q!<CR>", { noremap = true, silent = true, })
    end

    return { win_ids = win_ids, untie = untie }
end

M.clean_line = function(line)
    if line:match("^%s*$") then
        line = ""
    end

    if line ~= "" then
        -- Replace carriage return (^M) with nothing
        -- Is this only on windows??
        line = string.gsub(line, "\r", "")
        -- Trim leading and trailing whitespace
        line = line:gsub("^%s+", ""):gsub("%s+$", "")
        -- Add indentation
        line = " " .. line
    end

    return line
end

return M
