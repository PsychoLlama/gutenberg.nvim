---@alias gutenberg.code_block.Fence '`' | '~'

---@class gutenberg.code_block.CodeBlock
---@field indent string Leading whitespace before the opening fence (preserved verbatim).
---@field fence gutenberg.code_block.Fence
---@field fence_length integer Number of fence characters on the opening fence (>= 3).
---@field info_string string Everything after the opening fence, trimmed of trailing whitespace ('' if none).
---@field content string[] Code content, one entry per line, no trailing newline. Empty list = empty block.

local context = require('gutenberg.context')

local M = {}

--- Find the nearest `fenced_code_block` ancestor at the cursor, or nil.
---@param ctx gutenberg.Context
---@return TSNode?
local function find_fenced_code_block(ctx)
  local parser = vim.treesitter.get_parser(ctx.bufnr, 'markdown')
  if parser == nil then
    return nil
  end
  local tree = parser:parse()[1]
  local row = ctx.cursor[1] - 1
  local col = ctx.cursor[2]
  local node = tree:root():descendant_for_range(row, col, row, col)
  while node ~= nil do
    if node:type() == 'fenced_code_block' then
      return node
    end
    node = node:parent()
  end
  return nil
end

--- Locate the opening delimiter, optional info string, and closing delimiter
--- within a `fenced_code_block` node.
---@param node TSNode
---@return TSNode opening, TSNode? info, TSNode closing
local function find_parts(node)
  local opening, info, closing
  for child in node:iter_children() do
    local t = child:type()
    if t == 'fenced_code_block_delimiter' then
      if opening == nil then
        opening = child
      else
        closing = child
      end
    elseif t == 'info_string' then
      info = child
    end
  end
  if opening == nil or closing == nil then
    error('fenced_code_block is missing a delimiter')
  end
  return opening, info, closing
end

--- Whether the cursor is on a fenced code block. Gate calls to `read` with this.
---@param ctx? gutenberg.Context.Partial
---@return boolean
function M.is_code_block(ctx)
  return find_fenced_code_block(context.resolve(ctx)) ~= nil
end

--- Read the fenced code block containing the cursor. Errors if the cursor
--- isn't on a fenced code block; validate with `is_code_block` first. The
--- returned `TSNode` captures the block's range for `replace`.
---@param ctx? gutenberg.Context.Partial
---@return gutenberg.code_block.CodeBlock, TSNode
function M.read(ctx)
  ctx = context.resolve(ctx)
  local node = find_fenced_code_block(ctx)
  if node == nil then
    error('cursor is not on a fenced code block')
  end

  local opening, info, closing = find_parts(node)
  local open_row = opening:range()
  local close_row = closing:range()

  local opening_line = vim.api.nvim_buf_get_lines(
    ctx.bufnr,
    open_row,
    open_row + 1,
    false
  )[1] or ''

  local fence_start, _, fence_char = opening_line:find('([`~])')
  if fence_start == nil then
    error('fenced_code_block_delimiter has no fence character')
  end
  local indent = opening_line:sub(1, fence_start - 1)

  local fence_length = 0
  for i = fence_start, #opening_line do
    if opening_line:sub(i, i) == fence_char then
      fence_length = fence_length + 1
    else
      break
    end
  end

  local info_string = ''
  if info ~= nil then
    info_string = vim.treesitter.get_node_text(info, ctx.bufnr)
    info_string = info_string:gsub('%s+$', '')
  end

  local content = {}
  if close_row > open_row + 1 then
    content =
      vim.api.nvim_buf_get_lines(ctx.bufnr, open_row + 1, close_row, false)
  end

  return {
    indent = indent,
    fence = fence_char,
    fence_length = fence_length,
    info_string = info_string,
    content = content,
  },
    node
end

--- Construct a fenced code block from explicit fields. Missing fields fall
--- back to the configured defaults (see `gutenberg.setup`).
---@param fields { indent?: string, fence?: gutenberg.code_block.Fence, fence_length?: integer, info_string?: string, content?: string[] }
---@return gutenberg.code_block.CodeBlock
function M.create(fields)
  local code_block = require('gutenberg.config').get().code_block
  return {
    indent = fields.indent or '',
    fence = fields.fence or code_block.fence,
    fence_length = fields.fence_length or code_block.fence_length,
    info_string = fields.info_string or '',
    content = fields.content or {},
  }
end

--- Render a code block to buffer lines: opening fence, content, closing fence.
--- Content lines are emitted verbatim — they carry their own indentation and
--- are NOT auto-escalated when they look like a closing fence. Callers must
--- bump `fence_length` themselves when content contains a longer-or-equal run
--- of the fence character.
---@param block gutenberg.code_block.CodeBlock
---@return string[]
function M.render(block)
  local fence = block.fence:rep(block.fence_length)
  local lines = { block.indent .. fence .. block.info_string }
  for _, line in ipairs(block.content) do
    table.insert(lines, line)
  end
  table.insert(lines, block.indent .. fence)
  return lines
end

--- Replace `node`'s range with the rendered blocks in a single buffer update.
--- Pass an empty `blocks` list to delete the node.
---@param node TSNode
---@param blocks gutenberg.code_block.CodeBlock[]
---@param ctx? gutenberg.Context.Partial
function M.replace(node, blocks, ctx)
  ctx = context.resolve(ctx)
  local sr, _, er, ec = node:range()

  local lines = {}
  for _, block in ipairs(blocks) do
    for _, line in ipairs(M.render(block)) do
      table.insert(lines, line)
    end
  end

  -- A `fenced_code_block` range ends on the row after the closing delimiter
  -- when the buffer has a trailing newline; on the last block in the buffer
  -- it can end at (closing_row, closing_end_col). Clamp to the closing
  -- delimiter's row to avoid eating an unrelated following line.
  local end_row = er
  if ec ~= 0 then
    end_row = er + 1
  end

  vim.api.nvim_buf_set_lines(ctx.bufnr, sr, end_row, false, lines)
end

--- Get the info string on a block.
---@param block gutenberg.code_block.CodeBlock
---@return string
function M.get_info_string(block)
  return block.info_string
end

--- Set the info string on a block.
---@param block gutenberg.code_block.CodeBlock
---@param info_string string
function M.set_info_string(block, info_string)
  block.info_string = info_string
end

--- Get the content of a block as an array of lines.
---@param block gutenberg.code_block.CodeBlock
---@return string[]
function M.get_content(block)
  return block.content
end

--- Replace the content of a block with `lines`.
---@param block gutenberg.code_block.CodeBlock
---@param lines string[]
function M.set_content(block, lines)
  block.content = lines
end

--- Read the conventional language: the first whitespace-delimited token of
--- the info string. Returns `''` when the info string is empty.
---@param block gutenberg.code_block.CodeBlock
---@return string
function M.get_language(block)
  return block.info_string:match('^(%S+)') or ''
end

--- Replace the leading-language portion of the info string, preserving any
--- trailing attributes after the first whitespace.
---@param block gutenberg.code_block.CodeBlock
---@param language string
function M.set_language(block, language)
  local rest = block.info_string:match('^%S*(%s.*)$')
  if rest == nil then
    block.info_string = language
  else
    block.info_string = language .. rest
  end
end

return M
