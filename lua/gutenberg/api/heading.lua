---@class gutenberg.heading.Heading
---@field level integer Heading depth, 1..6.
---@field text string Heading content after the `#` markers.

local buffer = require('gutenberg.buffer')
local context = require('gutenberg.context')
local ts = require('gutenberg.treesitter')

---@class gutenberg.api.heading
local M = {}

---@param node TSNode
---@return integer?
local function marker_level(node)
  local digit = node:type():match('^atx_h(%d)_marker$')
  if digit == nil then
    return nil
  end
  return tonumber(digit)
end

--- Decode an `atx_heading` node, or nil if the node is malformed.
---@param node TSNode
---@param bufnr integer
---@return gutenberg.heading.Heading?
local function decode(node, bufnr)
  if node:type() ~= 'atx_heading' then
    return nil
  end

  local level
  local inline_node
  for child in node:iter_children() do
    local lvl = marker_level(child)
    if lvl ~= nil then
      level = lvl
    elseif child:type() == 'inline' then
      inline_node = child
    end
  end

  if level == nil then
    return nil
  end

  local text = ''
  if inline_node ~= nil then
    text = vim.treesitter.get_node_text(inline_node, bufnr)
  end

  return { level = level, text = text }
end

--- Whether the cursor is on an ATX heading. Gate calls to `read` with this.
---@param ctx? gutenberg.Context.Partial
---@return boolean
function M.is_heading(ctx)
  return ts.find_at_cursor(context.resolve(ctx), 'heading') ~= nil
end

--- Read the heading containing the cursor. Errors if the cursor isn't on an
--- ATX heading; validate with `is_heading` first. The returned `TSNode`
--- captures the heading's range for `replace`.
---@param ctx? gutenberg.Context.Partial
---@return gutenberg.heading.Heading, TSNode
function M.read(ctx)
  ctx = context.resolve(ctx)
  local node = ts.find_at_cursor(ctx, 'heading')
  if node == nil then
    error('gutenberg: cursor is not on a heading', 0)
  end

  local heading = decode(node, ctx.bufnr)
  if heading == nil then
    error('gutenberg: atx_heading is missing a level marker', 0)
  end

  return heading, node
end

--- Construct a heading from explicit fields. Missing fields fall back to the
--- configured defaults (see `gutenberg.setup`).
---@param fields { level?: integer, text?: string }
---@return gutenberg.heading.Heading
function M.create(fields)
  local cfg = require('gutenberg.config').get().heading
  local heading =
    { level = fields.level or cfg.level, text = fields.text or '' }
  M.set_level(heading, heading.level)
  return heading
end

--- Render a heading to a single line of buffer text.
---@param heading gutenberg.heading.Heading
---@return string
function M.render(heading)
  local hashes = string.rep('#', heading.level)
  if heading.text == '' then
    return hashes
  end
  return hashes .. ' ' .. heading.text
end

--- Replace `node`'s range with the rendered headings in a single buffer
--- update. Pass an empty `headings` list to delete the node.
---@param node TSNode
---@param headings gutenberg.heading.Heading[]
---@param ctx? gutenberg.Context.Partial
function M.replace(node, headings, ctx)
  ctx = context.resolve(ctx)
  local sr = node:range()
  local prefix = ts.container_prefix(node, ctx.bufnr)

  ---@type string[]
  local lines = {}
  for _, heading in ipairs(headings) do
    table.insert(lines, prefix .. M.render(heading))
  end

  -- atx_heading ranges include the trailing newline (er = sr + 1), so the
  -- only buffer row owned by the heading is sr.
  buffer.set_lines(ctx.bufnr, sr, sr + 1, lines)
end

--- Get the level of a heading.
---@param heading gutenberg.heading.Heading
---@return integer
function M.get_level(heading)
  return heading.level
end

--- Set the level of a heading. Errors if `level` is outside 1..6.
---@param heading gutenberg.heading.Heading
---@param level integer
function M.set_level(heading, level)
  if level < 1 or level > 6 or level ~= math.floor(level) then
    error(
      'gutenberg: heading level must be an integer in 1..6, got '
        .. tostring(level),
      0
    )
  end
  heading.level = level
end

--- Get the text of a heading.
---@param heading gutenberg.heading.Heading
---@return string
function M.get_text(heading)
  return heading.text
end

--- Set the text of a heading.
---@param heading gutenberg.heading.Heading
---@param text string
function M.set_text(heading, text)
  heading.text = text
end

--- All ATX headings in the buffer, in document order.
---@param ctx? gutenberg.Context.Partial
---@return { heading: gutenberg.heading.Heading, node: TSNode }[]
function M.list(ctx)
  ctx = context.resolve(ctx)
  ---@type { heading: gutenberg.heading.Heading, node: TSNode }[]
  local results = {}
  for _, node in ipairs(ts.collect(ctx.bufnr, 'heading')) do
    local heading = decode(node, ctx.bufnr)
    if heading ~= nil then
      table.insert(results, { heading = heading, node = node })
    end
  end
  return results
end

---@param level integer
---@param opts? { min_level?: integer, max_level?: integer }
---@return boolean
local function level_in_range(level, opts)
  opts = opts or {}
  if opts.min_level ~= nil and level < opts.min_level then
    return false
  end
  if opts.max_level ~= nil and level > opts.max_level then
    return false
  end
  return true
end

--- Nearest heading strictly after the cursor row, optionally filtered by
--- level. Returns nil when no heading qualifies.
---@param ctx? gutenberg.Context.Partial
---@param opts? { min_level?: integer, max_level?: integer }
---@return gutenberg.heading.Heading?, TSNode?
function M.find_next(ctx, opts)
  ctx = context.resolve(ctx)
  local row = ctx.cursor[1] - 1
  for _, entry in ipairs(M.list(ctx)) do
    local sr = entry.node:range()
    if sr > row and level_in_range(entry.heading.level, opts) then
      return entry.heading, entry.node
    end
  end
  return nil, nil
end

--- Nearest heading strictly before the cursor row, optionally filtered by
--- level. Returns nil when no heading qualifies.
---@param ctx? gutenberg.Context.Partial
---@param opts? { min_level?: integer, max_level?: integer }
---@return gutenberg.heading.Heading?, TSNode?
function M.find_prev(ctx, opts)
  ctx = context.resolve(ctx)
  local row = ctx.cursor[1] - 1
  ---@type gutenberg.heading.Heading?
  local match_heading
  ---@type TSNode?
  local match_node
  for _, entry in ipairs(M.list(ctx)) do
    local sr = entry.node:range()
    if sr < row and level_in_range(entry.heading.level, opts) then
      match_heading = entry.heading
      match_node = entry.node
    elseif sr >= row then
      break
    end
  end
  return match_heading, match_node
end

--- The heading governing the cursor's section. When the cursor is on a
--- heading, returns the closest preceding heading with strictly smaller
--- level (i.e. the parent of the cursor's heading). Returns nil if no
--- ancestor heading exists.
---@param ctx? gutenberg.Context.Partial
---@return gutenberg.heading.Heading?, TSNode?
function M.find_parent(ctx)
  ctx = context.resolve(ctx)
  local row = ctx.cursor[1] - 1
  local entries = M.list(ctx)

  ---@type integer?
  local cursor_level
  for _, entry in ipairs(entries) do
    local sr = entry.node:range()
    if sr == row then
      cursor_level = entry.heading.level
      break
    end
  end

  ---@type gutenberg.heading.Heading?
  local match_heading
  ---@type TSNode?
  local match_node
  for _, entry in ipairs(entries) do
    local sr = entry.node:range()
    if sr >= row then
      break
    end
    if cursor_level == nil or entry.heading.level < cursor_level then
      match_heading = entry.heading
      match_node = entry.node
    end
  end
  return match_heading, match_node
end

return M
