---@class gutenberg
---@field api gutenberg.api
---@field code_block gutenberg.code_block
---@field config gutenberg.config
---@field health gutenberg.health
---@field heading gutenberg.heading
---@field keymap gutenberg.keymap
---@field link gutenberg.link
---@field list gutenberg.list
---@field table gutenberg.table
---@field tour gutenberg.tour
local M = {}

---@param opts? gutenberg.Config.Partial
function M.setup(opts)
  require('gutenberg.config').merge(opts)
end

--- Require `name`, returning nil when the module doesn't exist. A
--- module that exists but fails to load propagates its error — a
--- broken submodule must not masquerade as a missing one.
---@param name string
---@return unknown?
local function try_require(name)
  local ok, result = pcall(require, name)
  if ok then
    return result
  end
  if
    type(result) == 'string'
    and result:find("module '" .. name .. "' not found", 1, true) ~= nil
  then
    return nil
  end
  error(result, 0)
end

-- Lazy submodule access. `require('gutenberg').list` resolves to
-- `require('gutenberg.constructs.list')` — the cursor-level verbs —
-- falling back to `require('gutenberg.<key>')` for infrastructure
-- modules (including `gutenberg.api`, the low-level primitives). The
-- result is cached so startup pays no import cost for unused
-- submodules.
setmetatable(M, {
  __index = function(self, key)
    local mod = try_require('gutenberg.constructs.' .. key)
    if mod == nil then
      mod = try_require('gutenberg.' .. key)
    end
    if mod == nil then
      return nil
    end
    rawset(self, key, mod)
    return mod
  end,
})

return M
