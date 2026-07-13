local code_span = require('gutenberg.constructs.code_span')

local with_buffer = require('gutenberg.tests.utils').with_buffer

describe('gutenberg.code_span', function()
  describe('wrap', function()
    it('wraps the charwise selection in backticks', function()
      with_buffer({ 'call foo() now' }, { 1, 0 }, function(ctx)
        code_span.wrap({
          bufnr = ctx.bufnr,
          range = { mode = 'char', start = { 1, 5 }, stop = { 1, 9 } },
        })
        assert.same(
          { 'call `foo()` now' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('escalates the fence when the selection has a backtick', function()
      with_buffer({ 'the a`b token' }, { 1, 0 }, function(ctx)
        code_span.wrap({
          bufnr = ctx.bufnr,
          range = { mode = 'char', start = { 1, 4 }, stop = { 1, 6 } },
        })
        assert.same(
          { 'the ``a`b`` token' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('errors on a linewise range', function()
      with_buffer({ 'text' }, { 1, 0 }, function(ctx)
        assert.error_matches(function()
          code_span.wrap({
            bufnr = ctx.bufnr,
            range = { mode = 'line', start = { 1, 0 }, stop = { 1, 0 } },
          })
        end, 'wrapping a code span requires a charwise selection')
      end)
    end)
  end)

  describe('remove', function()
    it('replaces the span with its bare text', function()
      with_buffer({ 'a `code` b' }, { 1, 5 }, function(ctx)
        code_span.remove(ctx)
        assert.same(
          { 'a code b' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('errors off a span', function()
      with_buffer({ 'plain' }, { 1, 0 }, function(ctx)
        assert.error_matches(function()
          code_span.remove(ctx)
        end, 'cursor is not on a code span')
      end)
    end)
  end)
end)
