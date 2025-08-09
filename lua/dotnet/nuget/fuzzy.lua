
local M = {}

-- Check if all characters of `needle` appear in order in `haystack`
function M.fuzzy_match(needle, haystack)
    print("Fuzzy matching:", needle, "in", haystack)
    needle = needle:lower()
    haystack = haystack:lower()

    local j = 1
    for i = 1, #haystack do
        if haystack:sub(i,i) == needle:sub(j,j) then
            j = j + 1
        end
        if j > #needle then
            return true
        end
    end
    return false
end

--- Filters a list of items based on a search term using a matching function.
--- The `match_fn` function is used to extract the string to match against the search term.
--- If the search term is empty or nil, it returns the original list of items.
--- @param items table List of items to filter.
--- @param search_term string term to search for in the items.
--- @param match_fn function function that takes an item and returns the string to match against the search term.
--- @return table|nil list of items that match the search term.
function M.filter(items, search_term, match_fn)
    if items == nil or #items == 0 then
        return {}
    end

    if not search_term or search_term == "" then
        return items
    end

    local results = {}
    for _, item in ipairs(items) do
        local item_to_match = match_fn(item)
        if M.fuzzy_match(search_term, item_to_match) then
            table.insert(results, item)
        end
    end
    return results
end

return M
