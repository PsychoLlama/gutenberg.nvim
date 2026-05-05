---@class gutenberg.Context.Partial
---@field bufnr? integer
---@field cursor? [integer, integer]

---@class gutenberg.Context: gutenberg.Context.Partial
---@field bufnr integer
---@field cursor [integer, integer] {row (1-indexed), col (0-indexed)}

local M = {}

--- Fill in missing fields from the current buffer and cursor.
---@param ctx? gutenberg.Context.Partial
---@return gutenberg.Context
function M.resolve(ctx)
  ctx = ctx or {}
  return {
    bufnr = ctx.bufnr or vim.api.nvim_get_current_buf(),
    cursor = ctx.cursor or vim.api.nvim_win_get_cursor(0),
  }
end

return M
