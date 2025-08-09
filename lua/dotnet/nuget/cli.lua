local M = {}

local buffer = require "dotnet.utils.buffer"
local window = require "dotnet.utils.window"

function M.new(bufnr, win)
    local on_cmd_start = function()
        print("Starting command...")
        buffer.clean(bufnr)
    end

    local on_cmd_out = function(_, data, _)
        print("Command output received")
        buffer.append_lines(bufnr, data)
        buffer.set_modifiable(bufnr, false)
    end

    local on_cmd_exit = function()
        print("Command finished")
        window.set_cursor_end(win)
    end

    local cli = require "dotnet.cli.cli":new({
        on_cmd_start = on_cmd_start,
        on_cmd_stdout = on_cmd_out,
        on_cmd_stderr = on_cmd_out,
        on_cmd_exit = on_cmd_exit,
    })

    return cli
end

return M
