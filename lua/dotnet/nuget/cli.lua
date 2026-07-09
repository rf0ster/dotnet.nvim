local M = {}

local buffer = require "dotnet.utils.buffer"
local window = require "dotnet.utils.window"
local stream = require "dotnet.cli.stream"

--- Creates a DotnetCli instance whose output streams into the given buffer.
--- @param bufnr number The buffer to stream command output into.
--- @param win number|nil The window showing the buffer; cursor moves to the end on exit.
--- @param on_exit function|nil Called after the command finishes.
function M.new(bufnr, win, on_exit)
    -- Normalizes raw jobstart chunks: reassembles partial lines, strips
    -- carriage returns from CRLF output, and tidies blank runs. The gutter
    -- pads content away from the window border.
    local out = stream.new({ gutter = " " })

    local on_cmd_start = function()
        buffer.clear(bufnr)
    end

    local on_cmd_out = function(_, data, _)
        buffer.append_lines(bufnr, out:push(data))
        window.set_cursor_end(win)
    end

    local on_cmd_exit = function()
        buffer.append_lines(bufnr, out:flush())
        window.set_cursor_end(win)
        if on_exit then
            on_exit()
        end
    end

    local cli = require "dotnet.cli":new({
        on_cmd_start = on_cmd_start,
        on_cmd_stdout = on_cmd_out,
        on_cmd_stderr = on_cmd_out,
        on_cmd_exit = on_cmd_exit,
    })

    return cli
end

return M
