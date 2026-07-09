-- Description: Turns raw neovim jobstart stdout/stderr chunks into clean,
-- display-ready lines.
--
-- jobstart delivers process output as a byte stream that is broken into a
-- list wherever a "\n" byte occurs, and those break points fall at arbitrary
-- boundaries: a single logical line can be split across two callbacks, where
-- the last item of one chunk continues into the first item of the next. This
-- module reassembles those partial lines, then normalizes each finished line
-- so the output reads cleanly no matter which OS produced it:
--
--   * carriage returns left behind by CRLF (Windows) endings are stripped;
--   * trailing whitespace is trimmed;
--   * runs of blank lines are collapsed to a single blank line; and
--   * blank lines before the first real line are dropped.
--
-- Leading whitespace is preserved so nested build output keeps its
-- indentation. See ":help channel-lines" for the jobstart streaming contract.

local M = {}

local Stream = {}
Stream.__index = Stream

--- Creates a new stream processor. Create one processor per command run so
--- its partial-line and blank-run state starts fresh.
--- @param opts table|nil Options:
---   - gutter (string): prefix added to every non-blank line so content is
---     padded away from the window border (default "").
---   - collapse_blanks (boolean): collapse consecutive blank lines into a
---     single blank line (default true).
--- @return table The stream processor.
function M.new(opts)
    opts = opts or {}
    return setmetatable({
        gutter = opts.gutter or "",
        collapse_blanks = opts.collapse_blanks ~= false,
        pending = "",    -- trailing partial line carried between chunks
        blanks = 0,      -- length of the current run of blank lines
        started = false, -- whether a non-blank line has been emitted yet
    }, Stream)
end

--- Normalizes a single finished line and appends the result (0 or 1 lines)
--- to `out`.
function Stream:_emit(line, out)
    -- Strip carriage returns (CRLF endings and stray "\r" redraws) and any
    -- trailing whitespace. Leading whitespace is kept to preserve indentation.
    line = line:gsub("\r", ""):gsub("%s+$", "")

    if line == "" then
        -- Never lead with a blank line, and collapse runs to a single blank.
        if not self.started then
            return
        end
        if self.collapse_blanks and self.blanks > 0 then
            return
        end
        self.blanks = self.blanks + 1
        table.insert(out, "")
    else
        self.blanks = 0
        self.started = true
        table.insert(out, self.gutter .. line)
    end
end

--- Feeds one raw jobstart data chunk and returns the lines it completed. The
--- trailing partial line is held back until the next push() or flush().
--- @param data table The list of strings from an on_stdout/on_stderr event.
--- @return table A list of normalized lines ready to append (may be empty).
function Stream:push(data)
    local out = {}
    if type(data) ~= "table" or #data == 0 then
        return out
    end

    local n = #data
    for i = 1, n do
        local chunk = data[i]
        if i == 1 then
            chunk = self.pending .. chunk
        end
        if i < n then
            self:_emit(chunk, out)
        else
            -- The last item continues into the next chunk, or is emitted by
            -- flush() when the command exits.
            self.pending = chunk
        end
    end

    return out
end

--- Emits any buffered partial line. Call once when the command exits so a
--- final line that has no trailing newline is not lost.
--- @return table A list containing 0 or 1 normalized lines.
function Stream:flush()
    local out = {}
    if self.pending ~= "" then
        self:_emit(self.pending, out)
        self.pending = ""
    end
    return out
end

return M
