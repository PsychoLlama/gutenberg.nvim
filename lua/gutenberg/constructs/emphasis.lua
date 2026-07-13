--- Cursor-level verbs over `gutenberg.api.emphasis`. Composes the shared
--- span primitives (read → replace); errors carry UI-ready copy so keymap
--- edges can `pcall` + notify directly. Drop down to
--- `require('gutenberg.api').emphasis` for the primitives themselves.

local span = require('gutenberg.span')

---@class gutenberg.emphasis
---@field wrap fun(ctx?: gutenberg.Context.Partial): gutenberg.emphasis.Emphasis Wrap the charwise range in `*...*`. Errors unless the range is charwise and single-line.
---@field remove fun(ctx?: gutenberg.Context.Partial): string Replace the emphasis at the cursor with its bare text. Errors when the cursor isn't on emphasis.

---@type gutenberg.emphasis
local M = span.new_verbs(require('gutenberg.api.emphasis'), 'emphasis')

return M
