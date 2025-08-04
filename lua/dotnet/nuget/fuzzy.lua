
local M = {}

-- Check if all characters of `needle` appear in order in `haystack`
function M.fuzzy_match(needle, haystack)
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

-- Filter array using fuzzy match
function M.filter(values, search)
  if not search or search == "" then
    return values
  end

  local results = {}
  for _, val in ipairs(values) do
    if M.fuzzy_match(search, val.text) then
      table.insert(results, val)
    end
  end
  return results
end

return M
