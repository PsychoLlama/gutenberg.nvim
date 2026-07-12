---@class gutenberg.api
---@field code_block gutenberg.api.code_block
---@field heading gutenberg.api.heading
---@field link gutenberg.api.link
---@field list gutenberg.api.list
---@field table gutenberg.api.table
local M = {}

-- Lazy submodule access, mirroring the root namespace:
-- `require('gutenberg.api').list` resolves to
-- `require('gutenberg.api.list')` on first reference and caches the
-- result so importing the api surface pays no cost for unused modules.
setmetatable(M, {
  __index = function(self, key)
    local ok, mod = pcall(require, 'gutenberg.api.' .. key)
    if not ok then
      return nil
    end
    rawset(self, key, mod)
    return mod
  end,
})

return M
