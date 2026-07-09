local M = {}

local config = require "dotnet.nuget.config"
local utils = require "dotnet.utils"

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
