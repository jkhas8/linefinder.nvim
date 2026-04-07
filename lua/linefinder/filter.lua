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

--- Fuzzy match: check if all query chars appear in text in order.
--- Returns matched character positions (1-indexed) or nil if no match.
--- @param text string
--- @param query string
--- @param used table|nil Set of byte positions already claimed by previous tokens
--- @return table|nil Array of matched byte positions
local function fuzzy_match(text, query, used)
  local positions = {}
  local lower_text = text:lower()
  local lower_query = query:lower()
  local ti = 1
  for qi = 1, #lower_query do
    local qchar = lower_query:sub(qi, qi)
    local found = false
    while ti <= #lower_text do
      if lower_text:sub(ti, ti) == qchar and not (used and used[ti]) then
        positions[#positions + 1] = ti
        ti = ti + 1
        found = true
        break
      end
      ti = ti + 1
    end
    if not found then
      return nil
    end
  end
  return positions
end

--- Check if all matched positions are consecutive (exact substring match).
--- @param positions table Array of matched byte positions
--- @return boolean
local function is_consecutive(positions)
  for i = 2, #positions do
    if positions[i] - positions[i - 1] ~= 1 then
      return false
    end
  end
  return true
end

--- Score a fuzzy match — lower is better.
--- Exact substring matches get a large bonus (score 0-999).
--- Fuzzy matches get penalized (score 1000+).
--- @param positions table Array of matched byte positions
--- @return number
local function fuzzy_score(positions)
  if #positions == 0 then
    return 0
  end
  local base = positions[1] -- prefer earlier matches
  if is_consecutive(positions) then
    return base -- exact substring: low score (0-999 range)
  end
  -- Fuzzy: add 1000 penalty plus gap penalties
  local score = 1000 + base
  for i = 2, #positions do
    local gap = positions[i] - positions[i - 1]
    if gap > 1 then
      score = score + gap
    end
  end
  return score
end

--- Split query into tokens by whitespace.
--- @param query string
--- @return string[]
local function split_tokens(query)
  local tokens = {}
  for token in query:gmatch("%S+") do
    tokens[#tokens + 1] = token
  end
  return tokens
end

--- Match all tokens against a line (order-independent).
--- Each token is fuzzy-matched individually. All must match for the line to pass.
--- Earlier tokens in the query have higher weight in scoring.
--- @param text string
--- @param tokens string[]
--- @return table|nil Combined array of all matched byte positions, or nil if any token fails
--- @return number score Total score across all tokens
local function multi_token_match(text, tokens)
  local all_positions = {}
  local total_score = 0
  local num_tokens = #tokens
  local used = {} -- track byte positions already claimed by previous tokens
  for i, token in ipairs(tokens) do
    local positions = fuzzy_match(text, token, used)
    if not positions then
      return nil, 0
    end
    -- Mark matched positions as used so later tokens can't reuse them
    for _, pos in ipairs(positions) do
      used[pos] = true
      all_positions[#all_positions + 1] = pos
    end
    -- Earlier tokens get higher weight: first token = num_tokens, last = 1
    local weight = num_tokens - i + 1
    total_score = total_score + fuzzy_score(positions) * weight
  end
  table.sort(all_positions)
  return all_positions, total_score
end

--- Filter lines by fuzzy match with multi-token support.
--- Tokens are split by whitespace and matched independently (order-independent).
--- @param entries table[] Array of {lnum, text}
--- @param query string
--- @return table[] Filtered entries (sorted by match quality)
--- @return table[] Array of matched positions per result (each is an array of byte positions)
function M.filter(entries, query)
  if not query or query == "" then
    return entries, {}
  end
  local tokens = split_tokens(query)
  if #tokens == 0 then
    return entries, {}
  end
  local results = {}
  for _, entry in ipairs(entries) do
    local positions, score = multi_token_match(entry.text, tokens)
    if positions then
      results[#results + 1] = {
        entry = entry,
        positions = positions,
        score = score,
      }
    end
  end
  -- Sort by score (lower is better), then by line number for ties
  table.sort(results, function(a, b)
    if a.score == b.score then
      return a.entry.lnum < b.entry.lnum
    end
    return a.score < b.score
  end)
  local filtered = {}
  local all_positions = {}
  for _, r in ipairs(results) do
    filtered[#filtered + 1] = r.entry
    all_positions[#all_positions + 1] = r.positions
  end
  return filtered, all_positions
end

return M
