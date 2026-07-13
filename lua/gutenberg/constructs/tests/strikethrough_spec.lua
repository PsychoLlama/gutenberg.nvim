local strikethrough = require('gutenberg.constructs.strikethrough')

local with_buffer = require('gutenberg.tests.utils').with_buffer

describe('gutenberg.strikethrough', function()
  describe('wrap', function()
    it('wraps the charwise selection in `~~`', function()
      with_buffer({ 'strike this out' }, { 1, 0 }, function(ctx)
        strikethrough.wrap({
          bufnr = ctx.bufnr,
          range = { mode = 'char', start = { 1, 7 }, stop = { 1, 10 } },
        })
        assert.same(
          { 'strike ~~this~~ out' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('errors on a linewise range', function()
      with_buffer({ 'text' }, { 1, 0 }, function(ctx)
        assert.error_matches(function()
          strikethrough.wrap({
            bufnr = ctx.bufnr,
            range = { mode = 'line', start = { 1, 0 }, stop = { 1, 0 } },
          })
        end, 'wrapping strikethrough requires a charwise selection')
      end)
    end)
  end)

  describe('remove', function()
    it('replaces the whole span with its bare text', function()
      with_buffer({ 'a ~~gone~~ b' }, { 1, 5 }, function(ctx)
        strikethrough.remove(ctx)
        assert.same(
          { 'a gone b' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('errors off a span', function()
      with_buffer({ 'plain' }, { 1, 0 }, function(ctx)
        assert.error_matches(function()
          strikethrough.remove(ctx)
        end, 'cursor is not on strikethrough')
      end)
    end)
  end)
end)
