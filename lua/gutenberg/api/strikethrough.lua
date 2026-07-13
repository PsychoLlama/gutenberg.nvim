---@class gutenberg.strikethrough.Strikethrough
---@field text string Struck-through text, with the surrounding `~~` delimiters stripped.

local span = require('gutenberg.span')

---@class gutenberg.api.strikethrough
---@field is_strikethrough fun(ctx?: gutenberg.Context.Partial): boolean Whether the cursor is inside a strikethrough span.
---@field read fun(ctx?: gutenberg.Context.Partial): gutenberg.strikethrough.Strikethrough, TSNode Read the strikethrough at the cursor; errors when there is none.
---@field create fun(fields: { text: string }): gutenberg.strikethrough.Strikethrough Build a strikethrough value from explicit fields.
---@field render fun(value: gutenberg.strikethrough.Strikethrough): string Render to markdown source (`~~text~~`).
---@field replace fun(node: TSNode, values: gutenberg.strikethrough.Strikethrough[], ctx?: gutenberg.Context.Partial) Replace `node`'s range with the rendered values; `{}` deletes.
---@field get_text fun(value: gutenberg.strikethrough.Strikethrough): string
---@field set_text fun(value: gutenberg.strikethrough.Strikethrough, text: string)

---@type gutenberg.api.strikethrough
local M = span.new_api({
  capture = 'strikethrough',
  delimiter = 'emphasis_delimiter',
  noun = 'strikethrough',
  render = function(text)
    return '~~' .. text .. '~~'
  end,
  decode = function(raw)
    return raw
  end,
})

return M
