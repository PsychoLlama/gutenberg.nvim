local tutor = require('gutenberg.tutor')

local BUFFER_NAME = 'gutenberg://tutor'

local function close_tutor()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_get_name(bufnr) == BUFFER_NAME then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end
end

describe('gutenberg.tutor', function()
  after_each(close_tutor)

  it('opens a markdown scratch buffer with the lessons', function()
    local bufnr = tutor.open()
    assert.equal(BUFFER_NAME, vim.api.nvim_buf_get_name(bufnr))
    assert.equal('markdown', vim.bo[bufnr].filetype)
    assert.equal('nofile', vim.bo[bufnr].buftype)

    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, 5, false)
    assert.truthy(table.concat(lines, '\n'):find('Gutenberg Tutor', 1, true))
  end)

  it('is callable as gutenberg.tutor()', function()
    local bufnr = require('gutenberg').tutor()
    assert.equal(BUFFER_NAME, vim.api.nvim_buf_get_name(bufnr))
  end)

  it('binds the tutor keymaps to the tutor buffer only', function()
    local bufnr = tutor.open()

    ---@param target integer
    ---@return table<string, true>
    local function buffer_maps(target)
      ---@type table<string, true>
      local lhs = {}
      for _, m in ipairs(vim.api.nvim_buf_get_keymap(target, 'n')) do
        lhs[m.lhs] = true
      end
      return lhs
    end

    assert.is_true(buffer_maps(bufnr)[']h'] == true)
    assert.is_true(buffer_maps(bufnr)['[h'] == true)

    local other = vim.api.nvim_create_buf(false, true)
    assert.is_nil(buffer_maps(other)[']h'])
    vim.api.nvim_buf_delete(other, { force = true })
  end)

  it('replaces a previous tutor buffer on reopen', function()
    local first = tutor.open()
    local second = tutor.open()
    assert.is_false(vim.api.nvim_buf_is_valid(first))
    assert.is_true(vim.api.nvim_buf_is_valid(second))
    assert.equal(BUFFER_NAME, vim.api.nvim_buf_get_name(second))
  end)
end)
