---@class gutenberg.list.Config
---@field marker string Default bullet marker for new items.

---@class gutenberg.heading.Config
---@field level integer Default level for new headings (1..6).

---@class gutenberg.table.Config
---@field default_alignment gutenberg.table.Alignment Default column alignment for new tables.

---@class gutenberg.Config
---@field list gutenberg.list.Config
---@field heading gutenberg.heading.Config
---@field table gutenberg.table.Config

---@type gutenberg.Config
local defaults = {
  list = {
    marker = '-',
  },
  heading = {
    level = 1,
  },
  table = {
    default_alignment = 'none',
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
