--- Treesitter plumbing shared by the feature modules. Everything here
--- deals in raw `TSNode`s; the feature modules translate nodes to and
--- from their value types. Internal — not part of the public API.

---@class gutenberg.ts
local M = {}

---@alias gutenberg.ts.Types string | table<string, true>

---@param types gutenberg.ts.Types
---@return table<string, true>
local function as_set(types)
  if type(types) == 'string' then
    return { [types] = true }
  end
  return types
end

--- Nearest ancestor of `node` (including itself) whose type is in `types`.
---@param node TSNode?
---@param types table<string, true>
---@return TSNode?
local function matching_ancestor(node, types)
  while node ~= nil do
    if types[node:type()] then
      return node
    end
    node = node:parent()
  end
  return nil
end

--- Root of the buffer's markdown block tree, or nil when no markdown
--- parser is available.
---@param bufnr integer
---@return TSNode?
function M.root(bufnr)
  local parser = vim.treesitter.get_parser(bufnr, 'markdown')
  if parser == nil then
    return nil
  end
  return parser:parse()[1]:root()
end

--- Find the nearest block node matching `types` at the cursor. The cursor
--- counts as "on" a block anywhere on the block's first row — including
--- the leading whitespace, which treesitter resolves to an enclosing node
--- (parent block, section, or document) rather than the block itself. When
--- the initial probe misses or lands on a block starting above the cursor
--- row, retry from the first non-blank column of the cursor row and prefer
--- that match.
---@param ctx gutenberg.Context
---@param types gutenberg.ts.Types
---@return TSNode?
function M.find_at_cursor(ctx, types)
  local root = M.root(ctx.bufnr)
  if root == nil then
    return nil
  end
  local set = as_set(types)
  local row = ctx.cursor[1] - 1
  local col = ctx.cursor[2]

  local found =
    matching_ancestor(root:descendant_for_range(row, col, row, col), set)
  if found ~= nil then
    local start_row = found:range()
    if start_row == row then
      return found
    end
  end

  local line = vim.api.nvim_buf_get_lines(ctx.bufnr, row, row + 1, false)[1]
    or ''
  local probe_col = line:find('%S')
  if probe_col == nil or probe_col - 1 == col then
    return found
  end
  local retry = matching_ancestor(
    root:descendant_for_range(row, probe_col - 1, row, probe_col - 1),
    set
  )
  return retry or found
end

--- Find the nearest inline node matching `types` at the cursor, searching
--- the injected `markdown_inline` trees. Inline constructs only span real
--- text, so unlike `find_at_cursor` there is no indent snapping.
---@param ctx gutenberg.Context
---@param types gutenberg.ts.Types
---@return TSNode?
function M.find_inline_at_cursor(ctx, types)
  local parser = vim.treesitter.get_parser(ctx.bufnr, 'markdown')
  if parser == nil then
    return nil
  end
  parser:parse(true)

  local set = as_set(types)
  local row = ctx.cursor[1] - 1
  local col = ctx.cursor[2]
  ---@type TSNode?
  local found
  parser:for_each_tree(function(tree, lt)
    if found ~= nil or lt:lang() ~= 'markdown_inline' then
      return
    end
    found = matching_ancestor(
      tree:root():descendant_for_range(row, col, row, col),
      set
    )
  end)
  return found
end

--- Every node under `node` whose type is in `types`, in document order.
--- Does not descend into matched nodes.
---@param node TSNode
---@param types gutenberg.ts.Types
---@return TSNode[]
function M.collect(node, types)
  local set = as_set(types)
  ---@type TSNode[]
  local results = {}
  ---@param n TSNode
  local function visit(n)
    if set[n:type()] then
      table.insert(results, n)
      return
    end
    for child in n:iter_children() do
      visit(child)
    end
  end
  visit(node)
  return results
end

--- First direct child of `node` whose type is in `types`, or nil.
---@param node TSNode
---@param types gutenberg.ts.Types
---@return TSNode?
function M.child(node, types)
  local set = as_set(types)
  for child in node:iter_children() do
    if set[child:type()] then
      return child
    end
  end
  return nil
end

--- Exclusive end row of `node` for `nvim_buf_set_lines`. Block ranges end
--- at column 0 of the row after the construct when a trailing newline
--- exists, and mid-row when the construct terminates the buffer without
--- one; both cases resolve to "one past the last owned row".
---@param node TSNode
---@return integer
function M.end_row(node)
  local _, _, er, ec = node:range()
  if ec == 0 then
    return er
  end
  return er + 1
end

--- The container prefix on `node`'s first row: the text in the columns
--- before the node's start, e.g. `> ` when the node sits inside a block
--- quote. Prepend it to rewritten lines so the container survives the
--- edit. Returns `''` for nodes starting at column 0.
---@param node TSNode
---@param bufnr integer
---@return string
function M.container_prefix(node, bufnr)
  local sr, sc = node:range()
  if sc == 0 then
    return ''
  end
  local first = vim.api.nvim_buf_get_lines(bufnr, sr, sr + 1, false)[1] or ''
  return first:sub(1, sc)
end

return M
