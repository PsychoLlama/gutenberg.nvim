---@class gutenberg.list.Config
---@field marker string Default bullet marker for new items.

---@class gutenberg.code_block.Config
---@field fence gutenberg.code_block.Fence Default fence character for new code blocks.
---@field fence_length integer Default fence length (>= 3) for new code blocks.

---@class gutenberg.Config
---@field list gutenberg.list.Config
---@field code_block gutenberg.code_block.Config

---@type gutenberg.Config
local defaults = {
  list = {
    marker = '-',
  },
  code_block = {
    fence = '`',
    fence_length = 3,
  },
}

local M = {}

---@type gutenberg.Config
local current = vim.deepcopy(defaults)

--- Merge user options over the defaults, replacing the active config.
---@param opts? gutenberg.Config
function M.merge(opts)
  current = vim.tbl_deep_extend('force', vim.deepcopy(defaults), opts or {})
end

--- Get the active config.
---@return gutenberg.Config
function M.get()
  return current
end

return M
