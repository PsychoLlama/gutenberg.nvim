--- Cursor-level sugar over `gutenberg.api.heading`. Every verb here
--- composes the low-level primitives (read → mutate → replace) and
--- errors with UI-ready messages, so keymap edges can `pcall` + notify
--- directly. Drop down to `require('gutenberg.api').heading` for the
--- primitives themselves.

local api = require('gutenberg.api.heading')
local buffer = require('gutenberg.buffer')
local context = require('gutenberg.context')
local ts = require('gutenberg.treesitter')

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

--- Shift a heading by `delta` levels, clamping into 1..6 instead of
--- erroring at the boundaries.
---@param heading gutenberg.heading.Heading
---@param delta integer
local function shift_level(heading, delta)
  api.set_level(heading, math.min(6, math.max(1, heading.level + delta)))
end

--- Shift the heading at the cursor — or, given a range, every heading
--- starting inside it — by `delta * ctx.count` levels in one buffer
--- update.
---@param delta integer
---@param ctx? gutenberg.Context.Partial
---@return gutenberg.heading.Heading[] written
local function shift(delta, ctx)
  ctx = context.resolve(ctx)
  delta = delta * ctx.count

  if ctx.range == nil then
    return M.update(function(heading)
      shift_level(heading, delta)
    end, ctx)
  end

  local start_row = ctx.range.start[1] - 1
  local stop_row = ctx.range.stop[1] - 1
  ---@type table<integer, string>
  local edits = {}
  ---@type gutenberg.heading.Heading[]
  local written = {}
  for _, entry in ipairs(api.list(ctx)) do
    local sr = entry.node:range()
    if sr >= start_row and sr <= stop_row then
      shift_level(entry.heading, delta)
      edits[sr] = ts.container_prefix(entry.node, ctx.bufnr)
        .. api.render(entry.heading)
      table.insert(written, entry.heading)
    end
  end
  if #written == 0 then
    error('gutenberg: no heading in the selected range', 0)
  end

  buffer.set_rows(ctx.bufnr, edits)
  return written
end

--- Raise the heading at the cursor `ctx.count` levels (`##` → `#`),
--- clamped at level 1. Given `ctx.range`, raises every heading
--- starting inside the range instead — still one buffer update.
--- Errors if the cursor isn't on a heading (or the range holds none).
---@param ctx? gutenberg.Context.Partial
---@return gutenberg.heading.Heading[] written
function M.promote(ctx)
  return shift(-1, ctx)
end

--- Sink the heading at the cursor `ctx.count` levels (`#` → `##`),
--- clamped at level 6. Given `ctx.range`, sinks every heading starting
--- inside the range instead — still one buffer update. Errors if the
--- cursor isn't on a heading (or the range holds none).
---@param ctx? gutenberg.Context.Partial
---@return gutenberg.heading.Heading[] written
function M.demote(ctx)
  return shift(1, ctx)
end

return M
