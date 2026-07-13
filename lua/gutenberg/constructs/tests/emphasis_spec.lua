local emphasis = require('gutenberg.constructs.emphasis')

local with_buffer = require('gutenberg.tests.utils').with_buffer

describe('gutenberg.emphasis', function()
  describe('wrap', function()
    it('wraps the charwise selection in `*`', function()
      with_buffer({ 'make this bold' }, { 1, 0 }, function(ctx)
        emphasis.wrap({
          bufnr = ctx.bufnr,
          range = { mode = 'char', start = { 1, 5 }, stop = { 1, 8 } },
        })
        assert.same(
          { 'make *this* bold' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('covers the full character at a multibyte stop', function()
      with_buffer({ 'see café here' }, { 1, 0 }, function(ctx)
        emphasis.wrap({
          bufnr = ctx.bufnr,
          range = { mode = 'char', start = { 1, 4 }, stop = { 1, 7 } },
        })
        assert.same(
          { 'see *café* here' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('errors without a charwise range', function()
      with_buffer({ 'text' }, { 1, 0 }, function(ctx)
        assert.error_matches(function()
          emphasis.wrap({
            bufnr = ctx.bufnr,
            range = { mode = 'line', start = { 1, 0 }, stop = { 1, 0 } },
          })
        end, 'wrapping emphasis requires a charwise selection')
      end)
    end)

    it('errors on a multiline range', function()
      with_buffer({ 'one', 'two' }, { 1, 0 }, function(ctx)
        assert.error_matches(function()
          emphasis.wrap({
            bufnr = ctx.bufnr,
            range = { mode = 'char', start = { 1, 0 }, stop = { 2, 1 } },
          })
        end, 'cannot wrap emphasis across multiple lines')
      end)
    end)
  end)

  describe('remove', function()
    it('replaces the span with its bare text', function()
      with_buffer({ 'a *em* b' }, { 1, 4 }, function(ctx)
        emphasis.remove(ctx)
        assert.same(
          { 'a em b' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('errors off a span', function()
      with_buffer({ 'plain' }, { 1, 0 }, function(ctx)
        assert.error_matches(function()
          emphasis.remove(ctx)
        end, 'cursor is not on emphasis')
      end)
    end)
  end)
end)
