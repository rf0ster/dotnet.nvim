local M = {}

local utils = require "dotnet.utils"
local window = require "dotnet.utils.window"
local buffer = require "dotnet.utils.buffer"
local stream = require "dotnet.cli.stream"

local cli
local win
local bufnr
local out -- stream processor for the currently running command

local function on_cmd_start(cmd)
    window.close(win)
    buffer.delete(bufnr)

    bufnr, win = window.create({ title = cmd or "dotnet" })
    buffer.set_modifiable(bufnr, false)
    utils.create_knot({ win })

    -- Fresh processor per run so partial-line/blank state does not leak
    -- between commands. The gutter pads output away from the border.
    out = stream.new({ gutter = " " })
end

local function on_cmd_out(_, data, _)
    buffer.append_lines(bufnr, out:push(data))
    window.set_cursor_end(win)
end

local function on_cmd_exit()
    buffer.append_lines(bufnr, out:flush())
    window.set_cursor_end(win)
    buffer.set_modifiable(bufnr, false)
end

function M.get_cli()
    if cli then
        return cli
    end

    cli = require "dotnet.cli":new({
        on_cmd_start = on_cmd_start,
        on_cmd_stdout = on_cmd_out,
        on_cmd_stderr = on_cmd_out,
        on_cmd_exit = on_cmd_exit,
    })

    return cli
end

return M
