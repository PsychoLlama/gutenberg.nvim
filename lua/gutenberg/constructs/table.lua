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

---@type gutenberg.table.Alignment[]
local ALIGNMENT_CYCLE = { 'none', 'left', 'center', 'right' }

---@type table<gutenberg.table.Alignment, integer>
local ALIGNMENT_INDEX = { none = 1, left = 2, center = 3, right = 4 }

--- Move the cursor to the (row, col) cell of the rewritten table at
--- `sr`, when the edited buffer is the one on screen. Blank cells
--- (fresh inserts) have no text range; land just inside their opening
--- pipe.
---@param ctx gutenberg.Context
---@param sr integer Start row of the table node before the rewrite.
---@param target_row integer 0 = header.
---@param target_col integer
local function land(ctx, sr, target_row, target_col)
  if vim.api.nvim_win_get_buf(0) ~= ctx.bufnr then
    return
  end
  local probe = { bufnr = ctx.bufnr, cursor = { sr + 1, 0 } }
  local ok, _, current = pcall(api.read, probe)
  if not ok or current == nil then
    return
  end

  local range = api.cell_range(current, target_row, target_col, probe)
  if range ~= nil then
    vim.api.nvim_win_set_cursor(0, { range.start[1], range.start[2] })
    return
  end

  local line_row = sr + (target_row == 0 and 0 or target_row + 1)
  local line = vim.api.nvim_buf_get_lines(
    ctx.bufnr,
    line_row,
    line_row + 1,
    false
  )[1] or ''
  local pipes = 0
  for i = 1, #line do
    if line:sub(i, i) == '|' then
      pipes = pipes + 1
      if pipes == target_col then
        vim.api.nvim_win_set_cursor(
          0,
          { line_row + 1, math.min(i + 1, math.max(#line - 1, 0)) }
        )
        return
      end
    end
  end
end

--- Open a `vim.ui.select` picker of structural operations on the table
--- at the cursor: insert/delete/move rows and columns, set the cursor
--- column's alignment (a nested select), and format. Entries that
--- don't apply at the cursor position (deleting the header row, moving
--- the first column left, …) are omitted. Column inserts prompt
--- `vim.ui.input` for the header text.
---
--- The cursor's table, row, and column are resolved eagerly — the
--- prompt can't retarget — and erroring off-table happens
--- synchronously so a `pcall` + notify keymap edge still works. Every
--- branch lands in one buffer write, and the cursor moves to the
--- affected cell. This is a sanctioned UI edge (see AGENTS.md):
--- failures inside prompt callbacks surface via `gutenberg.keymap.notify`.
---@param ctx? gutenberg.Context.Partial
function M.actions(ctx)
  ctx = context.resolve(ctx)
  local tbl, node = api.read(ctx)
  local sr = node:range()
  local row = api.row_at(ctx) or 0
  local col = api.column_at(ctx) or 1
  local notify = require('gutenberg.keymap').notify

  --- Rewrite the table through `fn` in one buffer update, then park
  --- the cursor on the affected cell.
  ---@param fn fun(tbl: gutenberg.table.Table)
  ---@param target_row integer
  ---@param target_col integer
  local function apply(fn, target_row, target_col)
    notify(function()
      M.update(fn, ctx)
      land(ctx, sr, target_row, target_col)
    end)
  end

  ---@type { label: string, run: fun() }[]
  local actions = {}
  ---@param label string
  ---@param applicable boolean
  ---@param run fun()
  local function add(label, applicable, run)
    if applicable then
      table.insert(actions, { label = label, run = run })
    end
  end

  add('Insert row above', row >= 1, function()
    apply(function(t)
      api.insert_row(t, row, {})
    end, row, col)
  end)

  add('Insert row below', true, function()
    local index = row + 1
    apply(function(t)
      api.insert_row(t, index, {})
    end, index, col)
  end)

  add('Delete row', row >= 1, function()
    local target = math.max(0, math.min(row, #tbl.rows - 1))
    apply(function(t)
      api.delete_row(t, row)
    end, target, col)
  end)

  add('Move row up', row >= 2, function()
    apply(function(t)
      api.move_row(t, row, row - 1)
    end, row - 1, col)
  end)

  add('Move row down', row >= 1 and row < #tbl.rows, function()
    apply(function(t)
      api.move_row(t, row, row + 1)
    end, row + 1, col)
  end)

  add('Insert column left', true, function()
    vim.ui.input({ prompt = 'Header: ' }, function(input)
      if input == nil then
        return
      end
      apply(function(t)
        api.insert_column(t, col, { header = input })
      end, row, col)
    end)
  end)

  add('Insert column right', true, function()
    vim.ui.input({ prompt = 'Header: ' }, function(input)
      if input == nil then
        return
      end
      apply(function(t)
        api.insert_column(t, col + 1, { header = input })
      end, row, col + 1)
    end)
  end)

  add('Delete column', #tbl.headers > 1, function()
    local target = math.min(col, #tbl.headers - 1)
    apply(function(t)
      api.delete_column(t, col)
    end, row, target)
  end)

  add('Move column left', col >= 2, function()
    apply(function(t)
      api.move_column(t, col, col - 1)
    end, row, col - 1)
  end)

  add('Move column right', col < #tbl.headers, function()
    apply(function(t)
      api.move_column(t, col, col + 1)
    end, row, col + 1)
  end)

  add('Set alignment', true, function()
    vim.ui.select(
      { 'none', 'left', 'center', 'right' },
      { prompt = 'Alignment' },
      function(choice)
        if choice == nil then
          return
        end
        apply(function(t)
          api.set_alignment(t, col, choice)
        end, row, col)
      end
    )
  end)

  add('Format table', true, function()
    apply(function() end, row, col)
  end)

  vim.ui.select(actions, {
    prompt = 'Table action',
    format_item = function(action)
      return action.label
    end,
  }, function(choice)
    if choice == nil then
      return
    end
    choice.run()
  end)
end

--- Every cell address in a table, reading order: header left-to-right,
--- then each body row.
---@param tbl gutenberg.table.Table
---@return [integer, integer][] positions {row, col} pairs.
local function cell_positions(tbl)
  ---@type [integer, integer][]
  local positions = {}
  for col = 1, #tbl.headers do
    table.insert(positions, { 0, col })
  end
  for row, cells in ipairs(tbl.rows) do
    for col = 1, #cells do
      table.insert(positions, { row, col })
    end
  end
  return positions
end

--- Step `ctx.count` cells in `direction` from the cursor's cell and
--- move the current window's cursor to the start of the cell text.
--- Blank cells (nothing to land on) are skipped; overshooting clamps
--- to the furthest reachable cell. Returns the landed-on cell's range,
--- or nil (cursor untouched) when no cell qualifies.
---@param direction 1 | -1
---@param ctx gutenberg.Context
---@return gutenberg.Range?
local function step_cell(direction, ctx)
  local tbl, node = api.read(ctx)
  local row = api.row_at(ctx)
  local col = api.column_at(ctx)
  local positions = cell_positions(tbl)

  ---@type integer?
  local index
  for i, pos in ipairs(positions) do
    if pos[1] == row and pos[2] == col then
      index = i
      break
    end
  end
  if index == nil then
    index = direction == 1 and 0 or #positions + 1
  end

  ---@type gutenberg.Range?
  local target
  local remaining = ctx.count
  local i = index
  while remaining > 0 do
    i = i + direction
    if i < 1 or i > #positions then
      break
    end
    local range = api.cell_range(node, positions[i][1], positions[i][2], ctx)
    if range ~= nil then
      target = range
      remaining = remaining - 1
    end
  end

  if target == nil then
    return nil
  end
  vim.api.nvim_win_set_cursor(0, { target.start[1], target.start[2] })
  return target
end

--- Move the cursor to the start of the `ctx.count`-th cell after the
--- cursor's, wrapping across rows in reading order and skipping blank
--- cells. Unlike everything in `gutenberg.api`, this MOVES the current
--- window's cursor — it exists to be a motion. Returns the landed-on
--- cell's range, or nil (cursor untouched) at the end of the table.
--- Errors if the cursor isn't on a pipe table.
---@param ctx? gutenberg.Context.Partial
---@return gutenberg.Range?
function M.next_cell(ctx)
  return step_cell(1, context.resolve(ctx))
end

--- Move the cursor to the start of the `ctx.count`-th cell before the
--- cursor's, wrapping across rows in reading order and skipping blank
--- cells. Moves the current window's cursor; returns the landed-on
--- cell's range, or nil (cursor untouched) at the start of the table.
--- Errors if the cursor isn't on a pipe table.
---@param ctx? gutenberg.Context.Partial
---@return gutenberg.Range?
function M.prev_cell(ctx)
  return step_cell(-1, context.resolve(ctx))
end

--- Step `ctx.count` tables via `find` and move the cursor to the last
--- one reached, clamping at the furthest match.
---@param find fun(ctx: gutenberg.Context.Partial): gutenberg.table.Table?, TSNode?
---@param ctx gutenberg.Context
---@return gutenberg.table.Table?, TSNode?
local function jump(find, ctx)
  ---@type gutenberg.table.Table?, TSNode?
  local found, node
  local probe = { bufnr = ctx.bufnr, cursor = ctx.cursor }
  for _ = 1, ctx.count do
    local t, n = find(probe)
    if n == nil then
      break
    end
    found, node = t, n
    local row, col = n:range()
    probe = { bufnr = ctx.bufnr, cursor = { row + 1, col } }
  end

  if node == nil then
    return nil, nil
  end
  local row, col = node:range()
  vim.api.nvim_win_set_cursor(0, { row + 1, col })
  return found, node
end

--- Move the cursor to the `ctx.count`-th pipe table after it, clamping
--- at the last one. Moves the current window's cursor; returns the
--- table landed on, or nil (cursor untouched) when none follows.
---@param ctx? gutenberg.Context.Partial
---@return gutenberg.table.Table?, TSNode?
function M.next_table(ctx)
  return jump(api.find_next, context.resolve(ctx))
end

--- Move the cursor to the `ctx.count`-th pipe table before it,
--- clamping at the first one. Moves the current window's cursor;
--- returns the table landed on, or nil (cursor untouched) when none
--- precedes.
---@param ctx? gutenberg.Context.Partial
---@return gutenberg.table.Table?, TSNode?
function M.prev_table(ctx)
  return jump(api.find_prev, context.resolve(ctx))
end

--- Visually select the trimmed text of the cell under the cursor —
--- the engine behind an `i|` inner-cell textobject in both visual and
--- operator-pending maps. Leaves any current visual mode first, then
--- selects charwise. Errors if the cursor isn't on a pipe table, or
--- when the cell is blank (nothing to select).
---@param ctx? gutenberg.Context.Partial
---@return gutenberg.Range selected
function M.select_cell(ctx)
  ctx = context.resolve(ctx)
  local _, node = api.read(ctx)
  local row = api.row_at(ctx)
  local col = api.column_at(ctx)
  if row == nil or col == nil then
    error('gutenberg: cursor is not on a pipe table', 0)
  end

  local range = api.cell_range(node, row, col, ctx)
  if range == nil then
    error('gutenberg: no cell text under the cursor', 0)
  end

  local mode = vim.fn.mode()
  if mode == 'v' or mode == 'V' or mode == '\22' then
    vim.cmd('normal! \27')
  end
  vim.api.nvim_win_set_cursor(0, { range.start[1], range.start[2] })
  vim.cmd('normal! v')
  vim.api.nvim_win_set_cursor(0, { range.stop[1], range.stop[2] })
  return range
end

--- Advance the alignment of the column under the cursor `ctx.count`
--- steps through none → left → center → right → none, rewriting the
--- table in a single buffer update. Errors if the cursor isn't on a
--- pipe table, or when the cursor column has no delimiter cell.
---@param ctx? gutenberg.Context.Partial
---@return gutenberg.table.Table[] written
function M.cycle_alignment(ctx)
  ctx = context.resolve(ctx)
  local col = api.column_at(ctx)
  if col == nil then
    error('gutenberg: cursor is not on a pipe table', 0)
  end
  return M.update(function(tbl)
    local index = ALIGNMENT_INDEX[api.get_alignment(tbl, col)]
    local advanced = ALIGNMENT_CYCLE[(index - 1 + ctx.count) % 4 + 1]
    api.set_alignment(tbl, col, advanced)
  end, ctx)
end

--- Move the cursor's column `direction * ctx.count` places, clamped at
--- the table edges, then land the cursor on the moved column so
--- repeated presses keep dragging it.
---@param direction 1 | -1
---@param ctx gutenberg.Context
---@return gutenberg.table.Table[] written
local function shift_column(direction, ctx)
  local tbl, node = api.read(ctx)
  local col = api.column_at(ctx)
  if col == nil then
    error('gutenberg: cursor is not on a pipe table', 0)
  end

  local target =
    math.max(1, math.min(#tbl.headers, col + direction * ctx.count))
  if target == col then
    error(
      direction == 1 and 'gutenberg: column is already rightmost'
        or 'gutenberg: column is already leftmost',
      0
    )
  end

  local row = api.row_at(ctx) or 0
  local sr = node:range()
  local written = M.update(function(t)
    api.move_column(t, col, target)
  end, ctx)
  land(ctx, sr, row, target)
  return written
end

--- Move the column under the cursor `ctx.count` columns left, clamping
--- at the first column, and rewrite the table in one buffer update.
--- Unlike most codemods this moves the current window's cursor — it
--- follows the column so repeated presses keep dragging it. Errors if
--- the cursor isn't on a pipe table, or when the column is already
--- leftmost.
---@param ctx? gutenberg.Context.Partial
---@return gutenberg.table.Table[] written
function M.move_column_left(ctx)
  return shift_column(-1, context.resolve(ctx))
end

--- Move the column under the cursor `ctx.count` columns right,
--- clamping at the last column, and rewrite the table in one buffer
--- update. Moves the current window's cursor — it follows the column
--- so repeated presses keep dragging it. Errors if the cursor isn't on
--- a pipe table, or when the column is already rightmost.
---@param ctx? gutenberg.Context.Partial
---@return gutenberg.table.Table[] written
function M.move_column_right(ctx)
  return shift_column(1, context.resolve(ctx))
end

return M
