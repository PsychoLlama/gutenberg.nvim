--- Cursor-level sugar over `gutenberg.api.table`. Every verb here
--- composes the low-level primitives (read → mutate → replace) and
--- errors with UI-ready messages, so keymap edges can `pcall` + notify
--- directly. Drop down to `require('gutenberg.api').table` for the
--- primitives themselves.

local api = require('gutenberg.api.table')
local context = require('gutenberg.context')

---@class gutenberg.table
local M = {}

--- Read the table at the cursor, apply `fn`, and write the result back
--- in a single buffer update. `fn` may mutate the table in place (and
--- return nothing) or return a replacement list — return `{}` to
--- delete the table. Errors if the cursor isn't on a pipe table.
---@param fn fun(tbl: gutenberg.table.Table): gutenberg.table.Table[]?
---@param ctx? gutenberg.Context.Partial
---@return gutenberg.table.Table[] written
function M.update(fn, ctx)
  ctx = context.resolve(ctx)
  local tbl, node = api.read(ctx)
  local tables = fn(tbl) or { tbl }
  api.replace(node, tables, ctx)
  return tables
end

--- Rewrite the table at the cursor in canonical form: cells padded to
--- the widest entry, pipes aligned, alignment markers normalized. A
--- read/replace round trip with no value changes. Errors if the cursor
--- isn't on a pipe table.
---@param ctx? gutenberg.Context.Partial
---@return gutenberg.table.Table[] written
function M.format(ctx)
  return M.update(function() end, ctx)
end

---@type table<gutenberg.table.Alignment, gutenberg.table.Alignment>
local NEXT_ALIGNMENT = {
  none = 'left',
  left = 'center',
  center = 'right',
  right = 'none',
}

--- Advance the alignment of the column under the cursor one step
--- through none → left → center → right → none, rewriting the table in
--- a single buffer update. Errors if the cursor isn't on a pipe table,
--- or when the cursor column has no delimiter cell.
---@param ctx? gutenberg.Context.Partial
---@return gutenberg.table.Table[] written
function M.cycle_alignment(ctx)
  ctx = context.resolve(ctx)
  local col = api.column_at(ctx)
  if col == nil then
    error('gutenberg: cursor is not on a pipe table', 0)
  end
  return M.update(function(tbl)
    api.set_alignment(tbl, col, NEXT_ALIGNMENT[api.get_alignment(tbl, col)])
  end, ctx)
end

return M
