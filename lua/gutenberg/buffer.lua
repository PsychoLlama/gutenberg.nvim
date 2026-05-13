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

return M
