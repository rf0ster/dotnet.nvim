local M = {}

function M.get_dimensions()
    local dimensions = require "dotnet.nuget.config".opts.ui
    local utils = require "dotnet.utils"

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

    return {
        row = row,
        col = col,
        width = width,
        height = height,
    }
end

return M
