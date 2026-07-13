--- `gutenberg.tour()` — an interactive tour of the plugin, in the
--- spirit of `:Tutor`. Opens the shipped tour document in a listed
--- scratch buffer and binds the recommended keymaps (see
--- `:h gutenberg-recommended-config`) to that buffer alone, so the
--- tour works even in a bare config.

local BUFFER_NAME = 'gutenberg://tour'

---@class gutenberg.tour
---@overload fun(): integer
local M = {}

--- Open the tour in the current window. Any previous tour buffer is
--- replaced with a fresh copy of the document. Returns the tour
--- buffer number.
---@return integer
function M.open()
  local path =
    vim.api.nvim_get_runtime_file('doc/gutenberg-tour.md', false)[1]
  if path == nil then
    error("gutenberg: doc/gutenberg-tour.md not found on 'runtimepath'", 0)
  end

  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_get_name(bufnr) == BUFFER_NAME then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end

  local bufnr = vim.api.nvim_create_buf(true, true)
  vim.api.nvim_buf_set_name(bufnr, BUFFER_NAME)

  -- Load the document with undo recording off (:h clear-undo) so
  -- undoing all the way back stops at the pristine tour instead of a
  -- blank buffer.
  vim.api.nvim_buf_call(bufnr, function()
    vim.cmd('setlocal undolevels=-1')
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.fn.readfile(path))
    vim.cmd('set undolevels<')
  end)

  vim.bo[bufnr].filetype = 'markdown'
  -- Bind the recommended keymaps to the tour buffer explicitly, so the
  -- tour works even when `default_keymaps.enable` is off.
  require('gutenberg.default_keymaps').apply(bufnr)
  vim.api.nvim_win_set_buf(0, bufnr)
  return bufnr
end

setmetatable(M, {
  __call = function()
    return M.open()
  end,
})

return M
