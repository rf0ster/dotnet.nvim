local M = {}

local xml2lua = require("xml2lua")
local handler = require("xmlhandler.tree")

-- Given a filepath, /path/to/test_results.trx,
-- returns table with the following structure:
-- {
--      { project = "project_name", testName = "test_name", outcome = "Passed", duration = 0.1, output = {} },
--      { project = "project_name", testName = "test_name", outcome = "Passed", duration = 0.1, output = {} },
--      ...
--  }
-- Uses xml2lua to parse the trx file.
M.parse_trx_file = function(file_path)
    -- Read the .trx XML content
    local file = io.open(file_path, "r")
    if not file then
       return nil
    end
    local xml_content = file:read("*all")
    file:close()

    local function clean_xml(xml)
        -- Remove BOM if present
        xml = xml:gsub("^\239\187\191", "") -- UTF-8 BOM (EF BB BF)

        -- Trim any leading junk before the XML declaration
        local start_pos = xml_content:find("<%?xml")
        if start_pos then
            xml_content = xml_content:sub(start_pos)
        end

        return xml
    end
    xml_content = clean_xml(xml_content)

    -- Parse the XML using xml2lua
    local tree = handler:new()
    local parser = xml2lua.parser(tree)
    parser:parse(xml_content)

    -- Extract test results from the TestResults node
    local test_results = {}
    local results = tree.root and tree.root.TestRun and tree.root.TestRun.Results and tree.root.TestRun.Results.UnitTestResult

    local get_output = function(test_result)
        if test_result.Output and test_result.Output.ErrorInfo then
            return {
                Message = test_result.Output.ErrorInfo.Message,
                StackTrace = test_result.Output.ErrorInfo.StackTrace,
            }
        end
        return nil
    end

    if results then
        -- If there are multiple test results, iterate over them
        if type(results) == "table" and #results > 0 then
            for _, test in ipairs(results) do
                table.insert(test_results, {
                    testName = test._attr.testName,
                    outcome = test._attr.outcome,
                    duration = test._attr.duration,
                    startTime = test._attr.startTime,
                    endTime = test._attr.endTime,
                    output = get_output(test)
                })
            end
        else
            -- Handle single test case scenario
            table.insert(test_results, {
                testName = results._attr.testName,
                outcome = results._attr.outcome,
                duration = results._attr.duration,
                startTime = results._attr.startTime,
                endTime = results._attr.endTime,
                output = get_output(results)
            })
        end
    end

    return test_results
end

return M
