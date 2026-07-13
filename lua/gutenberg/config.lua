-- Config classes come in pairs: a `.Partial` where every field is
-- optional — the shape users pass to `setup()` — and the full class it
-- resolves to once merged over the defaults, which internal readers see
-- through `config.get()`. This mirrors `gutenberg.Context.Partial`.

---@class gutenberg.list.Config.Partial
---@field marker? string Default bullet marker for new items.
---@field indent? string Whitespace unit for the `api.list` indent/dedent primitives, and the minimum shift for `gutenberg.list.indent` (which widens as needed to actually nest). When nil, derived per call from the target buffer's `&expandtab` and `&tabstop`.
---@field default_checked? boolean State of a newly-inserted checkbox. Callers driving a "toggle" keymap should read this when promoting an item to a checkbox so the inserted state respects user preference.

---@class gutenberg.list.Config: gutenberg.list.Config.Partial
---@field marker string
---@field default_checked boolean

---@class gutenberg.heading.Config.Partial
---@field level? integer Default level for new headings (1..6).

---@class gutenberg.heading.Config: gutenberg.heading.Config.Partial
---@field level integer

---@class gutenberg.table.Config.Partial
---@field default_alignment? gutenberg.table.Alignment Default column alignment for new tables.

---@class gutenberg.table.Config: gutenberg.table.Config.Partial
---@field default_alignment gutenberg.table.Alignment

---@class gutenberg.code_block.Config.Partial
---@field fence? gutenberg.code_block.Fence Default fence character for new code blocks.
---@field fence_length? integer Default fence length (>= 3) for new code blocks.

---@class gutenberg.code_block.Config: gutenberg.code_block.Config.Partial
---@field fence gutenberg.code_block.Fence
---@field fence_length integer

---@class gutenberg.link.Config.Partial
---@field default_kind? gutenberg.link.Kind Kind used when `create` omits one.

---@class gutenberg.link.Config: gutenberg.link.Config.Partial
---@field default_kind gutenberg.link.Kind

---@class gutenberg.emphasis.Config.Partial
---@field delimiter? string Delimiter wrapping emphasized text. Defaults to prettier's `_`; `*` is the common alternative.

---@class gutenberg.emphasis.Config: gutenberg.emphasis.Config.Partial
---@field delimiter string

---@class gutenberg.strong.Config.Partial
---@field delimiter? string Delimiter wrapping strong (bold) text. Defaults to prettier's `**`; `__` is the alternative.

---@class gutenberg.strong.Config: gutenberg.strong.Config.Partial
---@field delimiter string

---@class gutenberg.default_keymaps.Config.Partial
---@field enable? boolean Bind the recommended keymaps (:h gutenberg-recommended-config) on FileType. Off by default — gutenberg ships no keymaps unless asked.
---@field filetypes? string[] Filetypes to bind in. Dotted compounds match the full 'filetype' value, hence the explicit 'markdown.mdx' entry.

---@class gutenberg.default_keymaps.Config: gutenberg.default_keymaps.Config.Partial
---@field enable boolean
---@field filetypes string[]

---@class gutenberg.Config.Partial
---@field default_keymaps? gutenberg.default_keymaps.Config.Partial
---@field list? gutenberg.list.Config.Partial
---@field heading? gutenberg.heading.Config.Partial
---@field table? gutenberg.table.Config.Partial
---@field code_block? gutenberg.code_block.Config.Partial
---@field link? gutenberg.link.Config.Partial
---@field emphasis? gutenberg.emphasis.Config.Partial
---@field strong? gutenberg.strong.Config.Partial

---@class gutenberg.Config: gutenberg.Config.Partial
---@field default_keymaps gutenberg.default_keymaps.Config
---@field list gutenberg.list.Config
---@field heading gutenberg.heading.Config
---@field table gutenberg.table.Config
---@field code_block gutenberg.code_block.Config
---@field link gutenberg.link.Config
---@field emphasis gutenberg.emphasis.Config
---@field strong gutenberg.strong.Config

---@type gutenberg.Config
local defaults = {
  default_keymaps = {
    enable = false,
    filetypes = { 'markdown', 'markdown.mdx', 'mdx' },
  },
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
  emphasis = {
    delimiter = '_',
  },
  strong = {
    delimiter = '**',
  },
}

---@class gutenberg.config
local M = {}

---@type gutenberg.Config
local current = vim.deepcopy(defaults)

--- Merge user options over the defaults, replacing the active config.
---@param opts? gutenberg.Config.Partial
function M.merge(opts)
  current = vim.tbl_deep_extend('force', vim.deepcopy(defaults), opts or {})
end

--- Get the active config.
---@return gutenberg.Config
function M.get()
  return current
end

return M
