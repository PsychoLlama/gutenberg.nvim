--- Cursor-level verbs over `gutenberg.api.strikethrough`. Composes the
--- shared span primitives (read → replace); errors carry UI-ready copy so
--- keymap edges can `pcall` + notify directly. Drop down to
--- `require('gutenberg.api').strikethrough` for the primitives themselves.

local span = require('gutenberg.span')

---@class gutenberg.strikethrough
---@field wrap fun(ctx?: gutenberg.Context.Partial): gutenberg.strikethrough.Strikethrough Wrap the charwise range in `~~...~~`. Errors unless the range is charwise and single-line.
---@field remove fun(ctx?: gutenberg.Context.Partial): string Replace the strikethrough at the cursor with its bare text. Errors when the cursor isn't on strikethrough.

---@type gutenberg.strikethrough
local M =
  span.new_verbs(require('gutenberg.api.strikethrough'), 'strikethrough')

return M
