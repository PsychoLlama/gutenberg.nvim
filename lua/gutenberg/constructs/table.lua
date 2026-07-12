---@alias gutenberg.table.Alignment 'none' | 'left' | 'center' | 'right'

---@class gutenberg.table.Table
---@field alignments gutenberg.table.Alignment[] Per-column alignment.
---@field headers string[] Header cell text, trimmed.
---@field rows string[][] Body cells, per row then per column, trimmed.

local buffer = require('gutenberg.buffer')
local context = require('gutenberg.context')
local ts = require('gutenberg.treesitter')

---@class gutenberg.table
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

  local headers = {}
  local alignments = {}
  local rows = {}

  for child in node:iter_children() do
    local t = child:type()
    if t == 'pipe_table_header' then
      headers = read_row_cells(child, ctx.bufnr)
    elseif t == 'pipe_table_delimiter_row' then
      for cell in child:iter_children() do
        if cell:type() == 'pipe_table_delimiter_cell' then
          table.insert(alignments, read_alignment(cell))
        end
      end
    elseif t == 'pipe_table_row' then
      table.insert(rows, read_row_cells(child, ctx.bufnr))
    end
  end

  return {
    alignments = alignments,
    headers = headers,
    rows = rows,
  },
    node
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

return M
