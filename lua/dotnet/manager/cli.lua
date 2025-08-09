local M = {}

local utils = require "dotnet.utils"
local window = require "dotnet.utils.window"
local buffer = require "dotnet.utils.buffer"

local cli
local win
local bufnr

local function on_cmd_start()
    window.close(win)
    buffer.delete(bufnr)

    bufnr, win = window.create()
    buffer.set_modifiable(bufnr, false)
    utils.create_knot({ win })
end

local function on_cmd_out(_, data, _)
    buffer.append_lines(bufnr, data)
    buffer.set_modifiable(bufnr, false)
end

function M.get_cli()
    if cli then
        return cli
    end

    cli = require "dotnet.cli.cli":new({
        on_cmd_start = on_cmd_start,
        on_cmd_stdout = on_cmd_out,
        on_cmd_stderr = on_cmd_out
    })

    return cli
end

return M
