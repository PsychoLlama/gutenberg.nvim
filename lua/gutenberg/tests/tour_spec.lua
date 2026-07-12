local tour = require('gutenberg.tour')

local BUFFER_NAME = 'gutenberg://tour'

local function close_tour()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_get_name(bufnr) == BUFFER_NAME then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end
end

describe('gutenberg.tour', function()
  after_each(close_tour)

  it('opens a markdown scratch buffer with the tour document', function()
    local bufnr = tour.open()
    assert.equal(BUFFER_NAME, vim.api.nvim_buf_get_name(bufnr))
    assert.equal('markdown', vim.bo[bufnr].filetype)
    assert.equal('nofile', vim.bo[bufnr].buftype)

    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, 5, false)
    assert.truthy(table.concat(lines, '\n'):find('Gutenberg Tour', 1, true))
  end)

  it('is callable as gutenberg.tour()', function()
    local bufnr = require('gutenberg').tour()
    assert.equal(BUFFER_NAME, vim.api.nvim_buf_get_name(bufnr))
  end)

  it('binds the tour keymaps to the tour buffer only', function()
    local bufnr = tour.open()

    ---@param target integer
    ---@param mode string
    ---@return table<string, true>
    local function buffer_maps(target, mode)
      ---@type table<string, true>
      local lhs = {}
      for _, m in ipairs(vim.api.nvim_buf_get_keymap(target, mode)) do
        lhs[m.lhs] = true
      end
      return lhs
    end

    assert.is_true(buffer_maps(bufnr, 'n')[']E'] == true)
    assert.is_true(buffer_maps(bufnr, 'n')['[E'] == true)

    local other = vim.api.nvim_create_buf(false, true)
    assert.is_nil(buffer_maps(other, 'n')[']E'])
    vim.api.nvim_buf_delete(other, { force = true })
  end)

  it('binds motions, edits, and textobjects in the right modes', function()
    local bufnr = tour.open()

    ---@param mode string
    ---@return table<string, true>
    local function maps(mode)
      ---@type table<string, true>
      local lhs = {}
      for _, m in ipairs(vim.api.nvim_buf_get_keymap(bufnr, mode)) do
        -- get_keymap escapes a literal `<` as `<lt>`; undo that so
        -- expectations read naturally.
        lhs[m.lhs:gsub('<lt>', '<')] = true
      end
      return lhs
    end

    -- Motions land in normal, visual, and operator-pending modes.
    for _, mode in ipairs({ 'n', 'x', 'o' }) do
      for _, lhs in ipairs({ ']E', '[E', ']e', '[e' }) do
        assert.is_true(maps(mode)[lhs] == true, mode .. ' ' .. lhs)
      end
    end

    -- The inner-cell textobject is visual + operator-pending only.
    assert.is_true(maps('x')['i|'] == true)
    assert.is_true(maps('o')['i|'] == true)
    assert.is_nil(maps('n')['i|'])

    -- Edits bind normal + visual.
    local leader = vim.g.mapleader or '\\'
    for _, suffix in ipairs({ 'm<', 'm>', 'mx', 'ma', 'ml', 'mc' }) do
      assert.is_true(maps('n')[leader .. suffix] == true, 'n ' .. suffix)
      assert.is_true(maps('x')[leader .. suffix] == true, 'x ' .. suffix)
    end

    -- Normal-mode-only binds.
    for _, suffix in ipairs({ 'mf', 'mt', 'mL', 'mo', 'mO' }) do
      assert.is_true(maps('n')[leader .. suffix] == true, 'n ' .. suffix)
      assert.is_nil(maps('x')[leader .. suffix], 'x ' .. suffix)
    end
  end)

  it('cannot undo past the pristine document', function()
    local bufnr = tour.open()
    local pristine = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

    vim.api.nvim_buf_call(bufnr, function()
      vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, { 'edited' })
      vim.cmd('silent! undo')
      vim.cmd('silent! undo')
    end)

    assert.same(pristine, vim.api.nvim_buf_get_lines(bufnr, 0, -1, false))
  end)

  it('replaces a previous tour buffer on reopen', function()
    local first = tour.open()
    local second = tour.open()
    assert.is_false(vim.api.nvim_buf_is_valid(first))
    assert.is_true(vim.api.nvim_buf_is_valid(second))
    assert.equal(BUFFER_NAME, vim.api.nvim_buf_get_name(second))
  end)
end)
