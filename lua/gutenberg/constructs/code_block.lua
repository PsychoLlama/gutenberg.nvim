--- Cursor-level sugar over `gutenberg.api.code_block`. Every verb here
--- composes the low-level primitives (read → mutate → replace) and
--- errors with UI-ready messages, so keymap edges can `pcall` + notify
--- directly. Drop down to `require('gutenberg.api').code_block` for
--- the primitives themselves.

local api = require('gutenberg.api.code_block')
local context = require('gutenberg.context')

---@class gutenberg.code_block
local M = {}

--- Read the code block at the cursor, apply `fn`, and write the result
--- back in a single buffer update. `fn` may mutate the block in place
--- (and return nothing) or return a replacement list — return `{}` to
--- delete the block. Errors if the cursor isn't on a fenced code
--- block.
---@param fn fun(block: gutenberg.code_block.CodeBlock): gutenberg.code_block.CodeBlock[]?
---@param ctx? gutenberg.Context.Partial
---@return gutenberg.code_block.CodeBlock[] written
function M.update(fn, ctx)
  ctx = context.resolve(ctx)
  local block, node = api.read(ctx)
  local blocks = fn(block) or { block }
  api.replace(node, blocks, ctx)
  return blocks
end

return M
