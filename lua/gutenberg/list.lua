---@class gutenberg.list.Item
---@field indent string Leading whitespace before the marker.
---@field marker string Bullet ("-", "*", "+") or ordered ("1.") marker.
---@field checkbox string? Checkbox value (typically " " or "x"). nil = no checkbox.
---@field text string Content after the marker (and checkbox, if present).

local M = {}

--- Whether the cursor is on a list item. Gate calls to `read` with this.
---@param _ctx? gutenberg.Context.Partial
---@return boolean
function M.is_list_item(_ctx)
  error('not implemented')
end

--- Read the list item containing the cursor. Errors if the cursor isn't on
--- a list item; validate with `is_list_item` first. The returned `TSNode`
--- captures the item's range for `replace`.
---@param _ctx? gutenberg.Context.Partial
---@return gutenberg.list.Item, TSNode
function M.read(_ctx)
  error('not implemented')
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
---@param _item gutenberg.list.Item
---@return string
function M.render(_item)
  error('not implemented')
end

--- Replace `node`'s range with the rendered items in a single buffer update.
--- Pass an empty `items` list to delete the node.
---@param _node TSNode
---@param _items gutenberg.list.Item[]
---@param _ctx? gutenberg.Context.Partial
function M.replace(_node, _items, _ctx)
  error('not implemented')
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

return M
