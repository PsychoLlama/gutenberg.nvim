--- Test support shared by the `*_spec.lua` suites. Internal — not part
--- of the public API.

---@class gutenberg.spec_utils
local M = {}

---@class gutenberg.spec_utils.BufferOpts
---@field expandtab? boolean Defaults to true.
---@field tabstop? integer Defaults to 2.

--- Run `fn` against a scratch markdown buffer containing `lines`, passing
--- a fully-resolved context. The buffer is deleted afterwards, pass or
--- fail. Indentation options are pinned so specs that derive behavior
--- from `&expandtab` / `&tabstop` are predictable across host
--- configurations.
---@param lines string[]
---@param cursor [integer, integer]
---@param fn fun(ctx: gutenberg.Context)
---@param opts? gutenberg.spec_utils.BufferOpts
function M.with_buffer(lines, cursor, fn, opts)
  opts = opts or {}
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[bufnr].filetype = 'markdown'
  vim.bo[bufnr].expandtab = opts.expandtab ~= false
  vim.bo[bufnr].tabstop = opts.tabstop or 2
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  local ok, err = pcall(fn, { bufnr = bufnr, cursor = cursor })
  vim.api.nvim_buf_delete(bufnr, { force = true })
  if not ok then
    error(err)
  end
end

return M
