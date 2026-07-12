---@class gutenberg
---@field code_block gutenberg.code_block
---@field config gutenberg.config
---@field health gutenberg.health
---@field heading gutenberg.heading
---@field link gutenberg.link
---@field list gutenberg.list
---@field table gutenberg.table
---@field tour gutenberg.tour
local M = {}

---@param opts? gutenberg.Config
function M.setup(opts)
  require('gutenberg.config').merge(opts)
end

-- Lazy submodule access. `require('gutenberg').list` resolves to
-- `require('gutenberg.constructs.list')` (falling back to
-- `require('gutenberg.<key>')` for non-construct modules) on first
-- reference and caches the result so startup pays no import cost for
-- unused submodules.
setmetatable(M, {
  __index = function(self, key)
    local ok, mod = pcall(require, 'gutenberg.constructs.' .. key)
    if not ok then
      ok, mod = pcall(require, 'gutenberg.' .. key)
    end
    if not ok then
      return nil
    end
    rawset(self, key, mod)
    return mod
  end,
})

return M
