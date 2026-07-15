-- Description: Persistent, merged store of test results, keyed by solution.
--
-- `dotnet test` overwrites its .trx on every invocation, so a filtered run
-- (a single test) leaves the .trx holding only that test. Reading results
-- straight from the .trx therefore drops every test outside the latest run on
-- the next reload. This module keeps one JSON file per solution and merges each
-- run into it, retaining the most recently run result for every test.

local M = {}

-- Root directory for persisted results, under Neovim's data dir
-- (e.g. ~/.local/share/nvim/dotnet.nvim/test_results). stdpath is backslashed
-- on Windows, so normalize to keep the joined path from mixing separators.
local function store_dir()
    return vim.fs.normalize(vim.fn.stdpath("data")) .. "/dotnet.nvim/test_results"
end

-- Stable, filesystem-safe file name derived from the solution's absolute path,
-- so each solution keeps its own results regardless of the current directory.
local function store_path(sln_path_abs)
    return store_dir() .. "/" .. vim.fn.sha256(sln_path_abs or "") .. ".json"
end

--- Loads the persisted results for a solution.
--- @param sln_path_abs string|nil Absolute path to the solution file
--- @return table results Map of project_rel -> testName -> result record (never nil)
function M.load(sln_path_abs)
    local f = io.open(store_path(sln_path_abs), "r")
    if not f then
        return {}
    end
    local content = f:read("*a")
    f:close()

    if not content or content == "" then
        return {}
    end
    local ok, data = pcall(vim.json.decode, content)
    if not ok or type(data) ~= "table" then
        return {}
    end
    return data
end

--- Persists the results for a solution.
--- @param sln_path_abs string|nil Absolute path to the solution file
--- @param data table Map of project_rel -> testName -> result record
function M.save(sln_path_abs, data)
    vim.fn.mkdir(store_dir(), "p")
    local f = io.open(store_path(sln_path_abs), "w")
    if not f then
        return
    end
    f:write(vim.json.encode(data))
    f:close()
end

-- Returns true if result `a` is at least as recent as the stored result `b`,
-- comparing test end times. Timestamps are ISO-8601 produced on one machine, so
-- a lexical compare is monotonic. Missing end times sort oldest.
local function is_newer(a, b)
    if b == nil or b.endTime == nil then
        return true
    end
    if a.endTime == nil then
        return false
    end
    return a.endTime >= b.endTime
end

--- Merges a project's freshly parsed .trx results into the store, keeping the
--- most recently run result for each test. Tests absent from `results` are left
--- as they were, which is what preserves state across filtered runs.
--- @param data table The full store (project_rel -> testName -> record)
--- @param project_rel string Relative project path used as the bucket key
--- @param results table|nil List of result records from parser.parse_trx_file
function M.merge_project(data, project_rel, results)
    if results == nil then
        return
    end

    local bucket = data[project_rel]
    if bucket == nil then
        bucket = {}
        data[project_rel] = bucket
    end

    for _, result in ipairs(results) do
        local name = result.testName
        if name ~= nil and is_newer(result, bucket[name]) then
            bucket[name] = result
        end
    end
end

return M
