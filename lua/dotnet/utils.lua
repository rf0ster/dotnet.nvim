
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

-- Splits a string into lines that fit within the specified width.
-- It will first split the string by newlines, and then each line will
-- further be split into smaller lines that fit within the specified width.
-- Additionally, the resulting line will have leading whitespace removed,
-- a padding applied to the left and right, and a specified indentation 
-- for lines that are wrapped. Each resulting line will always be less
-- than or equal to the specified width.
function M.split_smart(str, width, pad_left, pad_right, indent)
    if not str or str == "" then
        return { "" }
    end

    indent = indent or 0
    pad_left = pad_left or 0
    pad_right = pad_right or 0

    local padded_width = width - pad_left - pad_right
    local indented_width = padded_width - indent

    local function pad(s)
        return string.rep(" ", pad_left) .. s .. string.rep(" ", pad_right)
    end

    local function indent_line(line)
        return string.rep(" ", indent) .. line
    end

    local lines = {}
    for line in str:gmatch("[^\r\n]+") do
        -- Remove leading and trailing whitespace from each line
        line = line:gsub("^%s+", ""):gsub("%s+$", "")
        -- If the new line is shorter than the padded width, add it to table
        if #line < padded_width then
            table.insert(lines, pad(line))
            goto continue
        end

        -- The first split will be calculated without indentation.
        -- Add the first line with padding, but no indentation.
        local first_line = line:sub(1, padded_width)
        table.insert(lines, pad(first_line))

        -- Start splitting the rest of the lines with indentation.
        for i = padded_width + 1, #line, indented_width do
            local l = line:sub(i, i + indented_width - 1)
            if l ~= "" then
                table.insert(lines, indent_line(pad(l)))
            end
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
