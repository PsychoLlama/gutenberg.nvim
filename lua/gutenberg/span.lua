--- Shared implementation for the inline "span" constructs — emphasis,
--- strong emphasis, strikethrough, and code spans. They all wrap a run of
--- text in a matched pair of delimiters, so each api/construct module is a
--- thin, fully-typed declaration over the factories here. Internal — not
--- part of the public API.
---
--- The tricky part is decoding: the delimiters are child nodes, but the
--- markdown_inline grammar renders `~~x~~` as a `strikethrough` node nested
--- inside a `strikethrough` node (the two `~` on each side land one level
--- apart), and `***x***` as a `strong_emphasis` nested inside an
--- `emphasis`. So we resolve to the outermost same-type node (climbing only
--- through nestings that fill their parent's whole delimited span, which
--- distinguishes the strikethrough artifact from genuinely nested emphasis
--- like `*a *b* c*`) and gather delimiter leaves through same-type children
--- only.

local buffer = require('gutenberg.buffer')
local context = require('gutenberg.context')
local ts = require('gutenberg.treesitter')

---@class gutenberg.span.Config
---@field capture string Query capture (and probe suffix): `emphasis`, `strong`, …
---@field delimiter string TS node type of the delimiter leaves.
---@field noun string Human phrase for error copy, e.g. `emphasis`, `a code span`.
---@field render fun(text: string): string Wrap `text` in the construct's delimiters.
---@field decode fun(raw: string): string Post-process the delimiter-stripped content (identity for most; strips code-span padding).

---@class gutenberg.span.Value
---@field text string Visible text, delimiters stripped.

---@class gutenberg.span.Api
---@field read fun(ctx?: gutenberg.Context.Partial): gutenberg.span.Value, TSNode
---@field create fun(fields: { text: string }): gutenberg.span.Value
---@field render fun(value: gutenberg.span.Value): string

---@alias gutenberg.span.Range { [1]: integer, [2]: integer, [3]: integer, [4]: integer }

local M = {}

--- Collect delimiter-leaf ranges within `node` in document order,
--- descending only through nested nodes of `node`'s own `node_type`. The
--- grammar splits a strikethrough's `~~` across a nested strikethrough, so
--- its delimiters live one level down; but a `strong_emphasis` inside an
--- `emphasis` is content, not a delimiter, and must not be descended.
---@param node TSNode
---@param node_type string
---@param delimiter string
---@param out gutenberg.span.Range[]
local function collect_delimiters(node, node_type, delimiter, out)
  for child in node:iter_children() do
    local t = child:type()
    if t == delimiter then
      local sr, sc, er, ec = child:range()
      out[#out + 1] = { sr, sc, er, ec }
    elseif t == node_type then
      collect_delimiters(child, node_type, delimiter, out)
    end
  end
end

---@param a gutenberg.span.Range
---@param b gutenberg.span.Range
---@return boolean
local function adjacent(a, b)
  return a[3] == b[1] and a[4] == b[2]
end

--- The content region of a span: everything between its leading and
--- trailing delimiter runs. `delimiters` is the ordered leaf list. Returns
--- `(start_row, start_col, stop_row, stop_col)`, or nil when there are no
--- delimiters.
---@param delimiters gutenberg.span.Range[]
---@return integer?, integer?, integer?, integer?
local function content_span(delimiters)
  local n = #delimiters
  if n == 0 then
    return nil
  end
  local i = 1
  while i < n and adjacent(delimiters[i], delimiters[i + 1]) do
    i = i + 1
  end
  local j = n
  while j > 1 and adjacent(delimiters[j - 1], delimiters[j]) do
    j = j - 1
  end
  return delimiters[i][3],
    delimiters[i][4],
    delimiters[j][1],
    delimiters[j][2]
end

--- The content region of `node` computed from its DIRECT delimiter children
--- only (no same-type descent). Used to test whether a same-type child
--- exactly fills its parent's delimited span.
---@param node TSNode
---@param delimiter string
---@return integer?, integer?, integer?, integer?
local function direct_content_span(node, delimiter)
  ---@type gutenberg.span.Range[]
  local delims = {}
  -- An empty node_type never equals a real type, so nothing is descended.
  collect_delimiters(node, '', delimiter, delims)
  return content_span(delims)
end

--- Climb to the outermost same-type ancestor that `node` fills exactly (its
--- delimiters butt directly against the parent's), unwinding the grammar's
--- `~~x~~`-as-nested-strikethrough artifact while leaving genuinely nested
--- emphasis (`*a *b* c*`) alone.
---@param node TSNode
---@param delimiter string
---@return TSNode
local function outermost(node, delimiter)
  while true do
    local parent = node:parent()
    if parent == nil or parent:type() ~= node:type() then
      return node
    end
    local sr, sc, er, ec = direct_content_span(parent, delimiter)
    if sr == nil then
      return node
    end
    local nsr, nsc, ner, nec = node:range()
    if nsr == sr and nsc == sc and ner == er and nec == ec then
      node = parent
    else
      return node
    end
  end
end

--- Whether the cursor sits on a span captured as `config.capture`.
---@param ctx gutenberg.Context
---@param config gutenberg.span.Config
---@return boolean
function M.is(ctx, config)
  return ts.find_inline_at_cursor(ctx, config.capture) ~= nil
end

--- Locate the span at the cursor: resolve the outermost node, decode its
--- delimiter-stripped text, and return `(text, node)`. Errors when the
--- cursor is not on the construct.
---@param ctx gutenberg.Context
---@param config gutenberg.span.Config
---@return string text, TSNode node
function M.locate(ctx, config)
  local node = ts.find_inline_at_cursor(ctx, config.capture)
  if node == nil then
    error('gutenberg: cursor is not on ' .. config.noun, 0)
  end
  node = outermost(node, config.delimiter)

  ---@type gutenberg.span.Range[]
  local delims = {}
  collect_delimiters(node, node:type(), config.delimiter, delims)
  local sr, sc, er, ec = content_span(delims)
  local raw = ''
  if sr ~= nil then
    raw = table.concat(
      vim.api.nvim_buf_get_text(ctx.bufnr, sr, sc, er, ec, {}),
      '\n'
    )
  end
  return config.decode(raw), node
end

--- Replace `node`'s exact range with `text` in a single buffer update.
---@param node TSNode
---@param text string
---@param ctx gutenberg.Context
function M.splice(node, text, ctx)
  local sr, sc, er, ec = node:range()
  buffer.set_text(ctx.bufnr, sr, sc, er, ec, { text })
end

--- Validate that `ctx.range` is a single-line charwise selection suitable
--- for wrapping, returning it. Errors with UI-ready copy otherwise.
---@param ctx gutenberg.Context
---@param noun string
---@return gutenberg.Range
function M.wrap_range(ctx, noun)
  local range = ctx.range
  if range == nil or range.mode ~= 'char' then
    error(
      'gutenberg: wrapping ' .. noun .. ' requires a charwise selection',
      0
    )
  end
  if range.start[1] ~= range.stop[1] then
    error('gutenberg: cannot wrap ' .. noun .. ' across multiple lines', 0)
  end
  return range
end

--- Build the low-level api surface for a span construct: `is_<capture>`,
--- `read`, `create`, `render`, `replace`, and `get_text` / `set_text`. The
--- calling module casts the result to its own `gutenberg.api.<name>` class.
---@param config gutenberg.span.Config
---@return table
function M.new_api(config)
  local api = {}

  api['is_' .. config.capture] = function(ctx)
    return M.is(context.resolve(ctx), config)
  end

  ---@param ctx? gutenberg.Context.Partial
  ---@return gutenberg.span.Value, TSNode
  function api.read(ctx)
    ctx = context.resolve(ctx)
    local text, node = M.locate(ctx, config)
    return { text = text }, node
  end

  ---@param fields { text: string }
  ---@return gutenberg.span.Value
  function api.create(fields)
    return { text = fields.text }
  end

  ---@param value gutenberg.span.Value
  ---@return string
  function api.render(value)
    return config.render(value.text)
  end

  ---@param node TSNode
  ---@param values gutenberg.span.Value[]
  ---@param ctx? gutenberg.Context.Partial
  function api.replace(node, values, ctx)
    ctx = context.resolve(ctx)
    local parts = {}
    for _, value in ipairs(values) do
      parts[#parts + 1] = config.render(value.text)
    end
    M.splice(node, table.concat(parts, ''), ctx)
  end

  ---@param value gutenberg.span.Value
  ---@return string
  function api.get_text(value)
    return value.text
  end

  ---@param value gutenberg.span.Value
  ---@param text string
  function api.set_text(value, text)
    value.text = text
  end

  return api
end

--- Build the cursor-level verbs (`wrap` / `remove`) for a span construct
--- over its `api` module. The calling module casts the result to its own
--- `gutenberg.<name>` class.
---@param api gutenberg.span.Api
---@param noun string
---@return table
function M.new_verbs(api, noun)
  local verbs = {}

  ---@param ctx? gutenberg.Context.Partial
  ---@return gutenberg.span.Value written
  function verbs.wrap(ctx)
    ctx = context.resolve(ctx)
    local range = M.wrap_range(ctx, noun)
    local text = buffer.get_range(ctx.bufnr, range)[1] or ''
    local value = api.create({ text = text })
    buffer.set_range(ctx.bufnr, range, { api.render(value) })
    return value
  end

  ---@param ctx? gutenberg.Context.Partial
  ---@return string text
  function verbs.remove(ctx)
    ctx = context.resolve(ctx)
    local value, node = api.read(ctx)
    M.splice(node, value.text, ctx)
    return value.text
  end

  return verbs
end

return M
