---@class gutenberg.Range
---@field mode 'line' | 'char'
---@field start [integer, integer] {row (1-indexed), col (0-indexed byte)}. Inclusive.
---@field stop [integer, integer] Inclusive. col is normalized to 0 for 'line' mode.

---@class gutenberg.Context.Partial
---@field bufnr? integer
---@field cursor? [integer, integer]
---@field count? integer
---@field range? gutenberg.Range

---@class gutenberg.Context: gutenberg.Context.Partial
---@field bufnr integer
---@field cursor [integer, integer] {row (1-indexed), col (0-indexed)}
---@field count integer
---@field range? gutenberg.Range

local M = {}

---@param position unknown
---@return boolean
local function is_position(position)
  return type(position) == 'table'
    and type(position[1]) == 'number'
    and type(position[2]) == 'number'
end

--- Validate a range and return a normalized copy: endpoints swapped so
--- `start` never falls after `stop`, and columns zeroed on 'line'
--- ranges so equivalent selections compare equal.
---@param range gutenberg.Range
---@return gutenberg.Range
local function normalize_range(range)
  if range.mode ~= 'line' and range.mode ~= 'char' then
    error(
      "gutenberg: range mode must be 'line' or 'char', got "
        .. tostring(range.mode),
      0
    )
  end
  if not is_position(range.start) or not is_position(range.stop) then
    error('gutenberg: range start/stop must be {row, col} pairs', 0)
  end

  local start = { range.start[1], range.start[2] }
  local stop = { range.stop[1], range.stop[2] }
  if stop[1] < start[1] or (stop[1] == start[1] and stop[2] < start[2]) then
    start, stop = stop, start
  end
  if range.mode == 'line' then
    start[2] = 0
    stop[2] = 0
  end
  return { mode = range.mode, start = start, stop = stop }
end

--- Fill in missing fields from the current buffer and cursor. `count`
--- defaults to 1 and must be a positive integer when given — callers at
--- the keymap edge pass `vim.v.count1` themselves; `resolve` never
--- reads it. When a range is given without a cursor, the cursor
--- defaults to the range start so cursor probes (`is_*`) gate
--- range-driven calls for free.
---@param ctx? gutenberg.Context.Partial
---@return gutenberg.Context
function M.resolve(ctx)
  ctx = ctx or {}

  local count = ctx.count or 1
  if type(count) ~= 'number' or count < 1 or count ~= math.floor(count) then
    error(
      'gutenberg: count must be a positive integer, got ' .. tostring(count),
      0
    )
  end

  ---@type gutenberg.Range?
  local range
  if ctx.range ~= nil then
    range = normalize_range(ctx.range)
  end

  local cursor = ctx.cursor
  if cursor == nil and range ~= nil then
    cursor = { range.start[1], range.start[2] }
  end

  return {
    bufnr = ctx.bufnr or vim.api.nvim_get_current_buf(),
    cursor = cursor or vim.api.nvim_win_get_cursor(0),
    count = count,
    range = range,
  }
end

--- Build a Range from the most recent visual selection (the `'<` / `'>`
--- marks and `visualmode()`). Only meaningful after leaving visual mode
--- — inside visual mode the marks still describe the previous
--- selection. Errors on blockwise selections and when no visual
--- selection has been made.
---@param bufnr? integer Defaults to the current buffer.
---@return gutenberg.Range
function M.range_from_visual(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local mode = vim.fn.visualmode()
  if mode == '' then
    error('gutenberg: no visual selection to build a range from', 0)
  end
  if mode ~= 'v' and mode ~= 'V' then
    error('gutenberg: blockwise visual ranges are not supported', 0)
  end

  local start = vim.api.nvim_buf_get_mark(bufnr, '<')
  local stop = vim.api.nvim_buf_get_mark(bufnr, '>')
  if start[1] == 0 or stop[1] == 0 then
    error('gutenberg: no visual selection to build a range from', 0)
  end

  return normalize_range({
    mode = mode == 'V' and 'line' or 'char',
    start = start,
    stop = stop,
  })
end

return M
