--- Cursor-level sugar over `gutenberg.api.link`. Every verb here
--- composes the low-level primitives (read → mutate → replace) and
--- errors with UI-ready messages, so keymap edges can `pcall` + notify
--- directly. Drop down to `require('gutenberg.api').link` for the
--- primitives themselves.

local api = require('gutenberg.api.link')
local context = require('gutenberg.context')

---@class gutenberg.link
local M = {}

--- Read the link at the cursor, apply `fn`, and write the result back
--- in a single buffer update. `fn` may mutate the link in place (and
--- return nothing) or return a replacement list — return `{}` to
--- delete the link. Errors if the cursor isn't on a link.
---@param fn fun(link: gutenberg.link.Link): gutenberg.link.Link[]?
---@param ctx? gutenberg.Context.Partial
---@return gutenberg.link.Link[] written
function M.update(fn, ctx)
  ctx = context.resolve(ctx)
  local link, node = api.read(ctx)
  local links = fn(link) or { link }
  api.replace(node, links, ctx)
  return links
end

return M
