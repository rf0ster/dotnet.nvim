local M = {}

local config = require "dotnet.nuget.config"
local utils = require "dotnet.utils"
local NugetPicker = require "dotnet.nuget.picker_temp"

function M.create(opts)
    opts = opts or {}
    opts.map_to_results  = opts.map_to_results or function(_) end
    opts.map_to_results_async = opts.map_to_results_async or function(_, _) end
    opts.on_result_selected = opts.on_result_selected or function(_, _, _, _, _, _) end

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
    })

    require "dotnet.utils".create_knot({header_win, output_win, view_win, picker.search_win, picker.results_win})

    return {
        output_bufnr,
        output_win,
        view_bufnr,
        view_win,
        header_bufnr,
        header_win,
        picker
    }
end

return M
