---@class gutenberg
---@field code_block gutenberg.code_block
---@field config gutenberg.config
---@field heading gutenberg.heading
---@field link gutenberg.link
---@field list gutenberg.list
---@field table gutenberg.table
local M = {}

---@param opts? gutenberg.Config
function M.setup(opts)
  require('gutenberg.config').merge(opts)
end

-- Lazy submodule access. `require('gutenberg').list` resolves to
-- `require('gutenberg.list')` on first reference and caches the result
-- so startup pays no import cost for unused submodules.
setmetatable(M, {
  __index = function(self, key)
    local ok, mod = pcall(require, 'gutenberg.' .. key)
    if not ok then
      return nil
    end
    rawset(self, key, mod)
    return mod
  end,
})

return M
