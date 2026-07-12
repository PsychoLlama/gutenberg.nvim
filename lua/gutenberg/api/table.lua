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

---@param node TSNode
---@param bufnr integer
---@return string[]
local function read_row_cells(node, bufnr)
  local cells = {}
  for child in node:iter_children() do
    if child:type() == 'pipe_table_cell' then
      local text = vim.treesitter.get_node_text(child, bufnr)
      table.insert(cells, vim.trim(text))
    end
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

  for child in node:iter_children() do
    local t = child:type()
    if t == 'pipe_table_header' then
      headers = read_row_cells(child, bufnr)
    elseif t == 'pipe_table_delimiter_row' then
      for cell in child:iter_children() do
        if cell:type() == 'pipe_table_delimiter_cell' then
          table.insert(alignments, read_alignment(cell))
        end
      end
    elseif t == 'pipe_table_row' then
      table.insert(rows, read_row_cells(child, bufnr))
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
  local column_count = #tbl.headers
  for _, row in ipairs(tbl.rows) do
    if #row > column_count then
      column_count = #row
    end
  end
  if #tbl.alignments > column_count then
    column_count = #tbl.alignments
  end

  local alignments = {}
  for i = 1, column_count do
    alignments[i] = tbl.alignments[i] or 'none'
  end

  local widths = {}
  for i = 1, column_count do
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
--- Errors on out-of-range indices.
---@param tbl gutenberg.table.Table
---@param row integer
---@param col integer
---@param text string
function M.set_cell(tbl, row, col, text)
  if row == 0 then
    if col < 1 or col > #tbl.headers then
      error('gutenberg: column index out of range: ' .. col, 0)
    end
    tbl.headers[col] = text
    return
  end
  local body = tbl.rows[row]
  if body == nil then
    error('gutenberg: row index out of range: ' .. row, 0)
  end
  if col < 1 or col > #body then
    error('gutenberg: column index out of range: ' .. col, 0)
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

---@type table<string, true>
local CELL_TYPES = {
  pipe_table_cell = true,
  pipe_table_delimiter_cell = true,
}

--- The 1-based column index under the cursor, or nil when the cursor
--- isn't on a pipe table. The cursor resolves to the last column
--- starting at or before it, so a cursor on a `|` counts as the column
--- that pipe closes; before the first cell it counts as column 1.
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
  for child in node:iter_children() do
    local sr = child:range()
    if ROW_TYPES[child:type()] and sr == row then
      ---@type integer?
      local index
      local count = 0
      for cell in child:iter_children() do
        if CELL_TYPES[cell:type()] then
          count = count + 1
          local _, sc = cell:range()
          if sc <= col then
            index = count
          end
        end
      end
      if index ~= nil then
        return index
      end
      return count > 0 and 1 or nil
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

--- The buffer range of a cell's trimmed text: charwise, multibyte-safe
--- endpoints. Row 0 is the header; rows 1..N are body rows. Returns
--- nil when the cell doesn't exist or holds only whitespace.
---@param node TSNode A `pipe_table` node (see `read`).
---@param row integer
---@param col integer
---@param ctx? gutenberg.Context.Partial
---@return gutenberg.Range?
function M.cell_range(node, row, col, ctx)
  ctx = context.resolve(ctx)

  ---@type TSNode?
  local row_node
  local body = 0
  for child in node:iter_children() do
    local t = child:type()
    if row == 0 and t == 'pipe_table_header' then
      row_node = child
      break
    elseif t == 'pipe_table_row' then
      body = body + 1
      if body == row then
        row_node = child
        break
      end
    end
  end
  if row_node == nil then
    return nil
  end

  ---@type TSNode?
  local cell_node
  local count = 0
  for cell in row_node:iter_children() do
    if cell:type() == 'pipe_table_cell' then
      count = count + 1
      if count == col then
        cell_node = cell
        break
      end
    end
  end
  if cell_node == nil then
    return nil
  end

  local text = vim.treesitter.get_node_text(cell_node, ctx.bufnr)
  local trimmed = vim.trim(text)
  if trimmed == '' then
    return nil
  end
  local leading = #(text:match('^%s*'))

  local sr, sc = cell_node:range()
  -- The stop column points at the first byte of the last character so
  -- consumers can treat it as an inclusive cursor position.
  local last_byte = leading + #trimmed
  local stop_col = sc + last_byte - 1 + vim.str_utf_start(text, last_byte)
  return {
    mode = 'char',
    start = { sr + 1, sc + leading },
    stop = { sr + 1, stop_col },
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
