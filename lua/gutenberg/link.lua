---@alias gutenberg.link.Kind 'inline' | 'reference_full' | 'reference_collapsed' | 'reference_shortcut' | 'autolink'

---@class gutenberg.link.Link
---@field kind gutenberg.link.Kind Discriminator for the variant fields.
---@field text string? Visible link text. nil for autolinks.
---@field url string? Destination URL. nil for reference_* (resolve via definitions).
---@field title string? Optional title. Inline links only.
---@field label string? Reference label. Set on reference_* kinds.

---@class gutenberg.link.Definition
---@field label string Reference label, brackets stripped, original case preserved.
---@field url string Destination URL.
---@field title string? Optional title, surrounding delimiters stripped.

local buffer = require('gutenberg.buffer')
local context = require('gutenberg.context')
local ts = require('gutenberg.ts')

---@class gutenberg.link
local M = {}

---@type table<string, true>
local LINK_NODE_TYPES = {
  inline_link = true,
  full_reference_link = true,
  collapsed_reference_link = true,
  shortcut_link = true,
  uri_autolink = true,
}

---@type table<string, gutenberg.link.Kind>
local NODE_TYPE_TO_KIND = {
  inline_link = 'inline',
  full_reference_link = 'reference_full',
  collapsed_reference_link = 'reference_collapsed',
  shortcut_link = 'reference_shortcut',
  uri_autolink = 'autolink',
}

--- Strip a single pair of matching surrounding delimiters from `text`.
--- Markdown link titles use any of `"..."`, `'...'`, or `(...)`. Treesitter
--- exposes the delimiters as part of the node, so we trim them here.
---@param text string
---@return string
local function strip_title_delimiters(text)
  local first = text:sub(1, 1)
  local last = text:sub(-1)
  if
    (first == '"' and last == '"')
    or (first == "'" and last == "'")
    or (first == '(' and last == ')')
  then
    return text:sub(2, -2)
  end
  return text
end

--- Strip the surrounding `[ ]` from a `link_label` node's text.
---@param text string
---@return string
local function strip_label_brackets(text)
  if text:sub(1, 1) == '[' and text:sub(-1) == ']' then
    return text:sub(2, -2)
  end
  return text
end

--- Normalize a reference label for matching per CommonMark §3.3: trim outer
--- whitespace, collapse internal whitespace runs to a single space, and
--- case-fold. Used as the dict key for both storing and looking up defs.
---@param label string
---@return string
local function normalize_label(label)
  return (vim.trim(label):gsub('%s+', ' ')):lower()
end

--- Strip the surrounding `< >` from a `uri_autolink` node's text.
---@param text string
---@return string
local function strip_autolink_angles(text)
  if text:sub(1, 1) == '<' and text:sub(-1) == '>' then
    return text:sub(2, -2)
  end
  return text
end

--- Read a `link_reference_definition` node into a Definition.
---@param node TSNode
---@param bufnr integer
---@return gutenberg.link.Definition
local function read_definition_node(node, bufnr)
  local label_node = ts.child(node, 'link_label')
  local dest_node = ts.child(node, 'link_destination')
  if label_node == nil or dest_node == nil then
    error('link_reference_definition is missing required children')
  end
  local label =
    strip_label_brackets(vim.treesitter.get_node_text(label_node, bufnr))
  local url = vim.treesitter.get_node_text(dest_node, bufnr)
  local title_node = ts.child(node, 'link_title')
  local title
  if title_node ~= nil then
    title =
      strip_title_delimiters(vim.treesitter.get_node_text(title_node, bufnr))
  end
  return { label = label, url = url, title = title }
end

--- Read a link node into a Link based on its type.
---@param node TSNode
---@param bufnr integer
---@return gutenberg.link.Link
local function read_link_node(node, bufnr)
  local type_ = node:type()
  local kind = NODE_TYPE_TO_KIND[type_]
  if kind == nil then
    error('node is not a link: ' .. type_)
  end

  if kind == 'autolink' then
    local url =
      strip_autolink_angles(vim.treesitter.get_node_text(node, bufnr))
    return { kind = kind, url = url }
  end

  local text_node = ts.child(node, 'link_text')
  if text_node == nil then
    error(type_ .. ' is missing link_text')
  end
  local text = vim.treesitter.get_node_text(text_node, bufnr)

  if kind == 'inline' then
    local dest_node = ts.child(node, 'link_destination')
    -- `[text]()` is legal markdown — destination may be absent.
    local url = ''
    if dest_node ~= nil then
      url = vim.treesitter.get_node_text(dest_node, bufnr)
    end
    local title_node = ts.child(node, 'link_title')
    local title
    if title_node ~= nil then
      title = strip_title_delimiters(
        vim.treesitter.get_node_text(title_node, bufnr)
      )
    end
    return { kind = kind, text = text, url = url, title = title }
  end

  if kind == 'reference_full' then
    local label_node = ts.child(node, 'link_label')
    if label_node == nil then
      error('full_reference_link is missing link_label')
    end
    local label =
      strip_label_brackets(vim.treesitter.get_node_text(label_node, bufnr))
    return { kind = kind, text = text, label = label }
  end

  -- collapsed and shortcut: label IS the text (case-insensitive lookup later).
  return { kind = kind, text = text, label = text }
end

--- Whether the cursor is inside a link node. Returns false on link reference
--- definitions and on images.
---@param ctx? gutenberg.Context.Partial
---@return boolean
function M.is_link(ctx)
  return ts.find_inline_at_cursor(context.resolve(ctx), LINK_NODE_TYPES)
    ~= nil
end

--- Read the link containing the cursor. Errors if the cursor isn't on a
--- link; validate with `is_link` first.
---@param ctx? gutenberg.Context.Partial
---@return gutenberg.link.Link, TSNode
function M.read(ctx)
  ctx = context.resolve(ctx)
  local node = ts.find_inline_at_cursor(ctx, LINK_NODE_TYPES)
  if node == nil then
    error('cursor is not on a link')
  end
  return read_link_node(node, ctx.bufnr), node
end

--- Whether the cursor is inside a link reference definition.
---@param ctx? gutenberg.Context.Partial
---@return boolean
function M.is_definition(ctx)
  return ts.find_at_cursor(context.resolve(ctx), 'link_reference_definition')
    ~= nil
end

--- Read the link reference definition containing the cursor. Errors if the
--- cursor isn't on a definition; validate with `is_definition` first.
---@param ctx? gutenberg.Context.Partial
---@return gutenberg.link.Definition, TSNode
function M.read_definition(ctx)
  ctx = context.resolve(ctx)
  local node = ts.find_at_cursor(ctx, 'link_reference_definition')
  if node == nil then
    error('cursor is not on a link reference definition')
  end
  return read_definition_node(node, ctx.bufnr), node
end

--- Collect every link reference definition in the buffer, keyed by the
--- lowercased label. Markdown labels are case-insensitive.
---@param ctx? gutenberg.Context.Partial
---@return table<string, gutenberg.link.Definition>
function M.definitions(ctx)
  ctx = context.resolve(ctx)
  ---@type table<string, gutenberg.link.Definition>
  local defs = {}
  local root = ts.root(ctx.bufnr)
  if root == nil then
    return defs
  end
  for _, node in ipairs(ts.collect(root, 'link_reference_definition')) do
    local def = read_definition_node(node, ctx.bufnr)
    defs[normalize_label(def.label)] = def
  end
  return defs
end

--- Resolve a reference_* link to its definition, or nil. Returns nil for
--- non-reference kinds (`inline`, `autolink`).
---@param link gutenberg.link.Link
---@param defs table<string, gutenberg.link.Definition>
---@return gutenberg.link.Definition?
function M.resolve(link, defs)
  if link.label == nil then
    return nil
  end
  return defs[normalize_label(link.label)]
end

--- Validate that `fields` contains the data required for `kind`.
---@param fields { kind: gutenberg.link.Kind, text?: string, url?: string, title?: string, label?: string }
local function validate_create(fields)
  local kind = fields.kind
  if kind == 'inline' then
    if fields.text == nil then
      error('inline links require `text`')
    end
    if fields.url == nil then
      error('inline links require `url`')
    end
  elseif kind == 'reference_full' then
    if fields.text == nil then
      error('reference_full links require `text`')
    end
    if fields.label == nil then
      error('reference_full links require `label`')
    end
  elseif kind == 'reference_collapsed' or kind == 'reference_shortcut' then
    if fields.text == nil then
      error(kind .. ' links require `text`')
    end
  elseif kind == 'autolink' then
    if fields.url == nil then
      error('autolinks require `url`')
    end
  else
    error('unknown link kind: ' .. tostring(kind))
  end
end

--- Construct a link from explicit fields. Validates that the required
--- fields for the chosen kind are present.
---@param fields { kind?: gutenberg.link.Kind, text?: string, url?: string, title?: string, label?: string }
---@return gutenberg.link.Link
function M.create(fields)
  local kind = fields.kind
    or require('gutenberg.config').get().link.default_kind
  ---@type { kind: gutenberg.link.Kind, text?: string, url?: string, title?: string, label?: string }
  local resolved = {
    kind = kind,
    text = fields.text,
    url = fields.url,
    title = fields.title,
    label = fields.label,
  }
  validate_create(resolved)

  if kind == 'inline' then
    return {
      kind = kind,
      text = resolved.text,
      url = resolved.url,
      title = resolved.title,
    }
  end
  if kind == 'reference_full' then
    return { kind = kind, text = resolved.text, label = resolved.label }
  end
  if kind == 'reference_collapsed' or kind == 'reference_shortcut' then
    return { kind = kind, text = resolved.text, label = resolved.text }
  end
  return { kind = kind, url = resolved.url }
end

--- Render a link to its literal markdown source. Special characters are NOT
--- escaped; callers feeding untrusted input must escape `[]()<>"` themselves.
---@param link gutenberg.link.Link
---@return string
function M.render(link)
  local kind = link.kind
  if kind == 'inline' then
    local text = link.text or ''
    local url = link.url or ''
    if link.title ~= nil then
      return '[' .. text .. '](' .. url .. ' "' .. link.title .. '")'
    end
    return '[' .. text .. '](' .. url .. ')'
  end
  if kind == 'reference_full' then
    return '[' .. (link.text or '') .. '][' .. (link.label or '') .. ']'
  end
  if kind == 'reference_collapsed' then
    return '[' .. (link.text or '') .. '][]'
  end
  if kind == 'reference_shortcut' then
    return '[' .. (link.text or '') .. ']'
  end
  if kind == 'autolink' then
    return '<' .. (link.url or '') .. '>'
  end
  error('unknown link kind: ' .. tostring(kind))
end

--- Replace `node`'s exact range with the rendered concatenation of `links`.
--- Pass an empty list to delete the link. Multiple links concatenate with no
--- separator; the caller adds spacing if needed.
---@param node TSNode
---@param links gutenberg.link.Link[]
---@param ctx? gutenberg.Context.Partial
function M.replace(node, links, ctx)
  ctx = context.resolve(ctx)
  local sr, sc, er, ec = node:range()
  local parts = {}
  for _, link in ipairs(links) do
    table.insert(parts, M.render(link))
  end
  local rendered = table.concat(parts, '')
  buffer.set_text(ctx.bufnr, sr, sc, er, ec, { rendered })
end

--- Get the URL of an inline or autolink link. Returns nil for reference_*
--- (resolve via definitions instead).
---@param link gutenberg.link.Link
---@return string?
function M.get_url(link)
  return link.url
end

--- Set the URL on an inline or autolink link. Errors on reference_* links —
--- those resolve through `link_reference_definition`s.
---@param link gutenberg.link.Link
---@param url string
function M.set_url(link, url)
  local kind = link.kind
  if kind == 'inline' or kind == 'autolink' then
    link.url = url
    return
  end
  error('cannot set url on ' .. kind .. ' link; use a definition instead')
end

--- Get the visible text of a link. Returns nil for autolinks.
---@param link gutenberg.link.Link
---@return string?
function M.get_text(link)
  return link.text
end

--- Set the visible text of a link. Errors on autolinks (no separate text
--- — the URL is the text).
---@param link gutenberg.link.Link
---@param text string
function M.set_text(link, text)
  if link.kind == 'autolink' then
    error('autolinks have no separate text')
  end
  link.text = text
  -- Collapsed/shortcut keep label === text. Update both so renders stay correct.
  if
    link.kind == 'reference_collapsed' or link.kind == 'reference_shortcut'
  then
    link.label = text
  end
end

--- Get the title on an inline link. Returns nil otherwise.
---@param link gutenberg.link.Link
---@return string?
function M.get_title(link)
  return link.title
end

--- Set the title on an inline link. Pass nil to remove. Errors on other
--- kinds — only inline links carry a title.
---@param link gutenberg.link.Link
---@param title string?
function M.set_title(link, title)
  if link.kind ~= 'inline' then
    error('only inline links support a title')
  end
  link.title = title
end

--- Get the reference label of a link. Returns nil for inline/autolink.
---@param link gutenberg.link.Link
---@return string?
function M.get_label(link)
  return link.label
end

--- Set the label on a reference_full link. Collapsed and shortcut links
--- derive their label from `text`; mutate via `set_text` instead.
---@param link gutenberg.link.Link
---@param label string
function M.set_label(link, label)
  if link.kind == 'reference_full' then
    link.label = label
    return
  end
  if
    link.kind == 'reference_collapsed' or link.kind == 'reference_shortcut'
  then
    error('label is derived from text on ' .. link.kind .. ' links')
  end
  error('cannot set label on ' .. link.kind .. ' link')
end

--- Get the link kind.
---@param link gutenberg.link.Link
---@return gutenberg.link.Kind
function M.get_kind(link)
  return link.kind
end

--- Mutate the kind of a link in place. The caller is responsible for
--- ensuring the link's other fields match the new kind's requirements.
---@param link gutenberg.link.Link
---@param kind gutenberg.link.Kind
function M.set_kind(link, kind)
  link.kind = kind
end

return M
