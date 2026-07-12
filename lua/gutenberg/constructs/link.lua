--- Cursor-level sugar over `gutenberg.api.link`. Every verb here
--- composes the low-level primitives (read → mutate → replace) and
--- errors with UI-ready messages, so keymap edges can `pcall` + notify
--- directly. Drop down to `require('gutenberg.api').link` for the
--- primitives themselves.

local api = require('gutenberg.api.link')
local buffer = require('gutenberg.buffer')
local context = require('gutenberg.context')

---@class gutenberg.link
local M = {}

--- Wrap the text covered by `ctx.range` in an inline link, using the
--- covered text as the link text. `opts.url` defaults to `''` —
--- `[text]()` is legal markdown, so the keymap edge may prompt and
--- pass an empty answer through. Returns the written link. Errors
--- unless the range is charwise and on a single line.
---@param opts? { url?: string }
---@param ctx? gutenberg.Context.Partial
---@return gutenberg.link.Link written
function M.wrap(opts, ctx)
  opts = opts or {}
  ctx = context.resolve(ctx)

  local range = ctx.range
  if range == nil or range.mode ~= 'char' then
    error('gutenberg: wrapping a link requires a charwise selection', 0)
  end
  if range.start[1] ~= range.stop[1] then
    error('gutenberg: cannot wrap multiple lines in a link', 0)
  end

  local text = buffer.get_range(ctx.bufnr, range)[1] or ''
  local link = api.create({
    kind = 'inline',
    text = text,
    url = opts.url or '',
  })
  buffer.set_range(ctx.bufnr, range, { api.render(link) })
  return link
end

--- Replace the link at the cursor with its visible text (autolinks
--- with their URL). Errors if the cursor isn't on a link.
---@param ctx? gutenberg.Context.Partial
---@return string text
function M.remove(ctx)
  ctx = context.resolve(ctx)
  local link, node = api.read(ctx)
  local text = link.text or link.url or ''
  local sr, sc, er, ec = node:range()
  buffer.set_text(ctx.bufnr, sr, sc, er, ec, { text })
  return text
end

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
