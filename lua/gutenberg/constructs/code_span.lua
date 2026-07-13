--- Cursor-level verbs over `gutenberg.api.code_span`. Composes the shared
--- span primitives (read → replace); errors carry UI-ready copy so keymap
--- edges can `pcall` + notify directly. Drop down to
--- `require('gutenberg.api').code_span` for the primitives themselves.

local span = require('gutenberg.span')

---@class gutenberg.code_span
---@field wrap fun(ctx?: gutenberg.Context.Partial): gutenberg.code_span.CodeSpan Wrap the charwise range in backticks (escalating for interior backticks). Errors unless the range is charwise and single-line.
---@field remove fun(ctx?: gutenberg.Context.Partial): string Replace the code span at the cursor with its bare text. Errors when the cursor isn't on a code span.

---@type gutenberg.code_span
local M = span.new_verbs(require('gutenberg.api.code_span'), 'a code span')

return M
