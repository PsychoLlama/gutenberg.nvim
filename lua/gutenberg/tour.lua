--- `gutenberg.tour()` — an interactive tour of the plugin, in the
--- spirit of `:Tutor`. Opens the shipped tour document in a listed
--- scratch buffer and binds the recommended keymaps (see
--- `:h gutenberg-recommended-config`) to that buffer alone, so the
--- tour works even in a bare config.

local BUFFER_NAME = 'gutenberg://tour'

---@class gutenberg.tour
---@overload fun(): integer
local M = {}

--- The tour buffer is plugin-owned UI — the one place gutenberg is
--- its own keymap edge, so errors surface through vim.notify here
--- instead of propagating to a caller.
---@param fn fun()
local function notify_errors(fn)
  local ok, err = pcall(fn)
  if not ok then
    vim.notify(tostring(err), vim.log.levels.WARN)
  end
end

---@param node TSNode?
local function jump_to(node)
  if node == nil then
    return
  end
  local row, col = node:range()
  vim.api.nvim_win_set_cursor(0, { row + 1, col })
end

---@param bufnr integer
local function apply_keymaps(bufnr)
  local gutenberg = require('gutenberg')

  ---@param lhs string
  ---@param fn fun()
  ---@param desc string
  local function map(lhs, fn, desc)
    vim.keymap.set('n', lhs, function()
      notify_errors(fn)
    end, { buffer = bufnr, desc = 'gutenberg: ' .. desc, silent = true })
  end

  map(']h', function()
    local _, node = gutenberg.api.heading.find_next()
    jump_to(node)
  end, 'next heading')

  map('[h', function()
    local _, node = gutenberg.api.heading.find_prev()
    jump_to(node)
  end, 'previous heading')

  map('<leader>m<', function()
    if gutenberg.api.heading.is_heading() then
      gutenberg.heading.promote()
    elseif gutenberg.api.list.is_list_item() then
      local _, node = gutenberg.api.list.read()
      gutenberg.api.list.dedent(node)
    else
      error('gutenberg: no heading or list item under the cursor', 0)
    end
  end, 'promote heading / dedent list item')

  map('<leader>m>', function()
    if gutenberg.api.heading.is_heading() then
      gutenberg.heading.demote()
    elseif gutenberg.api.list.is_list_item() then
      local _, node = gutenberg.api.list.read()
      gutenberg.api.list.indent(node)
    else
      error('gutenberg: no heading or list item under the cursor', 0)
    end
  end, 'demote heading / indent list item')

  map('<leader>mx', gutenberg.list.toggle_checkbox, 'toggle checkbox')
  map('<leader>mo', gutenberg.list.toggle_ordered_list, 'toggle ordered list')

  map('<leader>mf', gutenberg.table.format, 'format table')
  map('<leader>ma', gutenberg.table.cycle_alignment, 'cycle column alignment')

  map('<leader>me', function()
    if gutenberg.api.link.is_link() then
      local lnk = gutenberg.api.link.read()
      vim.ui.input({
        prompt = 'URL: ',
        default = gutenberg.api.link.get_url(lnk) or '',
      }, function(input)
        if input == nil then
          return
        end
        notify_errors(function()
          gutenberg.link.update(function(l)
            gutenberg.api.link.set_url(l, input)
          end)
        end)
      end)
    elseif gutenberg.api.code_block.is_code_block() then
      local block = gutenberg.api.code_block.read()
      vim.ui.input({
        prompt = 'Language: ',
        default = gutenberg.api.code_block.get_language(block),
      }, function(input)
        if input == nil then
          return
        end
        notify_errors(function()
          gutenberg.code_block.update(function(b)
            gutenberg.api.code_block.set_language(b, input)
          end)
        end)
      end)
    else
      error('gutenberg: no link or code block under the cursor', 0)
    end
  end, 'edit link URL / code block language')

  map('<leader>mE', function()
    local lnk = gutenberg.api.link.read()
    vim.ui.input({
      prompt = 'Text: ',
      default = gutenberg.api.link.get_text(lnk) or '',
    }, function(input)
      if input == nil then
        return
      end
      notify_errors(function()
        gutenberg.link.update(function(l)
          gutenberg.api.link.set_text(l, input)
        end)
      end)
    end)
  end, 'edit link text')
end

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
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.fn.readfile(path))
  vim.bo[bufnr].filetype = 'markdown'
  apply_keymaps(bufnr)
  vim.api.nvim_win_set_buf(0, bufnr)
  return bufnr
end

setmetatable(M, {
  __call = function()
    return M.open()
  end,
})

return M
