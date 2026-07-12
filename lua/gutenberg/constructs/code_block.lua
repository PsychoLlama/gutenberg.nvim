---@alias gutenberg.code_block.Fence '`' | '~'

---@class gutenberg.code_block.CodeBlock
---@field indent string Leading whitespace before the opening fence (preserved verbatim).
---@field fence gutenberg.code_block.Fence
---@field fence_length integer Number of fence characters on the opening fence (>= 3).
---@field info_string string Everything after the opening fence, trimmed of trailing whitespace ('' if none).
---@field content string[] Code content, one entry per line, no trailing newline. Empty list = empty block.

local buffer = require('gutenberg.buffer')
local context = require('gutenberg.context')
local ts = require('gutenberg.treesitter')

---@class gutenberg.code_block
local M = {}

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
    error('gutenberg: fenced_code_block is missing a delimiter', 0)
  end
  return opening, info, closing
end

--- Whether the cursor is on a fenced code block. Gate calls to `read` with this.
---@param ctx? gutenberg.Context.Partial
---@return boolean
function M.is_code_block(ctx)
  return ts.find_at_cursor(context.resolve(ctx), 'code_block') ~= nil
end

--- Read the fenced code block containing the cursor. Errors if the cursor
--- isn't on a fenced code block; validate with `is_code_block` first. The
--- returned `TSNode` captures the block's range for `replace`.
---@param ctx? gutenberg.Context.Partial
---@return gutenberg.code_block.CodeBlock, TSNode
function M.read(ctx)
  ctx = context.resolve(ctx)
  local node = ts.find_at_cursor(ctx, 'code_block')
  if node == nil then
    error('gutenberg: cursor is not on a fenced code block', 0)
  end

  local opening, info, closing = find_parts(node)
  local open_row, _, _, open_end_col = opening:range()
  local close_row = closing:range()

  local opening_line = vim.api.nvim_buf_get_lines(
    ctx.bufnr,
    open_row,
    open_row + 1,
    false
  )[1] or ''

  -- The delimiter node's range covers everything before the fence run —
  -- leading indent, and container prefixes like `> ` — so split the two
  -- apart; only the end column marks where the fence stops.
  local indent, fence_run =
    opening_line:sub(1, open_end_col):match('^(.-)([`~]+)$')
  if fence_run == nil then
    error('gutenberg: fenced_code_block_delimiter has no fence character', 0)
  end
  local fence_char = fence_run:sub(1, 1)
  local fence_length = #fence_run

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
  local sr = node:range()

  local lines = {}
  for _, block in ipairs(blocks) do
    for _, line in ipairs(M.render(block)) do
      table.insert(lines, line)
    end
  end

  buffer.set_lines(ctx.bufnr, sr, ts.end_row(node), lines)
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
