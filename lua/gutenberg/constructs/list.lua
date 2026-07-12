--- Cursor-level sugar over `gutenberg.api.list`. Every verb here
--- composes the low-level primitives (read → mutate → replace) and
--- errors with UI-ready messages, so keymap edges can `pcall` + notify
--- directly. Drop down to `require('gutenberg.api').list` for the
--- primitives themselves.

local api = require('gutenberg.api.list')
local buffer = require('gutenberg.buffer')
local context = require('gutenberg.context')

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
