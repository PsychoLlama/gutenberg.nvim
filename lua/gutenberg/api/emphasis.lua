---@class gutenberg.emphasis.Emphasis
---@field text string Emphasized text, with the surrounding `*`/`_` delimiters stripped.

local config = require('gutenberg.config')
local span = require('gutenberg.span')

---@class gutenberg.api.emphasis
---@field is_emphasis fun(ctx?: gutenberg.Context.Partial): boolean Whether the cursor is inside an emphasis span.
---@field read fun(ctx?: gutenberg.Context.Partial): gutenberg.emphasis.Emphasis, TSNode Read the emphasis at the cursor; errors when there is none.
---@field create fun(fields: { text: string }): gutenberg.emphasis.Emphasis Build an emphasis value from explicit fields.
---@field render fun(value: gutenberg.emphasis.Emphasis): string Render to markdown source, wrapping in the configured delimiter (`gutenberg.emphasis.Config.delimiter`, default `_`).
---@field replace fun(node: TSNode, values: gutenberg.emphasis.Emphasis[], ctx?: gutenberg.Context.Partial) Replace `node`'s range with the rendered values; `{}` deletes.
---@field get_text fun(value: gutenberg.emphasis.Emphasis): string
---@field set_text fun(value: gutenberg.emphasis.Emphasis, text: string)

---@type gutenberg.api.emphasis
local M = span.new_api({
  capture = 'emphasis',
  delimiter = 'emphasis_delimiter',
  noun = 'emphasis',
  render = function(text)
    local delimiter = config.get().emphasis.delimiter
    return delimiter .. text .. delimiter
  end,
  decode = function(raw)
    return raw
  end,
})

return M
