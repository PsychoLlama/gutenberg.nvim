--- Cursor-level sugar over `gutenberg.api.list`. Every verb here
--- composes the low-level primitives (read → mutate → replace) and
--- errors with UI-ready messages, so keymap edges can `pcall` + notify
--- directly. Drop down to `require('gutenberg.api').list` for the
--- primitives themselves.

local api = require('gutenberg.api.list')
local context = require('gutenberg.context')

---@class gutenberg.list
local M = {}

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
--- Errors if the cursor isn't on a list item.
---@param ctx? gutenberg.Context.Partial
---@return gutenberg.list.Item[] written
function M.toggle_checkbox(ctx)
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

--- Switch the item at the cursor between ordered and unordered (see
--- `gutenberg.api.list.set_ordered`). Errors if the cursor isn't on a
--- list item.
---@param ctx? gutenberg.Context.Partial
---@return gutenberg.list.Item[] written
function M.toggle_ordered(ctx)
  return M.update(function(item)
    api.set_ordered(item, not api.is_ordered(item))
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
