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
  local entries = api.read_list(ctx)
  fn(entries)
  api.replace_items(entries, ctx)
  return entries
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

--- The column where the content of `node`'s previous sibling starts —
--- the indentation a nested child must reach (CommonMark) — or nil
--- when there is no previous sibling to nest under.
---@param node TSNode A `list_item` node.
---@param bufnr integer
---@return integer?
local function nesting_col(node, bufnr)
  local prev = node:prev_named_sibling()
  if prev == nil or prev:type() ~= 'list_item' then
    return nil
  end

  ---@type TSNode?
  local marker
  for child in prev:iter_children() do
    if child:type():match('^list_marker') ~= nil then
      marker = child
      break
    end
  end
  if marker == nil then
    return nil
  end

  -- The marker node usually swallows the space before the content, but
  -- extend past any that survives so wide separators still count.
  local msr, _, _, mec = marker:range()
  local line = vim.api.nvim_buf_get_lines(bufnr, msr, msr + 1, false)[1] or ''
  return mec + #line:sub(mec + 1):match('^%s*')
end

--- The whitespace `indent` prepends to `node`'s lines: at least
--- `ctx.count` indent units, widened to reach the previous sibling's
--- content column so the item actually nests — a 2-space unit alone
--- would leave `3.` a sibling of `2.`. Tab units already span a
--- 4-column tab stop, wider than any common marker, and stay literal
--- tabs.
---@param node TSNode A `list_item` node.
---@param ctx gutenberg.Context
---@return string
local function indent_prefix(node, ctx)
  local unit = api.indent_unit(ctx.bufnr)
  if unit:find('\t') ~= nil then
    return unit:rep(ctx.count)
  end
  local _, sc = node:range()
  local target = nesting_col(node, ctx.bufnr)
  local needed = target ~= nil and target - sc or 0
  return (' '):rep(math.max(#unit * ctx.count, needed))
end

--- How much leading whitespace `dedent` strips from `node`'s lines:
--- the distance down to the `count`-th enclosing item's column,
--- clamped at the outermost. Errors when the item isn't nested —
--- there is no parent level to move out to.
---@param node TSNode A `list_item` node.
---@param count integer
---@return integer
local function dedent_strip(node, count)
  ---@type integer[]
  local cols = {}
  local ancestor = node:parent()
  while ancestor ~= nil do
    if ancestor:type() == 'list_item' then
      local _, sc = ancestor:range()
      table.insert(cols, sc)
    end
    ancestor = ancestor:parent()
  end
  if #cols == 0 then
    error('gutenberg: cannot dedent: item is already top-level', 0)
  end

  local _, sc = node:range()
  return sc - cols[math.min(count, #cols)]
end

--- Shift the targeted items along the nesting axis — indent nests each
--- under its previous sibling, dedent lifts each out to an enclosing
--- item's level — and renumber every ordered sibling group in the
--- affected lists, all in one buffer update.
---@param direction 1 | -1
---@param ctx? gutenberg.Context.Partial
local function shift(direction, ctx)
  ctx = context.resolve(ctx)
  local nodes = shift_targets(ctx)

  -- Nesting is defined only relative to a previous sibling. An item
  -- with none can't become anyone's child; indenting it anyway just
  -- piles on whitespace that stops parsing as a list once it reaches
  -- four columns (an indented code block), stranding it. Refuse before
  -- writing, mirroring dedent's top-level guard, so indent/dedent stay
  -- reversible and derive purely from the current tree.
  if direction == 1 then
    for _, node in ipairs(nodes) do
      local prev = node:prev_named_sibling()
      if prev == nil or prev:type() ~= 'list_item' then
        error(
          'gutenberg: cannot indent: item has no previous sibling to nest under',
          0
        )
      end
    end
  end

  ---@type integer?, integer?
  local span_start, span_stop
  for _, node in ipairs(nodes) do
    local list_node = outer_list(node)
    local sr = list_node:range()
    local stop = ts.content_end(list_node, ctx.bufnr)
    span_start = math.min(span_start or sr, sr)
    span_stop = math.max(span_stop or stop, stop)
  end
  assert(span_start ~= nil and span_stop ~= nil)

  local lines =
    vim.api.nvim_buf_get_lines(ctx.bufnr, span_start, span_stop + 1, false)

  for _, node in ipairs(nodes) do
    local prefix = direction == 1 and indent_prefix(node, ctx) or ''
    local strip = direction == -1 and dedent_strip(node, ctx.count) or 0
    local sr = node:range()
    for row = sr, ts.content_end(node, ctx.bufnr) do
      local index = row - span_start + 1
      local line = lines[index]
      if direction == 1 then
        lines[index] = prefix .. line
      elseif line:match('%S') ~= nil then
        local lead = line:sub(1, strip)
        if #lead < strip or lead:match('^%s*$') == nil then
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

--- Indent the item at the cursor, nesting it under its previous
--- sibling: the shift is at least `ctx.count` indent units (see
--- `gutenberg.list.Config.indent`) and widens to reach the sibling's
--- content column, so the item actually nests no matter how narrow
--- the unit. Nested children move with the item, and every ordered
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

--- Dedent the item at the cursor, lifting it out to its enclosing
--- item's level — the `ctx.count`-th enclosing item's, clamped at the
--- outermost. The strip is derived from the tree, not a fixed unit,
--- so the item lands exactly on its parent's column. Nested children
--- move with the item, and every ordered sibling group in the
--- affected list is renumbered. One buffer update. Errors before
--- writing when the item is already top-level, or when any affected
--- line lacks the leading whitespace to strip.
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
--- With `ctx.range`, toggles every item in the range as a group in one
--- buffer update: if any target is unchecked or missing its checkbox,
--- all become checked; otherwise all become unchecked. Counts are
--- ignored — "toggle 3 checkboxes" has no coherent meaning, so bulk
--- toggles come from ranges. Errors if the cursor isn't on a list item
--- (or the range holds none).
---@param ctx? gutenberg.Context.Partial
---@return gutenberg.list.Item[] written
function M.toggle_checkbox(ctx)
  ctx = context.resolve(ctx)
  if ctx.range == nil then
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
  api.replace_items(entries, ctx)
  return written
end

--- Remove the checkbox from the item at the cursor, turning a task
--- item back into a plain list item. Items without a checkbox are left
--- untouched.
---
--- With `ctx.range`, strips the checkbox from every targeted item in
--- one buffer update. Errors if the cursor isn't on a list item (or the
--- range holds none).
---@param ctx? gutenberg.Context.Partial
---@return gutenberg.list.Item[] written
function M.remove_checkbox(ctx)
  ctx = context.resolve(ctx)
  if ctx.range == nil then
    return M.update(function(item)
      api.set_checkbox(item, nil)
    end, ctx)
  end

  local entries = targets(ctx)
  ---@type gutenberg.list.Item[]
  local written = {}
  for _, entry in ipairs(entries) do
    api.set_checkbox(entry.item, nil)
    table.insert(written, entry.item)
  end
  api.replace_items(entries, ctx)
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
  api.replace_items(entries, ctx)
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

--- Insert a blank sibling next to the item at the cursor, cloning its
--- indent and marker (and an unchecked checkbox when the cursor item
--- carries one), then renumber every ordered sibling group in the
--- affected list so the new item counts in and the ones after it shift
--- up. `opts.where` places the new item `'below'` the cursor item —
--- past its nested children — or `'above'` it; defaults to `'below'`.
--- One buffer update.
---
--- Unlike most codemods this moves the current window's cursor onto the
--- new item's line — its rendered marker carries a trailing space, so a
--- following `startinsert!` lands ready for text entry. Errors if the
--- cursor isn't on a list item.
---@param opts? { where?: 'above' | 'below' }
---@param ctx? gutenberg.Context.Partial
---@return gutenberg.list.Item inserted
function M.insert_item(opts, ctx)
  opts = opts or {}
  local where = opts.where or 'below'
  if where ~= 'above' and where ~= 'below' then
    error("gutenberg: insert_item 'where' must be 'above' or 'below'", 0)
  end
  ctx = context.resolve(ctx)

  local item, node = api.read(ctx)
  local inserted = api.create({
    indent = item.indent,
    marker = item.marker,
    checkbox = item.checkbox ~= nil and ' ' or nil,
  })

  -- Renumber over the whole enclosing list, exactly as a shift does:
  -- splice the fresh marker row into the list's line span, then let
  -- renumber_lines reparse and re-sequence every ordered group. Empty
  -- ordered items still parse as list_items, so the new one counts.
  local list_node = outer_list(node)
  local span_start = list_node:range()
  local span_stop = ts.content_end(list_node, ctx.bufnr)
  local lines =
    vim.api.nvim_buf_get_lines(ctx.bufnr, span_start, span_stop + 1, false)

  ---@type integer
  local insert_row
  if where == 'below' then
    insert_row = ts.content_end(node, ctx.bufnr) + 1
  else
    insert_row = (node:range())
  end
  -- A trailing space separates the marker from whatever the caller
  -- types next; renumber_lines preserves everything past the marker.
  table.insert(
    lines,
    insert_row - span_start + 1,
    api.render(inserted) .. ' '
  )

  renumber_lines(lines)
  buffer.set_lines(ctx.bufnr, span_start, span_stop + 1, lines)

  if vim.api.nvim_win_get_buf(0) == ctx.bufnr then
    local line = vim.api.nvim_buf_get_lines(
      ctx.bufnr,
      insert_row,
      insert_row + 1,
      false
    )[1] or ''
    vim.api.nvim_win_set_cursor(0, { insert_row + 1, #line })
  end

  return inserted
end

return M
