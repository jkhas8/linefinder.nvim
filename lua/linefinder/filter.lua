-- lua/linefinder/filter.lua
local M = {}

--- Capture all lines from a buffer with their line numbers.
--- @param bufnr number
--- @return table[] Array of {lnum: number, text: string}
function M.get_lines(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local result = {}
  for i, line in ipairs(lines) do
    result[#result + 1] = { lnum = i, text = line }
  end
  return result
end

--- Filter lines by case-insensitive substring match.
--- @param entries table[] Array of {lnum, text}
--- @param query string
--- @return table[] Filtered entries (preserves original order)
--- @return table[] Array of {start, finish} match positions per result (1-indexed)
function M.filter(entries, query)
  if query == "" then
    return entries, {}
  end
  local lower_query = query:lower()
  local filtered = {}
  local positions = {}
  for _, entry in ipairs(entries) do
    local start = entry.text:lower():find(lower_query, 1, true)
    if start then
      filtered[#filtered + 1] = entry
      positions[#positions + 1] = { start = start, finish = start + #query - 1 }
    end
  end
  return filtered, positions
end

return M
