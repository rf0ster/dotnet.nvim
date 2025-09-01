local M = {}

local config = require "dotnet.nuget.config"
local utils = require "dotnet.utils"
local NugetPicker = require "dotnet.nuget.picker_temp"

--- Creates and configures the main UI windows for the NuGet package manager.
-- @param opts A table of options to customize the behavior of the windows.
--        - map_to_results: A function to map search input to results (synchronous).
--        - map_to_results_async: A function to map search input to results (asynchronous).
--        - on_result_selected: A function to handle when a result is selected.
--  @return A table containing the buffer and window IDs for output, view, header, and the picker instance.
--       - output_bufnr, output_win
--       - view_bufnr, view_win
--       - header_bufnr, header_win
--       - picker
function M.create(opts)
    opts = opts or {}
    opts.map_to_results  = opts.map_to_results or function(_) end
    opts.map_to_results_async = opts.map_to_results_async or function(_, _) end
    opts.on_result_selected = opts.on_result_selected or function(_, _, _, _, _, _) end
    opts.keymaps = opts.keymaps or {}

    local dimensions = config.opts.ui

    local row = dimensions.row
    local col = dimensions.col

    local width = dimensions.width or 0.8
    local height = dimensions.height or 0.8

    if width <= 1 then
        local d = utils.get_centered_win_width_dims(width)
        width = d.width
        col = col or d.col
    end

    if height <= 1 then
        local d = utils.get_centered_win_height_dims(height)
        height = d.height
        row = row or d.row
    end

    local output_h = 6

    local header_h = 1
    local header_w = width
    local header_r = row
    local header_c = col

    local picker_h = height - header_h - output_h - 4
    local picker_w = math.floor(width / 2) - 2
    local picker_r = row + header_h + 2
    local picker_c = col

    local view_h = height - header_h - output_h - 4
    local view_w = math.floor(width / 2)
    local view_r = row + header_h + 2
    local view_c = col + picker_w + 2

    local output_w = width
    local output_r = picker_r + picker_h + 2
    local output_c = col

    local header_bufnr, header_win = utils.float_win("Header", {
        height = header_h,
        width = header_w,
        row = header_r,
        col = header_c,
        style = config.opts.ui.style,
        border = config.opts.ui.border,
    })

    local output_bufnr, output_win = utils.float_win("Output", {
        height = output_h,
        width = output_w,
        row = output_r,
        col = output_c,
        style = config.opts.ui.style,
        border = config.opts.ui.border,
    })

    local view_bufnr, view_win = utils.float_win("View", {
        height = view_h,
        width = view_w,
        row = view_r,
        col = view_c,
        style = config.opts.ui.style,
        border = config.opts.ui.border,
    })

    local picker
    picker = NugetPicker:new({
        height = picker_h,
        width = picker_w,
        row = picker_r,
        col = picker_c,
        results_title = "NuGet Packages",
        on_result_selected = function(selection)
            opts.on_result_selected(selection, view_bufnr, view_win, output_bufnr, output_win, picker)
        end,
        map_to_results = opts.map_to_results,
        map_to_results_async = opts.map_to_results_async,
        keymaps = opts.keymaps
    })

    require "dotnet.utils".create_knot({header_win, output_win, view_win, picker.search_win, picker.results_win})

    return {
        output_bufnr = output_bufnr,
        output_win = output_win,
        view_bufnr = view_bufnr,
        view_win = view_win,
        header_bufnr = header_bufnr,
        header_win = header_win,
        picker = picker
    }
end

--- Calculates and returns the dimensions for the various UI components.
--- @return table: A table containing the dimensions for header, picker, output, and view windows.
---   Each component has its own table with the following keys:
---   - row (number): Row position of the window.
---   - col (number): Column position of the window.
---   - width (number): Width of the window.
---   - height (number): Height of the window.
---   - border (string): Border style of the window.
---   - style (string): Style of the window.
function M.get_dimensions()
    local dimensions = config.opts.ui

    local row = dimensions.row
    local col = dimensions.col

    local width = dimensions.width or 0.8
    local height = dimensions.height or 0.8

    if width <= 1 then
        local d = utils.get_centered_win_width_dims(width)
        width = d.width
        col = col or d.col
    end

    if height <= 1 then
        local d = utils.get_centered_win_height_dims(height)
        height = d.height
        row = row or d.row
    end

    local output_h = 6

    local header_h = 1
    local header_w = width
    local header_r = row
    local header_c = col

    local picker_h = height - header_h - output_h - 4
    local picker_w = math.floor(width / 2) - 2
    local picker_r = row + header_h + 2
    local picker_c = col

    local view_h = height - header_h - output_h - 4
    local view_w = math.floor(width / 2)
    local view_r = row + header_h + 2
    local view_c = col + picker_w + 2

    local output_w = width
    local output_r = picker_r + picker_h + 2
    local output_c = col

    return {
        header = {
            row = header_r,
            col = header_c,
            width = header_w,
            height = header_h,
            border = config.opts.ui.border,
            style = config.opts.ui.style,
        },
        picker = {
            row = picker_r,
            col = picker_c,
            width = picker_w,
            height = picker_h,
            border = config.opts.ui.border,
            style = config.opts.ui.style,
        },
        output = {
            row = output_r,
            col = output_c,
            width = output_w,
            height = output_h,
            border = config.opts.ui.border,
            style = config.opts.ui.style,
        },
        view = {
            row = view_r,
            col = view_c,
            width = view_w,
            height = view_h,
            border = config.opts.ui.border,
            style = config.opts.ui.style,
        }
    }
end

return M
