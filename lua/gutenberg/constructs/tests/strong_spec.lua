local strong = require('gutenberg.constructs.strong')

local with_buffer = require('gutenberg.tests.utils').with_buffer

describe('gutenberg.strong', function()
  describe('wrap', function()
    it('wraps the charwise selection in `**`', function()
      with_buffer({ 'make this bold' }, { 1, 0 }, function(ctx)
        strong.wrap({
          bufnr = ctx.bufnr,
          range = { mode = 'char', start = { 1, 5 }, stop = { 1, 8 } },
        })
        assert.same(
          { 'make **this** bold' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('errors on a linewise range', function()
      with_buffer({ 'text' }, { 1, 0 }, function(ctx)
        assert.error_matches(function()
          strong.wrap({
            bufnr = ctx.bufnr,
            range = { mode = 'line', start = { 1, 0 }, stop = { 1, 0 } },
          })
        end, 'wrapping strong emphasis requires a charwise selection')
      end)
    end)
  end)

  describe('remove', function()
    it('replaces the span with its bare text', function()
      with_buffer({ 'a **bold** b' }, { 1, 5 }, function(ctx)
        strong.remove(ctx)
        assert.same(
          { 'a bold b' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('errors off a span', function()
      with_buffer({ 'plain' }, { 1, 0 }, function(ctx)
        assert.error_matches(function()
          strong.remove(ctx)
        end, 'cursor is not on strong emphasis')
      end)
    end)
  end)
end)
