--- Cursor-level sugar over `gutenberg.api.code_block`. Every verb here
--- composes the low-level primitives (read → mutate → replace) and
--- errors with UI-ready messages, so keymap edges can `pcall` + notify
--- directly. Drop down to `require('gutenberg.api').code_block` for
--- the primitives themselves.

local api = require('gutenberg.api.code_block')
local buffer = require('gutenberg.buffer')
local context = require('gutenberg.context')

---@class gutenberg.code_block
local M = {}

--- Insert an empty fenced code block (the configured fence, no info
--- string) at the cursor: a blank cursor row is replaced by the block,
--- any other row gets the block spliced below it. Returns the inserted
--- block.
---@param ctx? gutenberg.Context.Partial
---@return gutenberg.code_block.CodeBlock inserted
function M.insert(ctx)
  ctx = context.resolve(ctx)
  local row = ctx.cursor[1] - 1
  local line = vim.api.nvim_buf_get_lines(ctx.bufnr, row, row + 1, false)[1]
    or ''

  local block = api.create({})
  local lines = api.render(block)
  if line:match('%S') == nil then
    buffer.set_lines(ctx.bufnr, row, row + 1, lines)
  else
    buffer.set_lines(ctx.bufnr, row + 1, row + 1, lines)
  end
  return block
end

--- Wrap buffer rows in a fenced code block: the linewise `ctx.range`
--- when given, otherwise the cursor row plus the next `ctx.count - 1`
--- rows. The fence length auto-escalates past any fence run the
--- content could close early. No info string, single buffer update.
--- Returns the written block. Errors on charwise ranges — fences are
--- line constructs.
---@param ctx? gutenberg.Context.Partial
---@return gutenberg.code_block.CodeBlock written
function M.wrap(ctx)
  ctx = context.resolve(ctx)

  local start_row, stop_row
  if ctx.range ~= nil then
    if ctx.range.mode ~= 'line' then
      error('gutenberg: can only wrap whole lines in a code block', 0)
    end
    start_row = ctx.range.start[1] - 1
    stop_row = ctx.range.stop[1] - 1
  else
    start_row = ctx.cursor[1] - 1
    stop_row = start_row + ctx.count - 1
  end

  local content =
    vim.api.nvim_buf_get_lines(ctx.bufnr, start_row, stop_row + 1, false)
  local block = api.create({ content = content })

  -- A content line opening with >= fence_length fence characters (a
  -- closing fence allows up to 3 columns of indent) would terminate
  -- the block early; outgrow the longest such run.
  for _, text in ipairs(content) do
    local run = text:match('^ ? ? ?(' .. block.fence .. '+)')
    if run ~= nil and #run >= block.fence_length then
      block.fence_length = #run + 1
    end
  end

  buffer.set_lines(
    ctx.bufnr,
    start_row,
    start_row + #content,
    api.render(block)
  )
  return block
end

--- Read the code block at the cursor, apply `fn`, and write the result
--- back in a single buffer update. `fn` may mutate the block in place
--- (and return nothing) or return a replacement list — return `{}` to
--- delete the block. Errors if the cursor isn't on a fenced code
--- block.
---@param fn fun(block: gutenberg.code_block.CodeBlock): gutenberg.code_block.CodeBlock[]?
---@param ctx? gutenberg.Context.Partial
---@return gutenberg.code_block.CodeBlock[] written
function M.update(fn, ctx)
  ctx = context.resolve(ctx)
  local block, node = api.read(ctx)
  local blocks = fn(block) or { block }
  api.replace(node, blocks, ctx)
  return blocks
end

return M
