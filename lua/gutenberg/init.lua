local M = {}

---@param opts? gutenberg.Config
function M.setup(opts)
  require('gutenberg.config').merge(opts)
end

return M
