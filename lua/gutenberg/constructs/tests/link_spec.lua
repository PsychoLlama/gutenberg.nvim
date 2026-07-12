local api = require('gutenberg.api.link')
local link = require('gutenberg.constructs.link')

local with_buffer = require('gutenberg.tests.utils').with_buffer

describe('gutenberg.link', function()
  describe('update', function()
    it('writes the mutated link back in one update', function()
      with_buffer({ 'see [text](url) here' }, { 1, 6 }, function(ctx)
        link.update(function(lnk)
          api.set_url(lnk, 'https://example.com')
        end, ctx)
        assert.same(
          { 'see [text](https://example.com) here' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('errors when the cursor is not on a link', function()
      with_buffer({ 'paragraph' }, { 1, 0 }, function(ctx)
        assert.error_matches(function()
          link.update(function() end, ctx)
        end, 'cursor is not on a link')
      end)
    end)
  end)
end)
