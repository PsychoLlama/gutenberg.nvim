local context = require('gutenberg.context')

describe('gutenberg.context', function()
  describe('resolve', function()
    it('defaults bufnr to the current buffer', function()
      local ctx = context.resolve()
      assert.equal(vim.api.nvim_get_current_buf(), ctx.bufnr)
    end)

    it('defaults cursor to the current window position', function()
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      local ctx = context.resolve()
      assert.same({ 1, 0 }, ctx.cursor)
    end)

    it('preserves bufnr when provided', function()
      local ctx = context.resolve({ bufnr = 42 })
      assert.equal(42, ctx.bufnr)
    end)

    it('preserves cursor when provided', function()
      local ctx = context.resolve({ cursor = { 5, 3 } })
      assert.same({ 5, 3 }, ctx.cursor)
    end)

    it('handles a nil argument', function()
      assert.has_no.error(function()
        context.resolve(nil)
      end)
    end)

    it('does not mutate the input', function()
      local input = { bufnr = 7 }
      context.resolve(input)
      assert.is_nil(input.cursor)
    end)

    it('returns a fresh table each call', function()
      local input = { bufnr = 7, cursor = { 1, 0 } }
      local a = context.resolve(input)
      local b = context.resolve(input)
      assert.are_not.equal(a, b)
      assert.are_not.equal(input, a)
    end)
  end)
end)
