---@class gutenberg.list.Item
---@field indent string Leading whitespace before the marker.
---@field marker string Bullet ("-", "*", "+") or ordered ("1.") marker.
---@field checkbox string? Checkbox value (typically " " or "x"). nil = no checkbox.
---@field text string Content after the marker (and checkbox, if present).

local buffer = require('gutenberg.buffer')
local context = require('gutenberg.context')
local ts = require('gutenberg.treesitter')

---@class gutenberg.list
local M = {}

--- Whether the cursor is on a list item. Gate calls to `read` with this.
---@param ctx? gutenberg.Context.Partial
---@return boolean
function M.is_list_item(ctx)
  return ts.find_at_cursor(context.resolve(ctx), 'list_item') ~= nil
end

---@type table<string, true>
local MARKER_TYPES = {
  list_marker_minus = true,
  list_marker_plus = true,
  list_marker_star = true,
  list_marker_dot = true,
  list_marker_parenthesis = true,
}

--- Decode a `list_item` node into an item struct. Errors if the node is
--- missing a marker.
---@param node TSNode
---@param bufnr integer
---@return gutenberg.list.Item
local function decode_item(node, bufnr)
  local marker_node = ts.child(node, MARKER_TYPES)
  if marker_node == nil then
    error('gutenberg: list_item is missing a marker', 0)
  end

  local sr = node:range()
  local line = vim.api.nvim_buf_get_lines(bufnr, sr, sr + 1, false)[1] or ''
  local _, msc, _, mec = marker_node:range()

  local indent = line:sub(1, msc)
  local marker = vim.trim(line:sub(msc + 1, mec))
  local rest = line:sub(mec + 1):gsub('^%s+', '')

  local checkbox, text = rest:match('^%[(.)%]%s*(.-)$')
  if checkbox == nil then
    text = rest
  end

  return {
    indent = indent,
    marker = marker,
    checkbox = checkbox,
    text = text,
  }
end

--- Walk up from the cursor's `list_item` to the enclosing `list` node, or
--- nil when the cursor isn't on a list item.
---@param ctx gutenberg.Context
---@return TSNode?
local function find_list(ctx)
  local item = ts.find_at_cursor(ctx, 'list_item')
  if item == nil then
    return nil
  end
  local parent = item:parent()
  if parent == nil or parent:type() ~= 'list' then
    return nil
  end
  return parent
end

--- Read the list item containing the cursor. Errors if the cursor isn't on
--- a list item; validate with `is_list_item` first. The returned `TSNode`
--- captures the item's range for `replace`.
---@param ctx? gutenberg.Context.Partial
---@return gutenberg.list.Item, TSNode
function M.read(ctx)
  ctx = context.resolve(ctx)
  local node = ts.find_at_cursor(ctx, 'list_item')
  if node == nil then
    error('gutenberg: cursor is not on a list item', 0)
  end
  return decode_item(node, ctx.bufnr), node
end

--- Construct a list item from explicit fields. Missing fields fall back to
--- the configured defaults (see `gutenberg.setup`).
---@param fields { indent?: string, marker?: string, checkbox?: string, text?: string }
---@return gutenberg.list.Item
function M.create(fields)
  local list = require('gutenberg.config').get().list
  return {
    indent = fields.indent or '',
    marker = fields.marker or list.marker,
    checkbox = fields.checkbox,
    text = fields.text or '',
  }
end

--- Render an item to a single line of buffer text.
---@param item gutenberg.list.Item
---@return string
function M.render(item)
  local parts = { item.indent, item.marker }
  if item.checkbox ~= nil then
    table.insert(parts, ' [' .. item.checkbox .. ']')
  end
  if item.text ~= '' then
    table.insert(parts, ' ' .. item.text)
  end
  return table.concat(parts)
end

--- Replace `node`'s range with the rendered items in a single buffer update.
--- Pass an empty `items` list to delete the node.
---@param node TSNode
---@param items gutenberg.list.Item[]
---@param ctx? gutenberg.Context.Partial
function M.replace(node, items, ctx)
  ctx = context.resolve(ctx)
  local sr = node:range()

  local lines = {}
  for _, item in ipairs(items) do
    table.insert(lines, M.render(item))
  end

  -- list_item ranges greedily include trailing blank lines and can extend
  -- past EOF on the last item. Items are single-line, so write only the
  -- marker's row — anything below sr is a nested child or whitespace we
  -- shouldn't touch.
  buffer.set_lines(ctx.bufnr, sr, sr + 1, lines)
end

--- Read every direct sibling of the cursor's list item. Returns the entries
--- in document order along with the parent `list` node (pass to
--- `replace_list`). Errors if the cursor isn't on a list item.
---@param ctx? gutenberg.Context.Partial
---@return { item: gutenberg.list.Item, node: TSNode }[], TSNode
function M.read_list(ctx)
  ctx = context.resolve(ctx)
  local list_node = find_list(ctx)
  if list_node == nil then
    error('gutenberg: cursor is not on a list item', 0)
  end

  ---@type { item: gutenberg.list.Item, node: TSNode }[]
  local entries = {}
  for child in list_node:iter_children() do
    if child:type() == 'list_item' then
      table.insert(
        entries,
        { item = decode_item(child, ctx.bufnr), node = child }
      )
    end
  end
  return entries, list_node
end

--- Rewrite the marker rows of `entries` in a single buffer update. Each
--- entry's `node` selects the row to overwrite; nested children below that
--- row are preserved verbatim. Use this to switch markers (e.g. ordered ↔
--- unordered) across siblings without disturbing their content.
---@param list_node TSNode The parent list returned by `read_list`.
---@param entries { item: gutenberg.list.Item, node: TSNode }[]
---@param ctx? gutenberg.Context.Partial
function M.replace_list(list_node, entries, ctx)
  ctx = context.resolve(ctx)
  local sr = list_node:range()
  local end_row = ts.end_row(list_node)
  local lines = vim.api.nvim_buf_get_lines(ctx.bufnr, sr, end_row, false)

  for _, entry in ipairs(entries) do
    local item_sr = entry.node:range()
    local idx = item_sr - sr + 1
    if idx < 1 or idx > #lines then
      error('gutenberg: entry node falls outside the list range', 0)
    end
    lines[idx] = M.render(entry.item)
  end

  buffer.set_lines(ctx.bufnr, sr, end_row, lines)
end

--- The last row owned by `node` (inclusive). list_item / list ranges can
--- extend past their content into trailing blanks; clamp to the last row
--- with non-whitespace text so we don't mangle unrelated rows.
---@param node TSNode
---@param bufnr integer
---@return integer sr, integer end_row
local function content_rows(node, bufnr)
  local sr = node:range()
  local lines = vim.api.nvim_buf_get_lines(bufnr, sr, ts.end_row(node), false)
  for i = #lines, 1, -1 do
    if lines[i]:match('%S') ~= nil then
      return sr, sr + i - 1
    end
  end
  return sr, sr
end

--- The indent unit used by `indent` / `dedent`. Honors a configured
--- `list.indent`; falls back to the buffer's `&expandtab` and
--- `&tabstop` so the result matches whatever indentation the buffer is
--- already using.
---@param bufnr integer
---@return string
local function resolve_indent(bufnr)
  local configured = require('gutenberg.config').get().list.indent
  if configured ~= nil then
    return configured
  end
  if not vim.bo[bufnr].expandtab then
    return '\t'
  end
  return string.rep(' ', vim.bo[bufnr].tabstop)
end

--- Shift the leading whitespace of `node`'s range right by one indent
--- unit (see `gutenberg.list.Config.indent`). Use to nest a list_item
--- under its previous sibling. Single buffer update; nested children
--- move with the parent.
---@param node TSNode A `list_item` node.
---@param ctx? gutenberg.Context.Partial
function M.indent(node, ctx)
  ctx = context.resolve(ctx)
  local indent = resolve_indent(ctx.bufnr)
  local sr, end_row = content_rows(node, ctx.bufnr)
  local lines = vim.api.nvim_buf_get_lines(ctx.bufnr, sr, end_row + 1, false)
  for i, line in ipairs(lines) do
    lines[i] = indent .. line
  end
  buffer.set_lines(ctx.bufnr, sr, end_row + 1, lines)
end

--- Shift the leading whitespace of `node`'s range left by one indent
--- unit (see `gutenberg.list.Config.indent`). Errors when any non-blank
--- line lacks the required leading whitespace. Single buffer update.
---@param node TSNode A `list_item` node.
---@param ctx? gutenberg.Context.Partial
function M.dedent(node, ctx)
  ctx = context.resolve(ctx)
  local indent = resolve_indent(ctx.bufnr)
  local sr, end_row = content_rows(node, ctx.bufnr)
  local lines = vim.api.nvim_buf_get_lines(ctx.bufnr, sr, end_row + 1, false)
  local strip = #indent
  for i, line in ipairs(lines) do
    if line:match('%S') ~= nil then
      local prefix = line:sub(1, strip)
      if #prefix < strip or prefix:match('^%s+$') == nil then
        error(
          'gutenberg: cannot dedent: line lacks '
            .. strip
            .. ' leading whitespace',
          0
        )
      end
      lines[i] = line:sub(strip + 1)
    end
  end
  buffer.set_lines(ctx.bufnr, sr, end_row + 1, lines)
end

--- Get the marker on an item.
---@param item gutenberg.list.Item
---@return string
function M.get_marker(item)
  return item.marker
end

--- Set the marker on an item.
---@param item gutenberg.list.Item
---@param marker string
function M.set_marker(item, marker)
  item.marker = marker
end

--- Whether the item carries an ordered marker (`1.`, `2)`, etc.) as
--- opposed to a bullet (`-`, `*`, `+`).
---@param item gutenberg.list.Item
---@return boolean
function M.is_ordered(item)
  return item.marker:match('^%d+[%.%)]$') ~= nil
end

--- Switch an item between ordered and unordered. The unordered marker
--- falls back to `gutenberg.list.Config.marker`; the ordered marker
--- defaults to `1.`. Callers wanting sequential numbering across a list
--- should follow up with `set_marker(item, n .. '.')` per entry and
--- write the result with `replace_list`.
---@param item gutenberg.list.Item
---@param ordered boolean
function M.set_ordered(item, ordered)
  if ordered then
    if not M.is_ordered(item) then
      item.marker = '1.'
    end
    return
  end
  if M.is_ordered(item) then
    item.marker = require('gutenberg.config').get().list.marker
  end
end

--- Get the checkbox state on an item, or nil if there is no checkbox.
---@param item gutenberg.list.Item
---@return string?
function M.get_checkbox(item)
  return item.checkbox
end

--- Set the raw checkbox value on an item. Pass nil to remove the checkbox.
---@param item gutenberg.list.Item
---@param state string?
function M.set_checkbox(item, state)
  item.checkbox = state
end

--- Boolean view over the checkbox state. Returns nil if there is no checkbox.
---@param item gutenberg.list.Item
---@return boolean?
function M.is_checked(item)
  if item.checkbox == nil then
    return nil
  end
  return item.checkbox == 'x' or item.checkbox == 'X'
end

--- Set the checked state, adding a checkbox if one isn't present.
---@param item gutenberg.list.Item
---@param checked boolean
function M.set_checked(item, checked)
  item.checkbox = checked and 'x' or ' '
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
  local item, node = M.read(ctx)
  local items = fn(item) or { item }
  M.replace(node, items, ctx)
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
  local entries, list_node = M.read_list(ctx)
  fn(entries)
  M.replace_list(list_node, entries, ctx)
  return entries
end

--- Toggle the checkbox on the item at the cursor. Items without a
--- checkbox gain one in the configured state
--- (`gutenberg.list.Config.default_checked`); items with one flip.
--- Errors if the cursor isn't on a list item.
---@param ctx? gutenberg.Context.Partial
---@return gutenberg.list.Item[] written
function M.toggle_checkbox(ctx)
  return M.update(function(item)
    local checked = M.is_checked(item)
    if checked == nil then
      local config = require('gutenberg.config').get().list
      M.set_checked(item, config.default_checked)
    else
      M.set_checked(item, not checked)
    end
  end, ctx)
end

--- Switch the item at the cursor between ordered and unordered (see
--- `set_ordered`). Errors if the cursor isn't on a list item.
---@param ctx? gutenberg.Context.Partial
---@return gutenberg.list.Item[] written
function M.toggle_ordered(ctx)
  return M.update(function(item)
    M.set_ordered(item, not M.is_ordered(item))
  end, ctx)
end

--- Switch the cursor item and all of its direct siblings between
--- ordered and unordered, renumbering from 1 when switching to
--- ordered. The direction comes from the first sibling. Errors if the
--- cursor isn't on a list item.
---@param ctx? gutenberg.Context.Partial
---@return { item: gutenberg.list.Item, node: TSNode }[] entries
function M.toggle_ordered_list(ctx)
  return M.update_list(function(entries)
    local ordered = not M.is_ordered(entries[1].item)
    for i, entry in ipairs(entries) do
      M.set_ordered(entry.item, ordered)
      if ordered then
        M.set_marker(entry.item, i .. '.')
      end
    end
  end, ctx)
end

return M
