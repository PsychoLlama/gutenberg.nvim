---@class gutenberg.api
---@field code_block gutenberg.api.code_block
---@field code_span gutenberg.api.code_span
---@field emphasis gutenberg.api.emphasis
---@field heading gutenberg.api.heading
---@field link gutenberg.api.link
---@field list gutenberg.api.list
---@field strikethrough gutenberg.api.strikethrough
---@field strong gutenberg.api.strong
---@field table gutenberg.api.table
local M = {}

-- Lazy submodule access, mirroring the root namespace:
-- `require('gutenberg.api').list` resolves to
-- `require('gutenberg.api.list')` on first reference and caches the
-- result so importing the api surface pays no cost for unused modules.
setmetatable(M, {
  __index = function(self, key)
    local name = 'gutenberg.api.' .. key
    local ok, mod = pcall(require, name)
    if not ok then
      -- Only a genuinely missing module resolves to nil; a module that
      -- exists but fails to load propagates its error.
      if
        type(mod) == 'string'
        and mod:find("module '" .. name .. "' not found", 1, true) ~= nil
      then
        return nil
      end
      error(mod, 0)
    end
    rawset(self, key, mod)
    return mod
  end,
})

return M
