local M = {}

--- Like `vim.api.nvim_buf_set_lines`, but skips the write (and any undo
--- entry it would create) when the requested replacement equals the
--- existing range. Use everywhere a `replace` may end up writing the
--- buffer's current contents back over themselves.
---@param bufnr integer
---@param start_row integer
---@param end_row integer
---@param lines string[]
function M.set_lines(bufnr, start_row, end_row, lines)
  local current = vim.api.nvim_buf_get_lines(bufnr, start_row, end_row, false)
  if vim.deep_equal(current, lines) then
    return
  end
  vim.api.nvim_buf_set_lines(bufnr, start_row, end_row, false, lines)
end

--- Like `vim.api.nvim_buf_set_text`, but skips the write when the
--- requested replacement equals the existing range.
---@param bufnr integer
---@param start_row integer
---@param start_col integer
---@param end_row integer
---@param end_col integer
---@param replacement string[]
function M.set_text(
  bufnr,
  start_row,
  start_col,
  end_row,
  end_col,
  replacement
)
  local current = vim.api.nvim_buf_get_text(
    bufnr,
    start_row,
    start_col,
    end_row,
    end_col,
    {}
  )
  if vim.deep_equal(current, replacement) then
    return
  end
  vim.api.nvim_buf_set_text(
    bufnr,
    start_row,
    start_col,
    end_row,
    end_col,
    replacement
  )
end

--- Resolve a charwise range's inclusive stop into the exclusive
--- (row, col) pair the nvim_buf_*_text APIs expect, widening the stop
--- column to the full character so multibyte text is never split.
---@param bufnr integer
---@param stop [integer, integer]
---@return integer end_row, integer end_col
local function charwise_stop(bufnr, stop)
  local row = stop[1] - 1
  local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ''
  if #line == 0 then
    return row, 0
  end
  local col = math.min(stop[2], #line - 1)
  return row, col + vim.str_utf_end(line, col + 1) + 1
end

--- Read the text covered by `range`. Linewise ranges return whole
--- lines; charwise ranges return the covered text with the stop column
--- widened to the end of its character.
---@param bufnr integer
---@param range gutenberg.Range
---@return string[]
function M.get_range(bufnr, range)
  if range.mode == 'line' then
    return vim.api.nvim_buf_get_lines(
      bufnr,
      range.start[1] - 1,
      range.stop[1],
      false
    )
  end
  local end_row, end_col = charwise_stop(bufnr, range.stop)
  return vim.api.nvim_buf_get_text(
    bufnr,
    range.start[1] - 1,
    range.start[2],
    end_row,
    end_col,
    {}
  )
end

--- Replace the text covered by `range` with `replacement` in a single
--- buffer update, skipping the write when nothing changes. Linewise
--- ranges replace whole lines; charwise ranges splice text.
---@param bufnr integer
---@param range gutenberg.Range
---@param replacement string[]
function M.set_range(bufnr, range, replacement)
  if range.mode == 'line' then
    M.set_lines(bufnr, range.start[1] - 1, range.stop[1], replacement)
    return
  end
  local end_row, end_col = charwise_stop(bufnr, range.stop)
  M.set_text(
    bufnr,
    range.start[1] - 1,
    range.start[2],
    end_row,
    end_col,
    replacement
  )
end

--- Rewrite scattered single rows in ONE buffer update: reads the
--- spanned block, substitutes the edited rows, and writes the block
--- back with a single `set_lines` (so a bulk operation costs one undo
--- entry). `edits` maps 0-indexed rows to their replacement line.
---@param bufnr integer
---@param edits table<integer, string>
function M.set_rows(bufnr, edits)
  ---@type integer?, integer?
  local min_row, max_row
  for row in pairs(edits) do
    if min_row == nil or row < min_row then
      min_row = row
    end
    if max_row == nil or row > max_row then
      max_row = row
    end
  end
  if min_row == nil or max_row == nil then
    return
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, min_row, max_row + 1, false)
  for row, line in pairs(edits) do
    lines[row - min_row + 1] = line
  end
  M.set_lines(bufnr, min_row, max_row + 1, lines)
end

return M
