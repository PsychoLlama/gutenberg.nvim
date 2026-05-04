---@class gutenberg.list.Config
---@field marker string Default bullet marker for new items.

---@class gutenberg.Config
---@field list gutenberg.list.Config

---@type gutenberg.Config
local defaults = {
  list = {
    marker = '-',
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
