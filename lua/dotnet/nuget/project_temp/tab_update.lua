--- Description: Module for opening a tab to update a package for a .csproj file.
local M = {}

--- Opens the tab for updating a package for a .csproj file.
--- @param csproj_file string File path to the .csproj file to open.
--- @return table The tab object containing windows and buffers.
function M.open(csproj_file)
    local utils = require "dotnet.utils"
    local d = require "dotnet.nuget.windows".get_dimensions()

    local view_bufnr, view_win = utils.float_win("View", d.view)
    local output_bufnr, output_win = utils.float_win("Output", d.output)

    local picker
    picker = require "dotnet.nuget.picker_temp":new({
        results_title = "Packages",
        height = d.picker.height,
        width = d.picker.width,
        row = d.picker.row,
        col = d.picker.col,
    })


    return {
        windows = { view_win, output_win, picker.results_win, picker.search_win },
        buffers = { view_bufnr, output_bufnr, picker.results_bufnr, picker.search_bufnr }
    }
end
return M
