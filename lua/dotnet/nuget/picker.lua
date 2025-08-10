local M = {}

function M.create(opts)
    local w = opts.width
    local h = opts.height
    local r = opts.row
    local c = opts.col

    local on_selected = opts.on_selected or function(_) end
    local map_to_results = opts.map_to_results or function(_) return {} end
    local map_to_results_async = opts.map_to_results_async

    local debounce = opts.debounce or 100
    local default_search_term = opts.default_search_term or ""

    --- Create the search prompt. This buffer is used
    --- as the input for the search term in the picker.
    local search_bufnr = vim.api.nvim_create_buf(false, true)
    local search_win = vim.api.nvim_open_win(search_bufnr, true, {
        relative = 'editor',
        width = w,
        height = 1,
        row = r,
        col = c,
        style = 'minimal',
        border = 'rounded',
    })
    vim.api.nvim_buf_set_option(search_bufnr, "buftype", "nofile")
    vim.api.nvim_buf_set_option(search_bufnr, "modifiable", true)
    vim.api.nvim_buf_set_keymap(search_bufnr, 'i', '<CR>', '<NOP>', { noremap = true, silent = true })
    vim.api.nvim_buf_set_keymap(search_bufnr, 'n', 'o', '<NOP>', { noremap = true, silent = true })
    vim.api.nvim_buf_set_keymap(search_bufnr, 'n', 'O', '<NOP>', { noremap = true, silent = true })
    vim.api.nvim_buf_set_keymap(search_bufnr, 'n', 'p', '<NOP>', { noremap = true, silent = true })
    vim.api.nvim_buf_set_keymap(search_bufnr, 'n', 'P', '<NOP>', { noremap = true, silent = true })

    --- Create the results buffer. This buffer is used to display
    --- the results of the search term entered in the search prompt.
    local results_bufnr = vim.api.nvim_create_buf(false, true)
    local results_win = vim.api.nvim_open_win(results_bufnr, true, {
        relative = 'editor',
        width = w,
        height = h - 3,
        row = r + 3,
        col = c,
        style = 'minimal',
        border = 'rounded',
    })
    vim.api.nvim_buf_set_option(results_bufnr, "buftype", "nofile")
    vim.api.nvim_buf_set_option(results_bufnr, "modifiable", false)
    vim.api.nvim_win_set_option(results_win, "cursorline", true)

    --- Stores the results of the search.
    --- Display name and the actual value.
    local stored_values = {}

    --- Gets the currently selected value in the results window.
    --- Assumes that the row the item is on corresponds to the 
    --- index in `stored_values`.
    local get_selected_value = function()
        local cur = vim.api.nvim_win_get_cursor(results_win)
        if cur[1] < 1 or cur[1] > #stored_values then
            return nil
        end
        return stored_values[cur[1]]
    end

    --- Called every time the user presses j|k in the search windows.
    --- Calculates the new cursor position in the results window and
    --- moves the cursor there accordingly.
    local move_results_cursor = function(direction)
        if not results_win or not vim.api.nvim_win_is_valid(results_win) then
            return
        end

        local cur = vim.api.nvim_win_get_cursor(results_win)
        local max = vim.api.nvim_buf_line_count(results_bufnr)

        cur[1] = cur[1] + direction
        if cur[1] < 1 then
            cur[1] = 1
        elseif cur[1] > vim.api.nvim_buf_line_count(results_bufnr) then
            cur[1] = max
        end
        vim.api.nvim_win_set_cursor(results_win, cur)

        local selected_value = get_selected_value()
        on_selected(selected_value)
    end

    vim.api.nvim_buf_set_keymap(search_bufnr, "n", "j", '', {
        noremap = true,
        silent = true,
        callback = function() move_results_cursor(1) end
    })

    vim.api.nvim_buf_set_keymap(search_bufnr, "n", "k", '', {
        noremap = true,
        silent = true,
        callback = function() move_results_cursor(-1) end
    })

    for _, keymap in ipairs(opts.keymaps or {}) do
        vim.api.nvim_buf_set_keymap(search_bufnr, "n", keymap.key, "", {
            noremap = true,
            silent = true,
            callback = function() keymap.callback(get_selected_value()) end
        })
    end


    local wrapped_on_change = function()
        local search_term = vim.api.nvim_buf_get_lines(search_bufnr, 0, -1, false)[1] or ""

        local display_results = {}
        stored_values = {}

        for _, result in ipairs(map_to_results(search_term)) do
            table.insert(stored_values, result)
            table.insert(display_results, " " .. result.display)
        end

        vim.api.nvim_buf_set_option(results_bufnr, "modifiable", true)
        vim.api.nvim_buf_set_lines(results_bufnr, 0, -1, false, {})
        vim.api.nvim_buf_set_lines(results_bufnr, 0, 0, false, display_results)
        vim.api.nvim_buf_set_option(results_bufnr, "modifiable", false)
        vim.api.nvim_win_set_cursor(results_win, { 1, 0 })

        move_results_cursor(0) -- Trick to make the first result selected
    end

    local wrapped_on_change_async = function()
        local search_term = vim.api.nvim_buf_get_lines(search_bufnr, 0, -1, false)[1] or ""

        map_to_results_async(search_term, function(results)
            local display_results = {}
            stored_values = {}

            for _, result in ipairs(results) do
                table.insert(stored_values, result)
                table.insert(display_results, " " .. result.display)
            end

            vim.api.nvim_buf_set_option(results_bufnr, "modifiable", true)
            vim.api.nvim_buf_set_lines(results_bufnr, 0, -1, false, {})
            vim.api.nvim_buf_set_lines(results_bufnr, 0, 0, false, display_results)
            vim.api.nvim_buf_set_option(results_bufnr, "modifiable", false)
            vim.api.nvim_win_set_cursor(results_win, { 1, 0 })

            move_results_cursor(0) -- Trick to make the first result selected
        end)
    end

    -- Setup an optional debounce timer for the search input
    -- box to prevent the picker from updating too frequently 
    -- while typing and possibly making too many network requests. 
    local debounce_timer = nil
    if debounce > 0 then
        vim.api.nvim_create_autocmd("TextChangedI", {
            buffer = search_bufnr,
            callback = function()
                if debounce_timer then
                    vim.fn.timer_stop(debounce_timer)
                end

                debounce_timer = vim.fn.timer_start(debounce, function()
                    if map_to_results_async then
                        wrapped_on_change_async()
                    else
                        wrapped_on_change()
                    end
                    debounce_timer = nil
                end)
            end
        })
    else
        vim.api.nvim_create_autocmd("TextChangedI", {
            buffer = search_bufnr,
            callback = function()
                if map_to_results_async then
                    wrapped_on_change_async()
                else
                    wrapped_on_change()
                end
            end
        })
    end

    -- Set focus on the search window
    vim.api.nvim_set_current_win(search_win)

    M.search_bufnr = search_bufnr
    M.search_win = search_win
    M.results_bufnr = results_bufnr
    M.results_win = results_win

    -- Set the initial search term if provided
    if default_search_term and default_search_term ~= "" then
        vim.api.nvim_buf_set_lines(search_bufnr, 0, -1, false, { default_search_term })
    end

    -- Schedule a task to ensure the results window is updated
    vim.schedule(function()
        if map_to_results_async then
            wrapped_on_change_async()
        else
            wrapped_on_change()
        end
    end)

    return M.get_state()
end


function M.get_state()
    return {
        search_bufnr = M.search_bufnr,
        search_win = M.search_win,
        results_bufnr = M.results_bufnr,
        results_win = M.results_win,
        override_dispaly_values = M.override_dispaly_values,
    }
end

return M
