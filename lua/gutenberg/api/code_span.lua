---@class gutenberg.code_span.CodeSpan
---@field text string Literal code, with the backtick delimiters and any CommonMark padding stripped.

local span = require('gutenberg.span')

--- Render code as an inline code span. The backtick run outgrows the
--- longest run inside the text (so it can't close early), and a single
--- space of padding is added when the text starts or ends with a backtick
--- or space — except for all-space text, which reads back verbatim.
---@param text string
---@return string
local function render(text)
  local longest = 0
  for run in text:gmatch('`+') do
    longest = math.max(longest, #run)
  end
  local fence = string.rep('`', longest + 1)

  local all_spaces = text ~= '' and text:match('^ +$') ~= nil
  local edge = text:match('^[` ]') ~= nil or text:match('[` ]$') ~= nil
  if text ~= '' and not all_spaces and edge then
    return fence .. ' ' .. text .. ' ' .. fence
  end
  return fence .. text .. fence
end

--- Invert the padding `render` adds: strip one leading and one trailing
--- space when both are present and the content is not all spaces.
---@param raw string
---@return string
local function decode(raw)
  if
    #raw >= 2
    and raw:sub(1, 1) == ' '
    and raw:sub(-1) == ' '
    and raw:match('[^ ]') ~= nil
  then
    return raw:sub(2, -2)
  end
  return raw
end

---@class gutenberg.api.code_span
---@field is_code_span fun(ctx?: gutenberg.Context.Partial): boolean Whether the cursor is inside an inline code span.
---@field read fun(ctx?: gutenberg.Context.Partial): gutenberg.code_span.CodeSpan, TSNode Read the code span at the cursor; errors when there is none.
---@field create fun(fields: { text: string }): gutenberg.code_span.CodeSpan Build a code span value from explicit fields.
---@field render fun(value: gutenberg.code_span.CodeSpan): string Render to markdown source, escalating backticks and padding as needed.
---@field replace fun(node: TSNode, values: gutenberg.code_span.CodeSpan[], ctx?: gutenberg.Context.Partial) Replace `node`'s range with the rendered values; `{}` deletes.
---@field get_text fun(value: gutenberg.code_span.CodeSpan): string
---@field set_text fun(value: gutenberg.code_span.CodeSpan, text: string)

---@type gutenberg.api.code_span
local M = span.new_api({
  capture = 'code_span',
  delimiter = 'code_span_delimiter',
  noun = 'a code span',
  render = render,
  decode = decode,
})

return M
