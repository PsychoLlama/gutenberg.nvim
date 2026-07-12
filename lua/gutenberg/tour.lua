--- `gutenberg.tour()` — an interactive tour of the plugin, in the
--- spirit of `:Tutor`. Opens the shipped tour document in a listed
--- scratch buffer and binds the recommended keymaps (see
--- `:h gutenberg-recommended-config`) to that buffer alone, so the
--- tour works even in a bare config.

local BUFFER_NAME = 'gutenberg://tour'

---@class gutenberg.tour
---@overload fun(): integer
local M = {}

--- The tour IS the recommended config, scoped to the tour buffer.
--- Keep this in sync with the RECOMMENDED CONFIG snippet in
--- doc/gutenberg.txt (`:h gutenberg-recommended-config`).
---@param bufnr integer
local function apply_keymaps(bufnr)
  local gutenberg = require('gutenberg')
  local keymap = gutenberg.keymap

  -- A cursor motion: count-aware, usable as an operator target.
  ---@param lhs string
  ---@param fn fun(ctx: gutenberg.Context.Partial)
  ---@param desc string
  local function motion(lhs, fn, desc)
    vim.keymap.set({ 'n', 'x', 'o' }, lhs, function()
      keymap.notify(function()
        fn({ count = vim.v.count1 })
      end)
    end, { buffer = bufnr, desc = 'gutenberg: ' .. desc })
  end

  -- An edit: count + `.`-repeat in normal mode, bulk over the
  -- selection in visual mode.
  ---@param lhs string
  ---@param fn fun(ctx: gutenberg.Context.Partial)
  ---@param desc string
  local function edit(lhs, fn, desc)
    vim.keymap.set('n', lhs, keymap.repeatable(fn), {
      buffer = bufnr,
      expr = true,
      desc = 'gutenberg: ' .. desc,
    })
    vim.keymap.set('x', lhs, keymap.visual(fn), {
      buffer = bufnr,
      desc = 'gutenberg: ' .. desc,
    })
  end

  -- Motions
  motion(']h', gutenberg.heading.next, 'next heading')
  motion('[h', gutenberg.heading.prev, 'previous heading')
  motion(']t', gutenberg.table.next_table, 'next table')
  motion('[t', gutenberg.table.prev_table, 'previous table')
  motion(']|', gutenberg.table.next_cell, 'next table cell')
  motion('[|', gutenberg.table.prev_cell, 'previous table cell')

  -- Inner-cell textobject. Off-table it errors before selecting,
  -- which cancels a pending operator and notifies.
  vim.keymap.set({ 'x', 'o' }, 'i|', function()
    keymap.notify(gutenberg.table.select_cell)
  end, { buffer = bufnr, desc = 'gutenberg: inner table cell' })

  -- Hierarchy: headings and list items share a depth axis.
  edit('<leader>m<', function(ctx)
    if gutenberg.api.heading.is_heading(ctx) then
      gutenberg.heading.promote(ctx)
    elseif gutenberg.api.list.is_list_item(ctx) then
      gutenberg.list.dedent(ctx)
    else
      error('gutenberg: no heading or list item under the cursor', 0)
    end
  end, 'promote heading / dedent list item')

  edit('<leader>m>', function(ctx)
    if gutenberg.api.heading.is_heading(ctx) then
      gutenberg.heading.demote(ctx)
    elseif gutenberg.api.list.is_list_item(ctx) then
      gutenberg.list.indent(ctx)
    else
      error('gutenberg: no heading or list item under the cursor', 0)
    end
  end, 'demote heading / indent list item')

  -- Lists
  edit('<leader>mx', gutenberg.list.toggle_checkbox, 'toggle checkbox')
  vim.keymap.set('n', '<leader>mo', function()
    keymap.notify(gutenberg.list.toggle_ordered_list)
  end, { buffer = bufnr, desc = 'gutenberg: toggle ordered list' })
  vim.keymap.set(
    'x',
    '<leader>mo',
    keymap.visual(gutenberg.list.toggle_ordered),
    { buffer = bufnr, desc = 'gutenberg: toggle ordered' }
  )

  -- Tables
  vim.keymap.set('n', '<leader>mf', function()
    keymap.notify(gutenberg.table.format)
  end, { buffer = bufnr, desc = 'gutenberg: format table' })
  vim.keymap.set(
    'n',
    '<leader>ma',
    keymap.repeatable(gutenberg.table.cycle_alignment),
    { buffer = bufnr, expr = true, desc = 'gutenberg: cycle alignment' }
  )
  vim.keymap.set('n', '<leader>mt', function()
    keymap.notify(gutenberg.table.actions)
  end, { buffer = bufnr, desc = 'gutenberg: table actions' })

  -- Links: wrap a motion or selection, prompting for the URL.
  ---@param ctx gutenberg.Context.Partial
  local function wrap_link(ctx)
    vim.ui.input({ prompt = 'URL: ' }, function(input)
      if input == nil then
        return
      end
      keymap.notify(function()
        gutenberg.link.wrap({ url = input }, ctx)
      end)
    end)
  end

  vim.keymap.set('n', '<leader>ml', keymap.operator(wrap_link), {
    buffer = bufnr,
    expr = true,
    desc = 'gutenberg: wrap motion in link',
  })
  vim.keymap.set('x', '<leader>ml', keymap.visual(wrap_link), {
    buffer = bufnr,
    desc = 'gutenberg: wrap selection in link',
  })
  vim.keymap.set(
    'n',
    '<leader>mL',
    keymap.repeatable(gutenberg.link.remove),
    {
      buffer = bufnr,
      expr = true,
      desc = 'gutenberg: remove link',
    }
  )

  -- Code blocks: insert an empty block, or fence the selection.
  vim.keymap.set('n', '<leader>mc', function()
    keymap.notify(gutenberg.code_block.insert)
  end, { buffer = bufnr, desc = 'gutenberg: insert code block' })
  vim.keymap.set(
    'x',
    '<leader>mc',
    keymap.visual(gutenberg.code_block.wrap),
    { buffer = bufnr, desc = 'gutenberg: fence selection' }
  )
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
