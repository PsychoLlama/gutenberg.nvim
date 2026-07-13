---@alias gutenberg.table.Alignment 'none' | 'left' | 'center' | 'right'

---@class gutenberg.table.Table
---@field alignments gutenberg.table.Alignment[] Per-column alignment.
---@field headers string[] Header cell text, trimmed.
---@field rows string[][] Body cells, per row then per column, trimmed.

local buffer = require('gutenberg.buffer')
local context = require('gutenberg.context')
local ts = require('gutenberg.treesitter')

---@class gutenberg.api.table
local M = {}

--- Whether the cursor is on a pipe table. Gate calls to `read` with this.
---@param ctx? gutenberg.Context.Partial
---@return boolean
function M.is_table(ctx)
  return ts.find_at_cursor(context.resolve(ctx), 'table') ~= nil
end

---@param node TSNode
---@return gutenberg.table.Alignment
local function read_alignment(node)
  local has_left = false
  local has_right = false
  for child in node:iter_children() do
    local t = child:type()
    if t == 'pipe_table_align_left' then
      has_left = true
    elseif t == 'pipe_table_align_right' then
      has_right = true
    end
  end
  if has_left and has_right then
    return 'center'
  elseif has_left then
    return 'left'
  elseif has_right then
    return 'right'
  end
  return 'none'
end

--- The 0-based columns of the unescaped `|` delimiters on `line`, at or
--- after `left` (the table's left edge, so a container prefix like a
--- block quote's `> ` is skipped). A `|` preceded by an odd run of
--- backslashes is escaped (`\|`) and stays inside its cell.
---@param line string
---@param left integer
---@return integer[]
local function pipe_columns(line, left)
  local cols = {}
  local i = left + 1
  while i <= #line do
    if line:sub(i, i) == '|' then
      local backslashes = 0
      local j = i - 1
      while j >= 1 and line:sub(j, j) == '\\' do
        backslashes = backslashes + 1
        j = j - 1
      end
      if backslashes % 2 == 0 then
        table.insert(cols, i - 1)
      end
    end
    i = i + 1
  end
  return cols
end

--- The logical cells of a table row, derived from the pipe delimiters on
--- its `line` rather than from `pipe_table_cell` nodes — the only
--- reliable source, since tree-sitter-markdown drops the node for a
--- zero-width cell (`|a||c|`) and pushes stray pipes into ERROR nodes.
--- Each cell is `{ open, close }`: the 0-based columns of the pipes on
--- either side (a trailing cell without a closing pipe closes at end of
--- line). The N-1 spans between N pipes are the columns; the leading and
--- trailing margins are dropped.
---@param line string
---@param left integer The table's left edge column (see `pipe_columns`).
---@return { open: integer, close: integer }[]
local function cell_bounds(line, left)
  local pipes = pipe_columns(line, left)
  local bounds = {}
  for k = 1, #pipes - 1 do
    table.insert(bounds, { open = pipes[k], close = pipes[k + 1] })
  end
  if #pipes >= 1 then
    local last = pipes[#pipes]
    if line:sub(last + 2):match('%S') ~= nil then
      table.insert(bounds, { open = last, close = #line })
    end
  end
  return bounds
end

--- The trimmed text of the cell bounded by `bound` on `line`. The cell's
--- interior runs from just past the opening pipe to the closing pipe.
---@param line string
---@param bound { open: integer, close: integer }
---@return string
local function cell_text(line, bound)
  return vim.trim(line:sub(bound.open + 2, bound.close))
end

---@param bufnr integer
---@param row integer 0-based buffer row.
---@return string
local function line_at(bufnr, row)
  return vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ''
end

--- Decode a header or body row into its trimmed cell texts. `left` is the
--- table's left-edge column, shared by every row.
---@param bufnr integer
---@param row integer 0-based buffer row of the table row.
---@param left integer
---@return string[]
local function read_row_cells(bufnr, row, left)
  local line = line_at(bufnr, row)
  local cells = {}
  for _, bound in ipairs(cell_bounds(line, left)) do
    table.insert(cells, cell_text(line, bound))
  end
  return cells
end

--- Decode a `pipe_table` node into a table struct.
---@param node TSNode
---@param bufnr integer
---@return gutenberg.table.Table
local function decode(node, bufnr)
  local headers = {}
  local alignments = {}
  local rows = {}
  local _, left = node:range()

  for child in node:iter_children() do
    local t = child:type()
    if t == 'pipe_table_header' then
      headers = read_row_cells(bufnr, (child:range()), left)
    elseif t == 'pipe_table_delimiter_row' then
      for cell in child:iter_children() do
        if cell:type() == 'pipe_table_delimiter_cell' then
          table.insert(alignments, read_alignment(cell))
        end
      end
    elseif t == 'pipe_table_row' then
      table.insert(rows, read_row_cells(bufnr, (child:range()), left))
    end
  end

  return {
    alignments = alignments,
    headers = headers,
    rows = rows,
  }
end

--- Read the pipe table containing the cursor. Errors if the cursor isn't on
--- a pipe table; validate with `is_table` first. The returned `TSNode`
--- captures the table's range for `replace`.
---@param ctx? gutenberg.Context.Partial
---@return gutenberg.table.Table, TSNode
function M.read(ctx)
  ctx = context.resolve(ctx)
  local node = ts.find_at_cursor(ctx, 'table')
  if node == nil then
    error('gutenberg: cursor is not on a pipe table', 0)
  end
  return decode(node, ctx.bufnr), node
end

--- Construct a pipe table from explicit fields. When `headers` is given but
--- `alignments` is not, alignments default to `'none'` per header column.
--- With no fields, returns a 1-column table with an empty header.
---@param fields { alignments?: gutenberg.table.Alignment[], headers?: string[], rows?: string[][] }
---@return gutenberg.table.Table
function M.create(fields)
  local config = require('gutenberg.config').get().table
  local headers = fields.headers or { '' }
  local alignments = fields.alignments
  if alignments == nil then
    alignments = {}
    for _ = 1, #headers do
      table.insert(alignments, config.default_alignment)
    end
  end
  return {
    alignments = alignments,
    headers = headers,
    rows = fields.rows or {},
  }
end

--- The logical column count: the widest of the header, any body row, and
--- the alignment list, so ragged and zero-width-cell tables still address
--- every column.
---@param tbl gutenberg.table.Table
---@return integer
local function column_count(tbl)
  local count = #tbl.headers
  if #tbl.alignments > count then
    count = #tbl.alignments
  end
  for _, row in ipairs(tbl.rows) do
    if #row > count then
      count = #row
    end
  end
  return count
end

---@param alignment gutenberg.table.Alignment
---@param width integer
---@return string
local function render_delimiter(alignment, width)
  if alignment == 'left' then
    return ':' .. string.rep('-', width - 1)
  elseif alignment == 'right' then
    return string.rep('-', width - 1) .. ':'
  elseif alignment == 'center' then
    return ':' .. string.rep('-', width - 2) .. ':'
  end
  return string.rep('-', width)
end

local DELIMITER_MIN_WIDTH = 3

---@param text string
---@param width integer
---@param alignment gutenberg.table.Alignment
---@return string
local function pad_cell(text, width, alignment)
  local pad = width - vim.fn.strdisplaywidth(text)
  if pad <= 0 then
    return text
  end
  if alignment == 'right' then
    return string.rep(' ', pad) .. text
  elseif alignment == 'center' then
    local left = math.floor(pad / 2)
    local right = pad - left
    return string.rep(' ', left) .. text .. string.rep(' ', right)
  end
  return text .. string.rep(' ', pad)
end

---@param cells string[]
---@param widths integer[]
---@param alignments gutenberg.table.Alignment[]
---@param renderer fun(text: string, width: integer, alignment: gutenberg.table.Alignment): string
---@return string
local function join_row(cells, widths, alignments, renderer)
  local parts = { '|' }
  for i = 1, #widths do
    local cell = cells[i] or ''
    local alignment = alignments[i] or 'none'
    table.insert(parts, ' ' .. renderer(cell, widths[i], alignment) .. ' |')
  end
  return table.concat(parts)
end

--- Render a pipe table to lines (one per header, delimiter, and body row).
--- Columns are padded to the max width across the header and body, with
--- alignment markers in the delimiter row.
---@param tbl gutenberg.table.Table
---@return string[]
function M.render(tbl)
  local columns = column_count(tbl)

  local alignments = {}
  for i = 1, columns do
    alignments[i] = tbl.alignments[i] or 'none'
  end

  local widths = {}
  for i = 1, columns do
    widths[i] = DELIMITER_MIN_WIDTH
    local header = tbl.headers[i] or ''
    local hw = vim.fn.strdisplaywidth(header)
    if hw > widths[i] then
      widths[i] = hw
    end
    for _, row in ipairs(tbl.rows) do
      local w = vim.fn.strdisplaywidth(row[i] or '')
      if w > widths[i] then
        widths[i] = w
      end
    end
  end

  local lines = {}
  table.insert(lines, join_row(tbl.headers, widths, alignments, pad_cell))
  table.insert(
    lines,
    join_row({}, widths, alignments, function(_, width, alignment)
      return render_delimiter(alignment, width)
    end)
  )
  for _, row in ipairs(tbl.rows) do
    table.insert(lines, join_row(row, widths, alignments, pad_cell))
  end
  return lines
end

--- Replace `node`'s range with the rendered tables in a single buffer
--- update. Pass an empty `tables` list to delete the node. Multiple tables
--- are separated by a blank line so the markdown parser keeps them
--- distinct.
---@param node TSNode
---@param tables gutenberg.table.Table[]
---@param ctx? gutenberg.Context.Partial
function M.replace(node, tables, ctx)
  ctx = context.resolve(ctx)
  local sr = node:range()
  local prefix = ts.container_prefix(node, ctx.bufnr)

  local lines = {}
  for i, tbl in ipairs(tables) do
    if i > 1 then
      table.insert(lines, prefix)
    end
    for _, line in ipairs(M.render(tbl)) do
      table.insert(lines, prefix .. line)
    end
  end

  buffer.set_lines(ctx.bufnr, sr, ts.end_row(node), lines)
end

--- Get a cell's text. Row 0 is the header; rows 1..N are body rows.
--- Errors on out-of-range indices.
---@param tbl gutenberg.table.Table
---@param row integer
---@param col integer
---@return string
function M.get_cell(tbl, row, col)
  if row == 0 then
    if col < 1 or col > #tbl.headers then
      error('gutenberg: column index out of range: ' .. col, 0)
    end
    return tbl.headers[col]
  end
  local body = tbl.rows[row]
  if body == nil then
    error('gutenberg: row index out of range: ' .. row, 0)
  end
  if col < 1 or col > #body then
    error('gutenberg: column index out of range: ' .. col, 0)
  end
  return body[col]
end

--- Set a cell's text. Row 0 is the header; rows 1..N are body rows.
--- `col` is validated against the table's logical column count (not the
--- target row's current length), and a row shorter than `col` is padded
--- with empty cells first — so writing into a freshly `insert_row`-ed
--- blank row, or a ragged row, works. Errors on out-of-range indices.
---@param tbl gutenberg.table.Table
---@param row integer
---@param col integer
---@param text string
function M.set_cell(tbl, row, col, text)
  if col < 1 or col > column_count(tbl) or col ~= math.floor(col) then
    error('gutenberg: column index out of range: ' .. col, 0)
  end
  if row == 0 then
    while #tbl.headers < col do
      table.insert(tbl.headers, '')
    end
    tbl.headers[col] = text
    return
  end
  local body = tbl.rows[row]
  if body == nil then
    error('gutenberg: row index out of range: ' .. row, 0)
  end
  while #body < col do
    table.insert(body, '')
  end
  body[col] = text
end

--- Get a column's alignment. Errors on out-of-range index.
---@param tbl gutenberg.table.Table
---@param col integer
---@return gutenberg.table.Alignment
function M.get_alignment(tbl, col)
  if col < 1 or col > #tbl.alignments then
    error('gutenberg: column index out of range: ' .. col, 0)
  end
  return tbl.alignments[col]
end

--- Set a column's alignment. Errors on out-of-range index.
---@param tbl gutenberg.table.Table
---@param col integer
---@param alignment gutenberg.table.Alignment
function M.set_alignment(tbl, col, alignment)
  if col < 1 or col > #tbl.alignments then
    error('gutenberg: column index out of range: ' .. col, 0)
  end
  tbl.alignments[col] = alignment
end

---@type table<string, true>
local ROW_TYPES = {
  pipe_table_header = true,
  pipe_table_delimiter_row = true,
  pipe_table_row = true,
}

--- The 1-based column index under the cursor, or nil when the cursor
--- isn't on a pipe table. The cursor resolves to the last column
--- starting at or before it, so a cursor on a `|` counts as the column
--- that pipe closes; before the first cell it counts as column 1.
--- Columns are the spans between pipe delimiters (see `cell_bounds`), so
--- zero-width and blank cells count like any other.
---@param ctx? gutenberg.Context.Partial
---@return integer?
function M.column_at(ctx)
  ctx = context.resolve(ctx)
  local node = ts.find_at_cursor(ctx, 'table')
  if node == nil then
    return nil
  end

  local row = ctx.cursor[1] - 1
  local col = ctx.cursor[2]
  local _, left = node:range()
  for child in node:iter_children() do
    local sr = child:range()
    if ROW_TYPES[child:type()] and sr == row then
      local bounds = cell_bounds(line_at(ctx.bufnr, row), left)
      ---@type integer?
      local index
      for i, bound in ipairs(bounds) do
        -- A cell's interior starts one column past its opening pipe; a
        -- cursor at or before that pipe hasn't reached the cell yet.
        if bound.open < col then
          index = i
        end
      end
      if index ~= nil then
        return index
      end
      return #bounds > 0 and 1 or nil
    end
  end
  return nil
end

--- The row index under the cursor: 0 for the header (and delimiter)
--- rows, 1..N for body rows, nil when the cursor isn't on a pipe
--- table.
---@param ctx? gutenberg.Context.Partial
---@return integer?
function M.row_at(ctx)
  ctx = context.resolve(ctx)
  local node = ts.find_at_cursor(ctx, 'table')
  if node == nil then
    return nil
  end

  local row = ctx.cursor[1] - 1
  local body = 0
  for child in node:iter_children() do
    local t = child:type()
    if ROW_TYPES[t] then
      local sr = child:range()
      if t == 'pipe_table_row' then
        body = body + 1
        if sr == row then
          return body
        end
      elseif sr == row then
        return 0
      end
    end
  end
  return nil
end

--- Nearest pipe table starting strictly after the cursor row. Returns
--- nil when no table qualifies.
---@param ctx? gutenberg.Context.Partial
---@return gutenberg.table.Table?, TSNode?
function M.find_next(ctx)
  ctx = context.resolve(ctx)
  local row = ctx.cursor[1] - 1
  for _, node in ipairs(ts.collect(ctx.bufnr, 'table')) do
    local sr = node:range()
    if sr > row then
      return decode(node, ctx.bufnr), node
    end
  end
  return nil, nil
end

--- Nearest pipe table starting strictly before the cursor row. Returns
--- nil when no table qualifies.
---@param ctx? gutenberg.Context.Partial
---@return gutenberg.table.Table?, TSNode?
function M.find_prev(ctx)
  ctx = context.resolve(ctx)
  local row = ctx.cursor[1] - 1
  ---@type TSNode?
  local match
  for _, node in ipairs(ts.collect(ctx.bufnr, 'table')) do
    local sr = node:range()
    if sr < row then
      match = node
    else
      break
    end
  end
  if match == nil then
    return nil, nil
  end
  return decode(match, ctx.bufnr), match
end

--- The editable buffer range of a cell: charwise, multibyte-safe
--- endpoints. Row 0 is the header; rows 1..N are body rows.
---
--- For a cell with text, the trimmed text's range (inclusive endpoints).
--- For a blank cell it never fails: the cell's interior whitespace when
--- there is padding to select, otherwise a collapsed range at the
--- insertion point just inside the opening pipe — so `next_cell`, the
--- `i|` textobject, and cursor landing all have somewhere to go on empty
--- cells and empty rows. Returns nil only when the cell doesn't exist.
---@param node TSNode A `pipe_table` node (see `read`).
---@param row integer
---@param col integer
---@param ctx? gutenberg.Context.Partial
---@return gutenberg.Range?
function M.cell_range(node, row, col, ctx)
  ctx = context.resolve(ctx)
  local _, left = node:range()

  ---@type integer?
  local row_line
  local body = 0
  for child in node:iter_children() do
    local t = child:type()
    if row == 0 and t == 'pipe_table_header' then
      row_line = (child:range())
      break
    elseif t == 'pipe_table_row' then
      body = body + 1
      if body == row then
        row_line = (child:range())
        break
      end
    end
  end
  if row_line == nil then
    return nil
  end

  local line = line_at(ctx.bufnr, row_line)
  local bound = cell_bounds(line, left)[col]
  if bound == nil then
    return nil
  end

  local r = row_line + 1
  local text = line:sub(bound.open + 2, bound.close)
  local trimmed = vim.trim(text)
  if trimmed ~= '' then
    local leading = #(text:match('^%s*'))
    local interior = bound.open + 1
    -- The stop column points at the first byte of the last character so
    -- consumers can treat it as an inclusive cursor position.
    local last_byte = leading + #trimmed
    local stop_col = interior
      + last_byte
      - 1
      + vim.str_utf_start(text, last_byte)
    return {
      mode = 'char',
      start = { r, interior + leading },
      stop = { r, stop_col },
    }
  end

  -- Blank cell: the insertion point sits one column past `| ` so typed
  -- text picks up a leading pad, clamped inside the closing pipe.
  local insert_col = math.min(bound.open + 2, bound.close)
  local last_pad = bound.close - 1
  return {
    mode = 'char',
    start = { r, insert_col },
    stop = { r, math.max(insert_col, last_pad) },
  }
end

--- Insert `row` (a list of cell texts) so it lands at body-row `index`
--- (1-based; `#rows + 1` appends). In-memory codemod — write it back
--- with `replace`. Errors on out-of-range indices.
---@param tbl gutenberg.table.Table
---@param index integer
---@param row string[]
function M.insert_row(tbl, index, row)
  if index < 1 or index > #tbl.rows + 1 or index ~= math.floor(index) then
    error('gutenberg: row index out of range: ' .. index, 0)
  end
  table.insert(tbl.rows, index, row)
end

--- Delete the body row at `index`. Row 0 (the header) cannot be
--- deleted. In-memory codemod. Errors on out-of-range indices.
---@param tbl gutenberg.table.Table
---@param index integer
function M.delete_row(tbl, index)
  if index == 0 then
    error('gutenberg: cannot delete the header row', 0)
  end
  if index < 1 or index > #tbl.rows or index ~= math.floor(index) then
    error('gutenberg: row index out of range: ' .. index, 0)
  end
  table.remove(tbl.rows, index)
end

--- Move the body row at `from` to position `to`. In-memory codemod.
--- Errors on out-of-range indices.
---@param tbl gutenberg.table.Table
---@param from integer
---@param to integer
function M.move_row(tbl, from, to)
  for _, index in ipairs({ from, to }) do
    if index < 1 or index > #tbl.rows or index ~= math.floor(index) then
      error('gutenberg: row index out of range: ' .. index, 0)
    end
  end
  local row = table.remove(tbl.rows, from)
  table.insert(tbl.rows, to, row)
end

--- Insert a column so it lands at `index` (1-based; `#headers + 1`
--- appends). `fields.cells` fills body cells top-down; missing cells
--- default to `''` and the alignment to the configured
--- `default_alignment`. In-memory codemod. Errors on out-of-range
--- indices.
---@param tbl gutenberg.table.Table
---@param index integer
---@param fields? { header?: string, alignment?: gutenberg.table.Alignment, cells?: string[] }
function M.insert_column(tbl, index, fields)
  fields = fields or {}
  if index < 1 or index > #tbl.headers + 1 or index ~= math.floor(index) then
    error('gutenberg: column index out of range: ' .. index, 0)
  end

  local config = require('gutenberg.config').get().table
  table.insert(tbl.headers, index, fields.header or '')
  table.insert(
    tbl.alignments,
    math.min(index, #tbl.alignments + 1),
    fields.alignment or config.default_alignment
  )

  local cells = fields.cells or {}
  for i, row in ipairs(tbl.rows) do
    while #row < index - 1 do
      table.insert(row, '')
    end
    table.insert(row, index, cells[i] or '')
  end
end

--- Delete the column at `index` across the header, alignments, and
--- every body row. The last remaining column cannot be deleted.
--- In-memory codemod. Errors on out-of-range indices.
---@param tbl gutenberg.table.Table
---@param index integer
function M.delete_column(tbl, index)
  if index < 1 or index > #tbl.headers or index ~= math.floor(index) then
    error('gutenberg: column index out of range: ' .. index, 0)
  end
  if #tbl.headers == 1 then
    error('gutenberg: cannot delete the only column', 0)
  end

  table.remove(tbl.headers, index)
  if index <= #tbl.alignments then
    table.remove(tbl.alignments, index)
  end
  for _, row in ipairs(tbl.rows) do
    if index <= #row then
      table.remove(row, index)
    end
  end
end

--- Move the column at `from` to position `to` across the header,
--- alignments, and every body row. Ragged rows are padded with empty
--- cells first so the move is well-defined. In-memory codemod. Errors
--- on out-of-range indices.
---@param tbl gutenberg.table.Table
---@param from integer
---@param to integer
function M.move_column(tbl, from, to)
  for _, index in ipairs({ from, to }) do
    if index < 1 or index > #tbl.headers or index ~= math.floor(index) then
      error('gutenberg: column index out of range: ' .. index, 0)
    end
  end

  table.insert(tbl.headers, to, table.remove(tbl.headers, from))
  while #tbl.alignments < #tbl.headers do
    table.insert(tbl.alignments, 'none')
  end
  table.insert(tbl.alignments, to, table.remove(tbl.alignments, from))
  for _, row in ipairs(tbl.rows) do
    while #row < #tbl.headers do
      table.insert(row, '')
    end
    table.insert(row, to, table.remove(row, from))
  end
end

return M
