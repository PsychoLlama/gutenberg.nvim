---@class gutenberg.list.Config
---@field marker string Default bullet marker for new items.
---@field indent? string Whitespace unit for the `api.list` indent/dedent primitives, and the minimum shift for `gutenberg.list.indent` (which widens as needed to actually nest). When nil, derived per call from the target buffer's `&expandtab` and `&tabstop`.
---@field default_checked boolean State of a newly-inserted checkbox. Callers driving a "toggle" keymap should read this when promoting an item to a checkbox so the inserted state respects user preference.

---@class gutenberg.heading.Config
---@field level integer Default level for new headings (1..6).

---@class gutenberg.table.Config
---@field default_alignment gutenberg.table.Alignment Default column alignment for new tables.

---@class gutenberg.code_block.Config
---@field fence gutenberg.code_block.Fence Default fence character for new code blocks.
---@field fence_length integer Default fence length (>= 3) for new code blocks.

---@class gutenberg.link.Config
---@field default_kind gutenberg.link.Kind Kind used when `create` omits one.

---@class gutenberg.Config
---@field list gutenberg.list.Config
---@field heading gutenberg.heading.Config
---@field table gutenberg.table.Config
---@field code_block gutenberg.code_block.Config
---@field link gutenberg.link.Config

---@type gutenberg.Config
local defaults = {
  list = {
    marker = '-',
    default_checked = true,
  },
  heading = {
    level = 1,
  },
  table = {
    default_alignment = 'none',
  },
  code_block = {
    fence = '`',
    fence_length = 3,
  },
  link = {
    default_kind = 'inline',
  },
}

---@class gutenberg.config
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
