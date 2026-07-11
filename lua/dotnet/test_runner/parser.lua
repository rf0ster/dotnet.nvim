local M = {}

-- Decodes the five predefined XML entities. `&amp;` must be decoded last so
-- that an escaped entity such as `&amp;lt;` survives as the literal `&lt;`.
local function unescape(s)
    if not s then
        return s
    end
    return (s:gsub("&lt;", "<")
        :gsub("&gt;", ">")
        :gsub("&quot;", '"')
        :gsub("&apos;", "'")
        :gsub("&amp;", "&"))
end

-- Reads a double-quoted attribute out of a start-tag's text.
local function attr(tag, name)
    return unescape(tag:match(name .. '%s*=%s*"([^"]*)"'))
end

-- Given a filepath, /path/to/test_results.trx,
-- returns table with the following structure:
-- {
--      { testName = "test_name", outcome = "Passed", duration = "00:00:00.1", startTime = "...", endTime = "...", output = nil },
--      { testName = "test_name", outcome = "Failed", ..., output = { Message = "...", StackTrace = "..." } },
--      ...
--  }
-- The .trx format is XML. Each result is a <UnitTestResult> element whose
-- attributes hold the summary fields; failures carry an <ErrorInfo> child with
-- <Message>/<StackTrace> text. We scan for those with Lua patterns rather than
-- a full XML parser so the plugin has no LuaRocks dependency.
M.parse_trx_file = function(file_path)
    local file = io.open(file_path, "r")
    if not file then
        return nil
    end
    local content = file:read("*all")
    file:close()

    local test_results = {}
    local pos = 1
    while true do
        local open_start = content:find("<UnitTestResult", pos, true)
        if not open_start then
            break
        end

        -- The start-tag ends at the next '>'. Attribute values in a .trx never
        -- contain a literal '>' (it is escaped as &gt;), so a plain find is safe.
        local open_end = content:find(">", open_start, true)
        if not open_end then
            break
        end

        local open_tag = content:sub(open_start, open_end)
        local self_closing = open_tag:sub(-2) == "/>"

        local output = nil
        if not self_closing then
            local close = content:find("</UnitTestResult>", open_end, true)
            local body = content:sub(open_end + 1, close and close - 1 or #content)

            local err_info = body:match("<ErrorInfo>(.-)</ErrorInfo>")
            if err_info then
                output = {
                    Message = unescape(err_info:match("<Message>(.-)</Message>")) or "",
                    StackTrace = unescape(err_info:match("<StackTrace>(.-)</StackTrace>")) or "",
                }
            end

            pos = (close or open_end) + 1
        else
            pos = open_end + 1
        end

        table.insert(test_results, {
            testName = attr(open_tag, "testName"),
            outcome = attr(open_tag, "outcome"),
            duration = attr(open_tag, "duration"),
            startTime = attr(open_tag, "startTime"),
            endTime = attr(open_tag, "endTime"),
            output = output,
        })
    end

    return test_results
end

return M
