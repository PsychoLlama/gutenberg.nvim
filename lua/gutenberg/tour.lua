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

  -- Motions. Heading navigation is left to the builtin markdown
  -- ftplugin's `[[` / `]]`.
  motion(']E', gutenberg.table.next_table, 'next table')
  motion('[E', gutenberg.table.prev_table, 'previous table')
  motion(']e', gutenberg.table.next_cell, 'next table cell')
  motion('[e', gutenberg.table.prev_cell, 'previous table cell')

  -- Inner-cell textobject. Off-table it errors before selecting,
  -- which cancels a pending operator and notifies.
  vim.keymap.set({ 'x', 'o' }, 'i|', function()
    keymap.notify(gutenberg.table.select_cell)
  end, { buffer = bufnr, desc = 'gutenberg: inner table cell' })

  -- Hierarchy: headings, list items, and table columns share a
  -- left/right axis.
  edit('<leader>m<', function(ctx)
    if gutenberg.api.heading.is_heading(ctx) then
      gutenberg.heading.promote(ctx)
    elseif gutenberg.api.list.is_list_item(ctx) then
      gutenberg.list.dedent(ctx)
    elseif gutenberg.api.table.is_table(ctx) then
      gutenberg.table.move_column_left(ctx)
    else
      error('gutenberg: nothing under the cursor to shift left', 0)
    end
  end, 'promote heading / dedent item / move column left')

  edit('<leader>m>', function(ctx)
    if gutenberg.api.heading.is_heading(ctx) then
      gutenberg.heading.demote(ctx)
    elseif gutenberg.api.list.is_list_item(ctx) then
      gutenberg.list.indent(ctx)
    elseif gutenberg.api.table.is_table(ctx) then
      gutenberg.table.move_column_right(ctx)
    else
      error('gutenberg: nothing under the cursor to shift right', 0)
    end
  end, 'demote heading / indent item / move column right')

  -- Lists
  edit('<leader>mx', gutenberg.list.toggle_checkbox, 'toggle checkbox')

  -- Append / prepend a sibling — a list item or a table row, whichever
  -- is under the cursor — then drop into insert mode on it. Lists land
  -- at the end of the fresh marker (`startinsert!`); table cells land
  -- inside the first cell (`startinsert`).
  ---@param where 'above' | 'below'
  local function insert_sibling(where)
    return function()
      keymap.notify(function()
        local ctx = { count = vim.v.count1 }
        if gutenberg.api.list.is_list_item(ctx) then
          gutenberg.list.insert_item({ where = where }, ctx)
          vim.cmd('startinsert!')
        elseif gutenberg.api.table.is_table(ctx) then
          gutenberg.table.insert_row({ where = where }, ctx)
          vim.cmd('startinsert')
        else
          error('gutenberg: no list or table under the cursor', 0)
        end
      end)
    end
  end
  vim.keymap.set('n', '<leader>mo', insert_sibling('below'), {
    buffer = bufnr,
    desc = 'gutenberg: append item / row',
  })
  vim.keymap.set('n', '<leader>mO', insert_sibling('above'), {
    buffer = bufnr,
    desc = 'gutenberg: prepend item / row',
  })

  -- Tables
  vim.keymap.set('n', '<leader>mf', function()
    keymap.notify(gutenberg.table.format)
  end, { buffer = bufnr, desc = 'gutenberg: format table' })
  -- One binding for the "alignment axis": toggle a list ordered, or
  -- cycle a table column's alignment.
  edit('<leader>ma', function(ctx)
    if gutenberg.api.list.is_list_item(ctx) then
      gutenberg.list.toggle_ordered(ctx)
    elseif gutenberg.api.table.is_table(ctx) then
      gutenberg.table.cycle_alignment(ctx)
    else
      error('gutenberg: no list or table under the cursor', 0)
    end
  end, 'toggle ordered / cycle column alignment')
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

  -- Load the document with undo recording off (:h clear-undo) so
  -- undoing all the way back stops at the pristine tour instead of a
  -- blank buffer.
  vim.api.nvim_buf_call(bufnr, function()
    vim.cmd('setlocal undolevels=-1')
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.fn.readfile(path))
    vim.cmd('set undolevels<')
  end)

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
