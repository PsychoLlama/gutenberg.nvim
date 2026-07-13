local default_keymaps = require('gutenberg.default_keymaps')

local AUGROUP = 'gutenberg.default_keymaps'

---@param bufnr integer
---@param mode string
---@return table<string, true>
local function buffer_maps(bufnr, mode)
  ---@type table<string, true>
  local lhs = {}
  for _, m in ipairs(vim.api.nvim_buf_get_keymap(bufnr, mode)) do
    -- get_keymap escapes a literal `<` as `<lt>`; undo that so
    -- expectations read naturally.
    lhs[m.lhs:gsub('<lt>', '<')] = true
  end
  return lhs
end

---@param filetype string
---@return integer
local function scratch(filetype)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[bufnr].filetype = filetype
  return bufnr
end

describe('gutenberg.default_keymaps', function()
  ---@type integer[]
  local buffers = {}

  ---@param filetype string
  ---@return integer
  local function tracked_scratch(filetype)
    local bufnr = scratch(filetype)
    table.insert(buffers, bufnr)
    return bufnr
  end

  after_each(function()
    for _, bufnr in ipairs(buffers) do
      if vim.api.nvim_buf_is_valid(bufnr) then
        vim.api.nvim_buf_delete(bufnr, { force = true })
      end
    end
    buffers = {}
    pcall(vim.api.nvim_del_augroup_by_name, AUGROUP)
    require('gutenberg').setup()
  end)

  describe('apply', function()
    it('binds motions, edits, and textobjects in the right modes', function()
      local bufnr = tracked_scratch('markdown')
      default_keymaps.apply(bufnr)

      -- Motions land in normal, visual, and operator-pending modes.
      for _, mode in ipairs({ 'n', 'x', 'o' }) do
        for _, lhs in ipairs({ ']E', '[E', ']e', '[e' }) do
          assert.is_true(buffer_maps(bufnr, mode)[lhs] == true, mode .. lhs)
        end
      end

      -- The inner-cell textobject is visual + operator-pending only.
      assert.is_true(buffer_maps(bufnr, 'x')['i|'] == true)
      assert.is_true(buffer_maps(bufnr, 'o')['i|'] == true)
      assert.is_nil(buffer_maps(bufnr, 'n')['i|'])

      -- Edits and span wraps bind normal + visual.
      local leader = vim.g.mapleader or '\\'
      for _, suffix in ipairs({
        'm<',
        'm>',
        'mx',
        'mX',
        'ma',
        'ml',
        'me',
        'mb',
        'ms',
        'mc',
      }) do
        assert.is_true(
          buffer_maps(bufnr, 'n')[leader .. suffix],
          'n' .. suffix
        )
        assert.is_true(
          buffer_maps(bufnr, 'x')[leader .. suffix],
          'x' .. suffix
        )
      end

      -- Normal-mode-only binds (pickers, inserts, and span removals).
      for _, suffix in ipairs({
        'mf',
        'mt',
        'mL',
        'mE',
        'mB',
        'mS',
        'mC',
        'mo',
        'mO',
      }) do
        assert.is_true(
          buffer_maps(bufnr, 'n')[leader .. suffix],
          'n' .. suffix
        )
        assert.is_nil(
          buffer_maps(bufnr, 'x')[leader .. suffix],
          'x' .. suffix
        )
      end
    end)

    it('binds to the given buffer only', function()
      local bufnr = tracked_scratch('markdown')
      local other = tracked_scratch('markdown')
      default_keymaps.apply(bufnr)

      assert.is_true(buffer_maps(bufnr, 'n')[']E'] == true)
      assert.is_nil(buffer_maps(other, 'n')[']E'])
    end)
  end)

  it('dispatches <leader>mc to inline code or a fenced block', function()
    local saved = vim.g.mapleader
    vim.g.mapleader = ','
    local ok, err = pcall(function()
      local bufnr = tracked_scratch('markdown')
      default_keymaps.apply(bufnr)
      vim.api.nvim_win_set_buf(0, bufnr)

      local function feed(keys)
        vim.api.nvim_feedkeys(
          vim.api.nvim_replace_termcodes(keys, true, false, true),
          'x',
          false
        )
      end

      -- Charwise selection wraps an inline code span.
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { 'call foo now' })
      vim.api.nvim_win_set_cursor(0, { 1, 5 })
      feed('viw,mc')
      assert.same(
        { 'call `foo` now' },
        vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      )

      -- Linewise selection fences a code block.
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { 'plain line' })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      feed('V,mc')
      assert.same(
        { '```', 'plain line', '```' },
        vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      )
    end)
    vim.g.mapleader = saved
    assert.is_true(ok, tostring(err))
  end)

  describe('setup integration', function()
    it('does not bind anything by default', function()
      require('gutenberg').setup()
      local bufnr = tracked_scratch('markdown')
      assert.is_nil(buffer_maps(bufnr, 'n')[']E'])
    end)

    it('binds configured filetypes when enabled', function()
      require('gutenberg').setup({ default_keymaps = { enable = true } })

      local markdown = tracked_scratch('markdown')
      assert.is_true(buffer_maps(markdown, 'n')[']E'] == true)

      local unrelated = tracked_scratch('lua')
      assert.is_nil(buffer_maps(unrelated, 'n')[']E'])
    end)

    it('honors a custom filetype list', function()
      require('gutenberg').setup({
        default_keymaps = { enable = true, filetypes = { 'quarto' } },
      })

      local quarto = tracked_scratch('quarto')
      assert.is_true(buffer_maps(quarto, 'n')[']E'] == true)

      -- A custom list replaces the default one wholesale.
      local markdown = tracked_scratch('markdown')
      assert.is_nil(buffer_maps(markdown, 'n')[']E'])
    end)

    it('binds buffers whose filetype was set before setup ran', function()
      -- Lazy plugin managers load gutenberg during the FileType event,
      -- after the buffer already has its filetype.
      local bufnr = tracked_scratch('markdown')
      assert.is_nil(buffer_maps(bufnr, 'n')[']E'])

      require('gutenberg').setup({ default_keymaps = { enable = true } })
      assert.is_true(buffer_maps(bufnr, 'n')[']E'] == true)
    end)
  end)
end)
