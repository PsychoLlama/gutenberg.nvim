--- Treesitter plumbing shared by the feature modules. Node recognition is
--- declared in the `queries/{markdown,markdown_inline}/gutenberg.scm`
--- runtime query files; the helpers here resolve captures from those
--- queries to raw `TSNode`s. The feature modules translate nodes to and
--- from their value types. Internal — not part of the public API.

---@class gutenberg.treesitter
local M = {}

---@alias gutenberg.treesitter.Types string | table<string, true>

---@param types gutenberg.treesitter.Types
---@return table<string, true>
local function as_set(types)
  if type(types) == 'string' then
    return { [types] = true }
  end
  return types
end

--- Parsed `gutenberg` query for `lang`. Errors when no
--- `queries/<lang>/gutenberg.scm` exists on 'runtimepath' — that's a
--- broken install, not a recoverable state. Neovim caches the parse.
---@param lang string
---@return vim.treesitter.Query
local function get_query(lang)
  local query = vim.treesitter.query.get(lang, 'gutenberg')
  if query == nil then
    error(
      'gutenberg: queries/'
        .. lang
        .. '/gutenberg.scm not found on runtimepath',
      0
    )
  end
  return query
end

--- Numeric id of `capture` in `query`. Errors on unknown captures so a
--- user query that replaces ours (instead of `;; extends`-ing it) and
--- drops a capture fails loudly instead of silently disabling a module.
---@param query vim.treesitter.Query
---@param capture string
---@return integer
local function capture_id(query, capture)
  for id, name in ipairs(query.captures) do
    if name == capture then
      return id
    end
  end
  error('gutenberg: query has no @' .. capture .. ' capture', 0)
end

--- Innermost node captured as `id` whose range contains (row, col), with
--- the matching pattern's `#set!` metadata. Captured nodes containing a
--- common point always nest, so "innermost" is the node contained by
--- every other candidate.
---@param query vim.treesitter.Query
---@param id integer
---@param root TSNode
---@param bufnr integer
---@param row integer
---@param col integer
---@return TSNode?, vim.treesitter.query.TSMetadata?
local function capture_at(query, id, root, bufnr, row, col)
  ---@type TSNode?, vim.treesitter.query.TSMetadata?
  local best, best_metadata
  for cid, node, metadata in query:iter_captures(root, bufnr, row, row + 1) do
    if cid == id and vim.treesitter.is_in_node_range(node, row, col) then
      if
        best == nil or vim.treesitter.node_contains(best, { node:range() })
      then
        best, best_metadata = node, metadata
      end
    end
  end
  return best, best_metadata
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

--- Find the innermost block node captured as `capture` (in the markdown
--- query) at the cursor. The cursor counts as "on" a block anywhere on the
--- block's first row — including the leading whitespace, which sits
--- outside the block's range. When the direct probe misses or resolves to
--- a block starting above the cursor row, retry from the first non-blank
--- column of the cursor row and prefer that match.
---@param ctx gutenberg.Context
---@param capture string
---@return TSNode?
function M.find_at_cursor(ctx, capture)
  local root = M.root(ctx.bufnr)
  if root == nil then
    return nil
  end
  local query = get_query('markdown')
  local id = capture_id(query, capture)
  local row = ctx.cursor[1] - 1
  local col = ctx.cursor[2]

  local found = capture_at(query, id, root, ctx.bufnr, row, col)
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
  local retry = capture_at(query, id, root, ctx.bufnr, row, probe_col - 1)
  return retry or found
end

--- Find the innermost inline node captured as `capture` (in the
--- markdown_inline query) at the cursor, along with the matching pattern's
--- `#set!` metadata, searching the injected `markdown_inline` trees.
--- Inline constructs only span real text, so unlike `find_at_cursor` there
--- is no indent snapping.
---@param ctx gutenberg.Context
---@param capture string
---@return TSNode?, vim.treesitter.query.TSMetadata?
function M.find_inline_at_cursor(ctx, capture)
  local parser = vim.treesitter.get_parser(ctx.bufnr, 'markdown')
  if parser == nil then
    return nil
  end
  parser:parse(true)

  local query = get_query('markdown_inline')
  local id = capture_id(query, capture)
  local row = ctx.cursor[1] - 1
  local col = ctx.cursor[2]
  ---@type TSNode?, vim.treesitter.query.TSMetadata?
  local found, metadata
  parser:for_each_tree(function(tree, lt)
    if found ~= nil or lt:lang() ~= 'markdown_inline' then
      return
    end
    found, metadata = capture_at(query, id, tree:root(), ctx.bufnr, row, col)
  end)
  return found, metadata
end

--- Every node captured as `capture` when `lines` are parsed as a
--- standalone markdown document, in document order, along with the
--- concatenated source (pass it to `vim.treesitter.get_node_text`).
--- Node ranges are relative to `lines`. Powers transforms that must
--- inspect the tree a candidate edit WOULD produce before writing it.
---@param lines string[]
---@param capture string
---@return TSNode[], string source
function M.collect_in_lines(lines, capture)
  local source = table.concat(lines, '\n')
  local parser = vim.treesitter.get_string_parser(source, 'markdown')
  local root = parser:parse()[1]:root()
  local query = get_query('markdown')
  local id = capture_id(query, capture)
  ---@type TSNode[]
  local results = {}
  for cid, node in query:iter_captures(root, source) do
    if cid == id then
      table.insert(results, node)
    end
  end
  return results, source
end

--- Every node captured as `capture` in the buffer's markdown block tree,
--- in document order. Returns an empty list when no markdown parser is
--- available.
---@param bufnr integer
---@param capture string
---@return TSNode[]
function M.collect(bufnr, capture)
  local root = M.root(bufnr)
  if root == nil then
    return {}
  end
  local query = get_query('markdown')
  local id = capture_id(query, capture)
  ---@type TSNode[]
  local results = {}
  for cid, node in query:iter_captures(root, bufnr) do
    if cid == id then
      table.insert(results, node)
    end
  end
  return results
end

--- First direct child of `node` whose type is in `types`, or nil.
---@param node TSNode
---@param types gutenberg.treesitter.Types
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

--- The last row owned by `node` that holds non-whitespace text
--- (inclusive), or the node's start row when every row is blank.
--- `list` / `list_item` ranges greedily extend into trailing blank
--- lines (and past EOF on the last item); clamp writes with this so
--- they never touch rows the construct doesn't really own.
---@param node TSNode
---@param bufnr integer
---@return integer
function M.content_end(node, bufnr)
  local sr = node:range()
  local lines = vim.api.nvim_buf_get_lines(bufnr, sr, M.end_row(node), false)
  for i = #lines, 1, -1 do
    if lines[i]:match('%S') ~= nil then
      return sr + i - 1
    end
  end
  return sr
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
