-- lua/linefinder/ui.lua
local filter = require("linefinder.filter")

local M = {}

-- State for the current finder session
local state = {
  input_buf = nil,
  input_win = nil,
  results_buf = nil,
  results_win = nil,
  source_buf = nil,
  entries = {},
  filtered = {},
  positions = {},
  selected = 1,
  ns_id = vim.api.nvim_create_namespace("linefinder"),
}

--- Set up highlight groups (linked, so they follow the user's colorscheme).
local function setup_highlights()
  vim.api.nvim_set_hl(0, "LineFinderMatch", { default = true, link = "Search" })
  vim.api.nvim_set_hl(0, "LineFinderSelection", { default = true, link = "CursorLine" })
  vim.api.nvim_set_hl(0, "LineFinderBorder", { default = true, link = "FloatBorder" })
  vim.api.nvim_set_hl(0, "LineFinderPrompt", { default = true, link = "Question" })
end

--- Compute window dimensions and position.
local function calc_layout()
  local editor_w = vim.o.columns
  local editor_h = vim.o.lines - vim.o.cmdheight - 1 -- account for statusline

  local width = math.min(math.floor(editor_w * 0.8), 120)
  local results_height = math.min(math.floor(editor_h * 0.4), 20)

  local col = math.floor((editor_w - width) / 2)
  local total_height = 1 + results_height + 2 -- input + results + borders
  local row = math.floor((editor_h - total_height) / 2)

  return {
    width = width,
    results_height = results_height,
    col = col,
    row = row,
  }
end

--- Render the filtered results into the results buffer.
local function render_results()
  if not state.results_buf or not vim.api.nvim_buf_is_valid(state.results_buf) then
    return
  end
  local lines = {}
  for _, entry in ipairs(state.filtered) do
    lines[#lines + 1] = string.format("%4d: %s", entry.lnum, entry.text)
  end
  if #lines == 0 then
    lines = { "  No matches" }
  end

  vim.bo[state.results_buf].modifiable = true
  vim.api.nvim_buf_set_lines(state.results_buf, 0, -1, false, lines)
  vim.bo[state.results_buf].modifiable = false

  -- Clear old highlights
  vim.api.nvim_buf_clear_namespace(state.results_buf, state.ns_id, 0, -1)

  -- Highlight matched substrings
  -- The prefix is "%4d: " which is 6 chars (4 digits + colon + space)
  for i, pos in ipairs(state.positions) do
    if i <= #state.filtered then
      local prefix_len = #string.format("%4d: ", state.filtered[i].lnum)
      vim.api.nvim_buf_add_highlight(
        state.results_buf,
        state.ns_id,
        "LineFinderMatch",
        i - 1,
        prefix_len + pos.start - 1,
        prefix_len + pos.finish
      )
    end
  end

  -- Highlight selected line
  if #state.filtered > 0 and state.selected >= 1 and state.selected <= #state.filtered then
    vim.api.nvim_buf_add_highlight(
      state.results_buf,
      state.ns_id,
      "LineFinderSelection",
      state.selected - 1,
      0,
      -1
    )
  end
end

--- Handle input changes: re-filter and re-render.
local function on_input_changed()
  local lines = vim.api.nvim_buf_get_lines(state.input_buf, 0, 1, false)
  local query = lines[1] or ""
  state.filtered, state.positions = filter.filter(state.entries, query)
  state.selected = 1
  render_results()
end

--- Close the finder windows and clean up.
local function close()
  if state.input_buf == nil and state.results_buf == nil then
    return
  end
  pcall(vim.cmd, "stopinsert")
  -- Delete autocmds
  pcall(vim.api.nvim_del_augroup_by_name, "LineFinder")

  -- Close windows
  if state.input_win and vim.api.nvim_win_is_valid(state.input_win) then
    vim.api.nvim_win_close(state.input_win, true)
  end
  if state.results_win and vim.api.nvim_win_is_valid(state.results_win) then
    vim.api.nvim_win_close(state.results_win, true)
  end

  -- Wipe buffers
  if state.input_buf and vim.api.nvim_buf_is_valid(state.input_buf) then
    vim.api.nvim_buf_delete(state.input_buf, { force = true })
  end
  if state.results_buf and vim.api.nvim_buf_is_valid(state.results_buf) then
    vim.api.nvim_buf_delete(state.results_buf, { force = true })
  end

  state.input_buf = nil
  state.input_win = nil
  state.results_buf = nil
  state.results_win = nil
end

--- Move selection up or down.
local function move_selection(delta)
  if #state.filtered == 0 then
    return
  end
  state.selected = state.selected + delta
  if state.selected < 1 then
    state.selected = #state.filtered
  elseif state.selected > #state.filtered then
    state.selected = 1
  end
  render_results()
end

--- Accept the current selection: jump to the line and close.
local function accept()
  local entry = state.filtered[state.selected]
  local source_buf = state.source_buf
  close()
  if entry then
    -- Jump to the line in the original buffer
    local win = vim.fn.bufwinid(source_buf)
    if win ~= -1 then
      vim.api.nvim_set_current_win(win)
    end
    vim.api.nvim_win_set_cursor(0, { entry.lnum, 0 })
    -- Move to first non-blank
    vim.cmd("normal! ^")
  end
end

--- Open the finder UI.
function M.open()
  if state.input_win and vim.api.nvim_win_is_valid(state.input_win) then
    return
  end
  setup_highlights()

  state.source_buf = vim.api.nvim_get_current_buf()
  state.entries = filter.get_lines(state.source_buf)
  state.filtered = state.entries
  state.positions = {}
  state.selected = 1

  local layout = calc_layout()

  -- Create results buffer and window (bottom)
  state.results_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[state.results_buf].bufhidden = "wipe"
  vim.bo[state.results_buf].modifiable = false

  state.results_win = vim.api.nvim_open_win(state.results_buf, false, {
    relative = "editor",
    width = layout.width,
    height = layout.results_height,
    col = layout.col,
    row = layout.row + 3, -- below input window (1 line + 2 border lines)
    style = "minimal",
    border = "rounded",
  })
  vim.wo[state.results_win].cursorline = false

  -- Create input buffer and window (top)
  state.input_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[state.input_buf].bufhidden = "wipe"
  vim.bo[state.input_buf].buftype = "nofile"

  state.input_win = vim.api.nvim_open_win(state.input_buf, true, {
    relative = "editor",
    width = layout.width,
    height = 1,
    col = layout.col,
    row = layout.row,
    style = "minimal",
    border = "rounded",
    title = " LineFinder ",
    title_pos = "center",
  })

  -- Enter insert mode in the input window
  vim.cmd("startinsert")

  -- Render initial results (all lines)
  render_results()

  -- Set up autocmd for filtering on input change
  local group = vim.api.nvim_create_augroup("LineFinder", { clear = true })
  vim.api.nvim_create_autocmd({ "TextChangedI", "TextChanged" }, {
    group = group,
    buffer = state.input_buf,
    callback = on_input_changed,
  })

  -- Close if the input buffer is left (e.g., user clicks elsewhere)
  vim.api.nvim_create_autocmd("BufLeave", {
    group = group,
    buffer = state.input_buf,
    callback = function()
      -- Defer to avoid issues during window switching
      vim.schedule(close)
    end,
  })

  -- Buffer-local keymaps for the input window
  local opts = { buffer = state.input_buf, noremap = true, silent = true }

  vim.keymap.set("i", "<CR>", accept, opts)
  vim.keymap.set("i", "<Esc>", close, opts)
  vim.keymap.set("i", "<C-j>", function() move_selection(1) end, opts)
  vim.keymap.set("i", "<C-k>", function() move_selection(-1) end, opts)
  vim.keymap.set("i", "<Down>", function() move_selection(1) end, opts)
  vim.keymap.set("i", "<Up>", function() move_selection(-1) end, opts)
  -- Normal mode mappings in case user exits insert mode
  vim.keymap.set("n", "<CR>", accept, opts)
  vim.keymap.set("n", "<Esc>", close, opts)
  vim.keymap.set("n", "j", function() move_selection(1) end, opts)
  vim.keymap.set("n", "k", function() move_selection(-1) end, opts)
end

return M
