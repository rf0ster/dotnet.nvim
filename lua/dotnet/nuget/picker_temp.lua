local window = require "dotnet.utils.window"
local buffer = require "dotnet.utils.buffer"
local utils = require "dotnet.utils"

--- @class Picker
--- @field search_bufnr number buffer number for the search input
--- @field search_win number window number for the search input
--- @field results_bufnr number buffer number for the results display
--- @field results_win number window number for the results display
--- @field set_display_values function method to set the display values in the results buffer
--- @field get_selected_value function method to get the currently selected value from the results buffer
--- @field set_search_term function method to set the search term in the search buffer
--- @field attach function method to create and attach the search and results buffers and windows
--- @field refresh_results function|nil method to read from the search buffer and update the display
--- @field close function method to close the picker and clean up buffers and windows

local Picker = {}
Picker.__index = Picker

--- @class Picker.Options
--- @field height number|nil height of the picker window
--- @field width number|nil width of the picker window
--- @field row number|nil row position of the picker window
--- @field col number|nil column position of the picker window
--- @field debounce number|nil debounce time in milliseconds for search input
--- @field results_title string|nil title for the results window
--- @field on_result_selected function|nil callback function when a result is selected
--- @field map_to_results function|nil function to map search term to results synchronously
--- @field map_to_results_async function|nil function to map search term to results asynchronously
--- @field keymaps table|nil custom keymaps for the picker, each entry should be a table with `key` and `callback` fields

--- Creates a new Picker instance.
--- @param opts Picker.Options|nil Options for the picker
--- @return Picker instance of the Picker class
--- @usage
--- local picker = Picker:new({
---     map_to_results = function(search_term)
---         return {
---             { display = "Result 1 for " .. search_term, value = 1 },
---             { display = "Result 2 for " .. search_term, value = 2 },
---             { display = "Result 3 for " .. search_term, value = 3 },
---         }
---     end,
---     map_to_results_async = function(search_term, callback)
---         -- Simulate an async operations
---         vim.defer_fn(function()
---             callback({
---                 { display = "Async Result 1 for " .. search_term, value = 1 },
---                 { display = "Async Result 2 for " .. search_term, value = 2 },
---                 { display = "Async Result 3 for " .. search_term, value = 3 },
---             })
---         end, 1000)
---     end,
---     on_result_selected = function(val)
---         if val then
---             print("Selected value: " .. val)
---         else
---             print("No value selected")
---         end
---     end,
--- })
function Picker:new(opts)
    opts = opts or {}

    local instance = setmetatable({}, self)
    instance.search_bufnr = nil
    instance.search_win = nil
    instance.results_bufnr = nil
    instance.results_win = nil

    local centered = window.centered_dimensions()
    instance.height = opts.height or centered.height
    instance.width = opts.width or centered.width
    instance.row = opts.row or centered.row
    instance.col = opts.col or centered.col

    instance.on_result_selected = opts.on_result_selected or function(_) end
    instance.map_to_results = opts.map_to_results or function(_) return {} end
    instance.map_to_results_async = opts.map_to_results_async

    instance.results_title = opts.results_title
    instance.keymaps = opts.keymaps or {}
    instance.debounce = opts.debounce or 100
    instance.results = {}

    instance:attach()
    return instance
end

--- Creates and attaches the search and results buffers and windows to the Picker instance.
--- This method sets up the UI for the picker, allowing users to input search terms and view results.
function Picker:attach()
    local search_h = 1
    local search_w = self.width
    local search_r = self.row
    local search_c = self.col
    self.search_bufnr, self.search_win = window.create({
        height = search_h,
        width = search_w,
        row = search_r,
        col = search_c,
    })
    vim.api.nvim_buf_set_option(self.search_bufnr, "buftype", "nofile")
    vim.api.nvim_buf_set_option(self.search_bufnr, "modifiable", true)
    vim.api.nvim_buf_set_keymap(self.search_bufnr, 'i', '<CR>', '<NOP>', { noremap = true, silent = true })
    vim.api.nvim_buf_set_keymap(self.search_bufnr, 'n', 'o', '<NOP>', { noremap = true, silent = true })
    vim.api.nvim_buf_set_keymap(self.search_bufnr, 'n', 'O', '<NOP>', { noremap = true, silent = true })
    vim.api.nvim_buf_set_keymap(self.search_bufnr, 'n', 'p', '<NOP>', { noremap = true, silent = true })
    vim.api.nvim_buf_set_keymap(self.search_bufnr, 'n', 'P', '<NOP>', { noremap = true, silent = true })

    local results_h = self.height - search_h - 2
    local results_w = self.width
    local results_r = self.row + search_h + 2
    local results_c = self.col
    self.results_bufnr, self.results_win = window.create({
        title = self.results_title,
        height = results_h,
        width = results_w,
        row = results_r,
        col = results_c,
    })
    vim.api.nvim_buf_set_option(self.results_bufnr, "buftype", "nofile")
    vim.api.nvim_buf_set_option(self.results_bufnr, "modifiable", false)
    vim.api.nvim_win_set_option(self.results_win, "cursorline", true)

    -- Set focus on the search window
    vim.api.nvim_set_current_win(self.search_win)

    local debounce_timer = nil
    vim.api.nvim_create_autocmd("TextChangedI", {
        buffer = self.search_bufnr,
        callback = function()
            if not self.debounce or self.debounce <= 0 then
                self:refresh_results()
                return
            end

            if debounce_timer then
                vim.fn.timer_stop(debounce_timer)
            end
            debounce_timer = vim.fn.timer_start(self.debounce, function()
                self:refresh_results()
                debounce_timer = nil
            end)
        end
    })

    local function move_cursor(direction)
        if #self.results == 0 then
            return
        end

        local row = vim.api.nvim_win_get_cursor(self.results_win)[1] + direction
        if 1 <= row and row <= #self.results then
            vim.api.nvim_win_set_cursor(self.results_win, { row, 0 })
        end

        self.on_result_selected(self:get_selected_value())
    end
    vim.api.nvim_buf_set_keymap(self.search_bufnr, 'n', 'j', '', {
        noremap = true, silent = true, callback = function() move_cursor(1) end
    })
    vim.api.nvim_buf_set_keymap(self.search_bufnr, 'n', 'k', '', {
        noremap = true, silent = true, callback = function() move_cursor(-1) end
    })

    --- Allow users to define custom keymaps while in normal mode in the search buffer.
    for _, keymap in ipairs(self.keymaps or {}) do
        vim.api.nvim_buf_set_keymap(self.search_bufnr, "n", keymap.key, "", {
            noremap = true,
            silent = true,
            callback = function()
                keymap.callback(self:get_selected_value())
            end
        })
    end

    utils.create_knot({ self.search_win, self.results_win })
    vim.schedule(function() self:refresh_results() end)
end

--- Sets the display values in the results buffer.
--- @param values table a list of results to display
--- Each result should be a table with a `display` field for the display name.
--- @usage
--- picker:set_display_values({
---     { display = "Result 1", value = 1 },
---     { display = "Result 2", value = 2 },
---     { display = "Result 3", value = 3 },
---  })
--- If `values` is nil or empty, the results buffer will be cleared.
--- If the results buffer is not valid, this method does nothing.
function Picker:set_display_values(values)
    buffer.clear(self.results_bufnr)
    self.results = values or {}

    buffer.write(self.results_bufnr, vim.tbl_map(function(v)
        return " " .. v.display
    end, values))

    self.on_result_selected(self:get_selected_value())
end

--- Gets the currently selected value from the results buffer.
--- @return table|nil the selected value, or nil if no value is selected
function Picker:get_selected_value()
    if not self.results_win or not vim.api.nvim_win_is_valid(self.results_win) then
        return nil
    end

    local row = vim.api.nvim_win_get_cursor(self.results_win)[1]
    if row < 1 or row > #self.results then
        return nil
    end

    return self.results[row]
end

--- Sets the search term in the search buffer.
--- @param term string the search term to set
function Picker:set_search_term(term)
    if not self.search_bufnr or not vim.api.nvim_buf_is_valid(self.search_bufnr) then
        return
    end
    buffer.clear(self.search_bufnr)
    buffer.write(self.search_bufnr, { term })
end

--- Reads the search term from the search buffer and updates the display values in the results buffer.
function Picker:refresh_results()
    local search_term = buffer.read_lines(self.search_bufnr)[1]
    if self.map_to_results_async then
        self.map_to_results_async(search_term, function(results)
            self:set_display_values(results)
        end)
    else
        local results = self.map_to_results(search_term)
        self:set_display_values(results)
    end
end

--- Closes the Picker instance, cleaning up buffers and windows.
--- @usage
--- picker:close()
function Picker:close()
    window.close(self.search_win)
    window.close(self.results_win)
    buffer.delete(self.search_bufnr)
    buffer.delete(self.results_bufnr)

    self.search_bufnr = nil
    self.search_win = nil
    self.results_bufnr = nil
    self.results_win = nil
end

return Picker
