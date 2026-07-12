--- Cursor-level sugar over `gutenberg.api.list`. Every verb here
--- composes the low-level primitives (read → mutate → replace) and
--- errors with UI-ready messages, so keymap edges can `pcall` + notify
--- directly. Drop down to `require('gutenberg.api').list` for the
--- primitives themselves.

local api = require('gutenberg.api.list')
local buffer = require('gutenberg.buffer')
local context = require('gutenberg.context')
local ts = require('gutenberg.treesitter')

---@class gutenberg.list
local M = {}

--- The list items a bulk verb operates on: every item whose marker row
--- starts inside `ctx.range` when a range is given, otherwise the
--- cursor item plus the next `ctx.count - 1` items in document order.
--- Errors when nothing is targeted.
---@param ctx gutenberg.Context
---@return { item: gutenberg.list.Item, node: TSNode }[]
local function targets(ctx)
  local entries = api.items(ctx)

  if ctx.range ~= nil then
    local start_row = ctx.range.start[1] - 1
    local stop_row = ctx.range.stop[1] - 1
    ---@type { item: gutenberg.list.Item, node: TSNode }[]
    local results = {}
    for _, entry in ipairs(entries) do
      local sr = entry.node:range()
      if sr >= start_row and sr <= stop_row then
        table.insert(results, entry)
      end
    end
    if #results == 0 then
      error('gutenberg: no list item in the selected range', 0)
    end
    return results
  end

  local _, cursor_node = api.read(ctx)
  ---@type integer?
  local start_index
  for i, entry in ipairs(entries) do
    if entry.node:equal(cursor_node) then
      start_index = i
      break
    end
  end
  if start_index == nil then
    error('gutenberg: cursor is not on a list item', 0)
  end

  ---@type { item: gutenberg.list.Item, node: TSNode }[]
  local results = {}
  for i = start_index, math.min(start_index + ctx.count - 1, #entries) do
    table.insert(results, entries[i])
  end
  return results
end

--- Rewrite the marker rows of `entries` in one buffer update.
---@param bufnr integer
---@param entries { item: gutenberg.list.Item, node: TSNode }[]
local function write_targets(bufnr, entries)
  ---@type table<integer, string>
  local edits = {}
  for _, entry in ipairs(entries) do
    edits[(entry.node:range())] = api.render(entry.item)
  end
  buffer.set_rows(bufnr, edits)
end

--- Read the item at the cursor, apply `fn`, and write the result back
--- in a single buffer update. `fn` may mutate the item in place (and
--- return nothing) or return a replacement list — return `{}` to
--- delete the item. Errors if the cursor isn't on a list item.
---@param fn fun(item: gutenberg.list.Item): gutenberg.list.Item[]?
---@param ctx? gutenberg.Context.Partial
---@return gutenberg.list.Item[] written
function M.update(fn, ctx)
  ctx = context.resolve(ctx)
  local item, node = api.read(ctx)
  local items = fn(item) or { item }
  api.replace(node, items, ctx)
  return items
end

--- Read the cursor item's direct siblings, apply `fn` to the entries,
--- and rewrite their marker rows in a single buffer update. `fn`
--- mutates each entry's `item` in place; the entry nodes select the
--- rows to rewrite, so entries cannot be added or removed here. Errors
--- if the cursor isn't on a list item.
---@param fn fun(entries: { item: gutenberg.list.Item, node: TSNode }[])
---@param ctx? gutenberg.Context.Partial
---@return { item: gutenberg.list.Item, node: TSNode }[] entries
function M.update_list(fn, ctx)
  ctx = context.resolve(ctx)
  local entries, list_node = api.read_list(ctx)
  fn(entries)
  api.replace_list(list_node, entries, ctx)
  return entries
end

--- The last content row owned by `node` (inclusive): list_item and
--- list ranges greedily extend into trailing blanks, so clamp to the
--- last row holding text.
---@param node TSNode
---@param bufnr integer
---@return integer
local function content_end(node, bufnr)
  local sr = node:range()
  local rows = vim.api.nvim_buf_get_lines(bufnr, sr, ts.end_row(node), false)
  for i = #rows, 1, -1 do
    if rows[i]:match('%S') ~= nil then
      return sr + i - 1
    end
  end
  return sr
end

--- The outermost `list` node enclosing `node` — the span every group
--- affected by an indent shift lives inside.
---@param node TSNode A `list_item` node.
---@return TSNode
local function outer_list(node)
  local result = node:parent()
  local cursor = result
  while cursor ~= nil do
    if cursor:type() == 'list' then
      result = cursor
    end
    cursor = cursor:parent()
  end
  assert(result ~= nil, 'list_item has no parent list')
  return result
end

--- The list_item nodes an indent shift moves: every selected item
--- whose parent item isn't also selected when a range is given (nested
--- children travel with their parent), otherwise the cursor item.
---@param ctx gutenberg.Context
---@return TSNode[]
local function shift_targets(ctx)
  if ctx.range == nil then
    local _, node = api.read(ctx)
    return { node }
  end

  local start_row = ctx.range.start[1] - 1
  local stop_row = ctx.range.stop[1] - 1
  ---@param node TSNode
  ---@return boolean
  local function selected(node)
    local sr = node:range()
    return sr >= start_row and sr <= stop_row
  end

  ---@type TSNode[]
  local results = {}
  for _, entry in ipairs(api.items(ctx)) do
    if selected(entry.node) then
      local ancestor_selected = false
      local cursor = entry.node:parent()
      while cursor ~= nil do
        if cursor:type() == 'list_item' and selected(cursor) then
          ancestor_selected = true
          break
        end
        cursor = cursor:parent()
      end
      if not ancestor_selected then
        table.insert(results, entry.node)
      end
    end
  end
  if #results == 0 then
    error('gutenberg: no list item in the selected range', 0)
  end
  return results
end

--- Renumber every ordered sibling group `lines` would parse into, in
--- place. The candidate text is reparsed standalone, so the groups
--- reflect the tree the pending write produces — not the stale one in
--- the buffer.
---@param lines string[]
local function renumber_lines(lines)
  local nodes, source = ts.collect_in_lines(lines, 'list_item')

  ---@type string[]
  local order = {}
  ---@type table<string, TSNode[]>
  local groups = {}
  for _, node in ipairs(nodes) do
    local parent = node:parent()
    local key = parent ~= nil and parent:id() or 'root'
    if groups[key] == nil then
      groups[key] = {}
      table.insert(order, key)
    end
    table.insert(groups[key], node)
  end

  for _, key in ipairs(order) do
    ---@type { row: integer, sc: integer, ec: integer, text: string, item: gutenberg.list.Item }[]
    local markers = {}
    ---@type gutenberg.list.Item[]
    local items = {}
    for _, node in ipairs(groups[key]) do
      ---@type TSNode?
      local marker
      for child in node:iter_children() do
        if child:type():match('^list_marker') ~= nil then
          marker = child
          break
        end
      end
      if marker ~= nil then
        local sr, sc, _, ec = marker:range()
        local text = vim.treesitter.get_node_text(marker, source)
        local entry = {
          row = sr,
          sc = sc,
          ec = ec,
          text = text,
          item = api.create({ marker = vim.trim(text) }),
        }
        table.insert(markers, entry)
        table.insert(items, entry.item)
      end
    end

    api.renumber(items)
    for _, entry in ipairs(markers) do
      -- Marker nodes can swallow surrounding whitespace (a top-level
      -- item's ≤3-column indent, the space before the content) —
      -- rebuild it around the renumbered marker.
      local renumbered = entry.text:match('^%s*')
        .. entry.item.marker
        .. entry.text:match('%s*$')
      if renumbered ~= entry.text then
        local line = lines[entry.row + 1]
        lines[entry.row + 1] = line:sub(1, entry.sc)
          .. renumbered
          .. line:sub(entry.ec + 1)
      end
    end
  end
end

--- Shift the targeted items `direction * ctx.count` indent units and
--- renumber every ordered sibling group in the affected lists, all in
--- one buffer update.
---@param direction 1 | -1
---@param ctx? gutenberg.Context.Partial
local function shift(direction, ctx)
  ctx = context.resolve(ctx)
  local nodes = shift_targets(ctx)
  local unit = api.indent_unit(ctx.bufnr):rep(ctx.count)

  ---@type integer?, integer?
  local span_start, span_stop
  for _, node in ipairs(nodes) do
    local list_node = outer_list(node)
    local sr = list_node:range()
    local stop = content_end(list_node, ctx.bufnr)
    span_start = math.min(span_start or sr, sr)
    span_stop = math.max(span_stop or stop, stop)
  end
  assert(span_start ~= nil and span_stop ~= nil)

  local lines =
    vim.api.nvim_buf_get_lines(ctx.bufnr, span_start, span_stop + 1, false)

  for _, node in ipairs(nodes) do
    local sr = node:range()
    for row = sr, content_end(node, ctx.bufnr) do
      local index = row - span_start + 1
      local line = lines[index]
      if direction == 1 then
        lines[index] = unit .. line
      elseif line:match('%S') ~= nil then
        local strip = #unit
        local lead = line:sub(1, strip)
        if #lead < strip or lead:match('^%s+$') == nil then
          error(
            'gutenberg: cannot dedent: line lacks '
              .. strip
              .. ' leading whitespace',
            0
          )
        end
        lines[index] = line:sub(strip + 1)
      end
    end
  end

  renumber_lines(lines)
  buffer.set_lines(ctx.bufnr, span_start, span_stop + 1, lines)
end

--- Indent the item at the cursor `ctx.count` units (see
--- `gutenberg.list.Config.indent`), nesting it under its previous
--- sibling. Nested children move with the item, and every ordered
--- sibling group in the affected list is renumbered — the item's old
--- siblings close the gap it left, its new siblings count it in. One
--- buffer update.
---
--- With `ctx.range`, indents each selected item whose parent item
--- isn't also selected (children travel with their parent). Errors if
--- the cursor isn't on a list item (or the range holds none).
---@param ctx? gutenberg.Context.Partial
function M.indent(ctx)
  shift(1, ctx)
end

--- Dedent the item at the cursor `ctx.count` units (see
--- `gutenberg.list.Config.indent`), moving it out to its parent's
--- level. Nested children move with the item, and every ordered
--- sibling group in the affected list is renumbered. One buffer
--- update. Errors when any affected line lacks the leading whitespace
--- to strip.
---
--- With `ctx.range`, dedents each selected item whose parent item
--- isn't also selected (children travel with their parent). Errors if
--- the cursor isn't on a list item (or the range holds none).
---@param ctx? gutenberg.Context.Partial
function M.dedent(ctx)
  shift(-1, ctx)
end

--- Toggle the checkbox on the item at the cursor. Items without a
--- checkbox gain one in the configured state
--- (`gutenberg.list.Config.default_checked`); items with one flip.
---
--- With `ctx.count > 1` or `ctx.range`, operates on the targeted items
--- (see above) as a group in one buffer update: if any target is
--- unchecked or missing its checkbox, all become checked; otherwise
--- all become unchecked. Errors if the cursor isn't on a list item (or
--- the range holds none).
---@param ctx? gutenberg.Context.Partial
---@return gutenberg.list.Item[] written
function M.toggle_checkbox(ctx)
  ctx = context.resolve(ctx)
  if ctx.range == nil and ctx.count == 1 then
    return M.update(function(item)
      local checked = api.is_checked(item)
      if checked == nil then
        local config = require('gutenberg.config').get().list
        api.set_checked(item, config.default_checked)
      else
        api.set_checked(item, not checked)
      end
    end, ctx)
  end

  local entries = targets(ctx)
  local all_checked = true
  for _, entry in ipairs(entries) do
    if api.is_checked(entry.item) ~= true then
      all_checked = false
      break
    end
  end

  ---@type gutenberg.list.Item[]
  local written = {}
  for _, entry in ipairs(entries) do
    api.set_checked(entry.item, not all_checked)
    table.insert(written, entry.item)
  end
  write_targets(ctx.bufnr, entries)
  return written
end

--- Switch the item at the cursor between ordered and unordered (see
--- `gutenberg.api.list.set_ordered`).
---
--- With `ctx.count > 1` or `ctx.range`, switches the targeted items
--- (see above) in one buffer update: the direction comes from the
--- first target, and items switched to ordered are renumbered from 1.
--- Errors if the cursor isn't on a list item (or the range holds
--- none).
---@param ctx? gutenberg.Context.Partial
---@return gutenberg.list.Item[] written
function M.toggle_ordered(ctx)
  ctx = context.resolve(ctx)
  if ctx.range == nil and ctx.count == 1 then
    return M.update(function(item)
      api.set_ordered(item, not api.is_ordered(item))
    end, ctx)
  end

  local entries = targets(ctx)
  local ordered = not api.is_ordered(entries[1].item)
  ---@type gutenberg.list.Item[]
  local written = {}
  for _, entry in ipairs(entries) do
    api.set_ordered(entry.item, ordered)
    table.insert(written, entry.item)
  end
  if ordered then
    api.renumber(written)
  end
  write_targets(ctx.bufnr, entries)
  return written
end

--- Switch the cursor item and all of its direct siblings between
--- ordered and unordered, renumbering from 1 when switching to
--- ordered. The direction comes from the first sibling. Errors if the
--- cursor isn't on a list item.
---@param ctx? gutenberg.Context.Partial
---@return { item: gutenberg.list.Item, node: TSNode }[] entries
function M.toggle_ordered_list(ctx)
  return M.update_list(function(entries)
    local ordered = not api.is_ordered(entries[1].item)
    ---@type gutenberg.list.Item[]
    local items = {}
    for _, entry in ipairs(entries) do
      api.set_ordered(entry.item, ordered)
      table.insert(items, entry.item)
    end
    if ordered then
      api.renumber(items)
    end
  end, ctx)
end

return M
