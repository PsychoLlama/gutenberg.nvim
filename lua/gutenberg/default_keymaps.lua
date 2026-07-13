--- The recommended keymaps as a real, requireable module — the
--- canonical source behind `:h gutenberg-recommended-config`. Opt in
--- through setup:
--- >lua
---   require('gutenberg').setup({
---     default_keymaps = { enable = true },
---   })
--- <
--- which binds `apply` below to the configured filetypes. The
--- interactive tour applies the same maps to its own buffer, and this
--- file doubles as the reference for hand-rolled configs: every
--- binding is a verb wrapped in a `gutenberg.keymap` adapter, so copy
--- what you want and adjust to taste.

---@class gutenberg.default_keymaps
local M = {}

--- Bind the full recommended set into one buffer (buffer-locally —
--- nothing global). Everything routes through the `gutenberg.keymap`
--- adapters, so edits get counts, `.`-repeat, and visual mode, and
--- failures surface as WARN notifications.
---@param bufnr integer
function M.apply(bufnr)
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
  -- ftplugin's `[[` / `]]` (see :h ft-markdown-plugin).
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
  edit('<leader>mX', gutenberg.list.remove_checkbox, 'remove checkbox')

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
  -- cycle a table column's alignment. On a list a plain press converts
  -- the whole sibling group; a visual selection converts just its
  -- items.
  edit('<leader>ma', function(ctx)
    if gutenberg.api.list.is_list_item(ctx) then
      if ctx.range ~= nil then
        gutenberg.list.toggle_ordered(ctx)
      else
        gutenberg.list.toggle_ordered_list(ctx)
      end
    elseif gutenberg.api.table.is_table(ctx) then
      gutenberg.table.cycle_alignment(ctx)
    else
      error('gutenberg: no list or table under the cursor', 0)
    end
  end, 'toggle ordered list / cycle column alignment')
  vim.keymap.set('n', '<leader>mt', function()
    keymap.notify(gutenberg.table.actions)
  end, { buffer = bufnr, desc = 'gutenberg: table actions' })

  -- Inline spans: wrap a motion (n) or selection (x) in delimiters.
  ---@param lhs string
  ---@param verb fun(ctx: gutenberg.Context.Partial)
  ---@param desc string
  local function wrap(lhs, verb, desc)
    vim.keymap.set('n', lhs, keymap.operator(verb), {
      buffer = bufnr,
      expr = true,
      desc = 'gutenberg: ' .. desc,
    })
    vim.keymap.set('x', lhs, keymap.visual(verb), {
      buffer = bufnr,
      desc = 'gutenberg: ' .. desc,
    })
  end

  -- Remove the span under the cursor (`.`-repeatable).
  ---@param lhs string
  ---@param verb fun(ctx: gutenberg.Context.Partial)
  ---@param desc string
  local function remove(lhs, verb, desc)
    vim.keymap.set('n', lhs, keymap.repeatable(verb), {
      buffer = bufnr,
      expr = true,
      desc = 'gutenberg: ' .. desc,
    })
  end

  -- Links prompt for the URL; the other spans wrap directly.
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
  wrap('<leader>ml', wrap_link, 'wrap in link')
  remove('<leader>mL', gutenberg.link.remove, 'remove link')

  wrap('<leader>me', gutenberg.emphasis.wrap, 'wrap in emphasis')
  remove('<leader>mE', gutenberg.emphasis.remove, 'remove emphasis')
  wrap('<leader>mb', gutenberg.strong.wrap, 'wrap in strong')
  remove('<leader>mB', gutenberg.strong.remove, 'remove strong')
  wrap('<leader>ms', gutenberg.strikethrough.wrap, 'wrap in strikethrough')
  remove('<leader>mS', gutenberg.strikethrough.remove, 'remove strikethrough')

  -- Code: a charwise motion/selection wraps an inline code span; a
  -- linewise one fences a code block. (`gutenberg.code_block.insert`
  -- has no binding — a blank-line linewise `<leader>mc` fences an empty
  -- block; bind `keymap.notify(gutenberg.code_block.insert)` for it.)
  ---@param ctx gutenberg.Context.Partial
  local function wrap_code(ctx)
    if ctx.range ~= nil and ctx.range.mode == 'line' then
      gutenberg.code_block.wrap(ctx)
    else
      gutenberg.code_span.wrap(ctx)
    end
  end
  wrap('<leader>mc', wrap_code, 'inline code / fence block')
  remove('<leader>mC', gutenberg.code_span.remove, 'remove code span')
end

--- Bind `apply` to the filetypes in `config.default_keymaps.filetypes`.
--- Called by `setup()` when `default_keymaps.enable` is set. Buffers
--- that already carry a matching filetype are bound immediately, so
--- enabling works no matter when setup runs — including plugin
--- managers that load gutenberg lazily on the FileType event.
function M.enable()
  local filetypes =
    require('gutenberg.config').get().default_keymaps.filetypes
  local group =
    vim.api.nvim_create_augroup('gutenberg.default_keymaps', { clear = true })

  vim.api.nvim_create_autocmd('FileType', {
    group = group,
    pattern = filetypes,
    desc = 'gutenberg: bind the recommended keymaps',
    callback = function(args)
      M.apply(args.buf)
    end,
  })

  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if
      vim.api.nvim_buf_is_loaded(bufnr)
      and vim.tbl_contains(filetypes, vim.bo[bufnr].filetype)
    then
      M.apply(bufnr)
    end
  end
end

return M
