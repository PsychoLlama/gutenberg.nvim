---@class gutenberg.strong.Strong
---@field text string Bold text, with the surrounding `**`/`__` delimiters stripped.

local config = require('gutenberg.config')
local span = require('gutenberg.span')

---@class gutenberg.api.strong
---@field is_strong fun(ctx?: gutenberg.Context.Partial): boolean Whether the cursor is inside a strong emphasis span.
---@field read fun(ctx?: gutenberg.Context.Partial): gutenberg.strong.Strong, TSNode Read the strong emphasis at the cursor; errors when there is none.
---@field create fun(fields: { text: string }): gutenberg.strong.Strong Build a strong value from explicit fields.
---@field render fun(value: gutenberg.strong.Strong): string Render to markdown source, wrapping in the configured delimiter (`gutenberg.strong.Config.delimiter`, default `**`).
---@field replace fun(node: TSNode, values: gutenberg.strong.Strong[], ctx?: gutenberg.Context.Partial) Replace `node`'s range with the rendered values; `{}` deletes.
---@field get_text fun(value: gutenberg.strong.Strong): string
---@field set_text fun(value: gutenberg.strong.Strong, text: string)

---@type gutenberg.api.strong
local M = span.new_api({
  capture = 'strong',
  delimiter = 'emphasis_delimiter',
  noun = 'strong emphasis',
  render = function(text)
    local delimiter = config.get().strong.delimiter
    return delimiter .. text .. delimiter
  end,
  decode = function(raw)
    return raw
  end,
})

return M
