--- Cursor-level verbs over `gutenberg.api.strong`. Composes the shared
--- span primitives (read → replace); errors carry UI-ready copy so keymap
--- edges can `pcall` + notify directly. Drop down to
--- `require('gutenberg.api').strong` for the primitives themselves.

local span = require('gutenberg.span')

---@class gutenberg.strong
---@field wrap fun(ctx?: gutenberg.Context.Partial): gutenberg.strong.Strong Wrap the charwise range in `**...**`. Errors unless the range is charwise and single-line.
---@field remove fun(ctx?: gutenberg.Context.Partial): string Replace the strong emphasis at the cursor with its bare text. Errors when the cursor isn't on strong emphasis.

---@type gutenberg.strong
local M = span.new_verbs(require('gutenberg.api.strong'), 'strong emphasis')

return M
