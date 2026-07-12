--- Cursor-level sugar over `gutenberg.api.heading`. Every verb here
--- composes the low-level primitives (read → mutate → replace) and
--- errors with UI-ready messages, so keymap edges can `pcall` + notify
--- directly. Drop down to `require('gutenberg.api').heading` for the
--- primitives themselves.

local api = require('gutenberg.api.heading')
local context = require('gutenberg.context')

---@class gutenberg.heading
local M = {}

--- Read the heading at the cursor, apply `fn`, and write the result
--- back in a single buffer update. `fn` may mutate the heading in
--- place (and return nothing) or return a replacement list — return
--- `{}` to delete the heading. Errors if the cursor isn't on a
--- heading.
---@param fn fun(heading: gutenberg.heading.Heading): gutenberg.heading.Heading[]?
---@param ctx? gutenberg.Context.Partial
---@return gutenberg.heading.Heading[] written
function M.update(fn, ctx)
  ctx = context.resolve(ctx)
  local heading, node = api.read(ctx)
  local headings = fn(heading) or { heading }
  api.replace(node, headings, ctx)
  return headings
end

--- Raise the heading at the cursor one level (`##` → `#`). Level-1
--- headings are left unchanged. Errors if the cursor isn't on a
--- heading.
---@param ctx? gutenberg.Context.Partial
---@return gutenberg.heading.Heading[] written
function M.promote(ctx)
  return M.update(function(heading)
    if heading.level > 1 then
      api.set_level(heading, heading.level - 1)
    end
  end, ctx)
end

--- Sink the heading at the cursor one level (`#` → `##`). Level-6
--- headings are left unchanged. Errors if the cursor isn't on a
--- heading.
---@param ctx? gutenberg.Context.Partial
---@return gutenberg.heading.Heading[] written
function M.demote(ctx)
  return M.update(function(heading)
    if heading.level < 6 then
      api.set_level(heading, heading.level + 1)
    end
  end, ctx)
end

return M
