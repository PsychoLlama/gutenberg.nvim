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

  describe('wrap', function()
    it('wraps the selected text in an inline link', function()
      with_buffer({ 'visit the docs today' }, { 1, 0 }, function(ctx)
        link.wrap({ url = 'https://example.com' }, {
          bufnr = ctx.bufnr,
          range = { mode = 'char', start = { 1, 6 }, stop = { 1, 13 } },
        })
        assert.same(
          { 'visit [the docs](https://example.com) today' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('defaults the url to an empty destination', function()
      with_buffer({ 'docs' }, { 1, 0 }, function(ctx)
        link.wrap(nil, {
          bufnr = ctx.bufnr,
          range = { mode = 'char', start = { 1, 0 }, stop = { 1, 3 } },
        })
        assert.same(
          { '[docs]()' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('covers the full character at a multibyte stop', function()
      -- The stop column points at the first byte of the final 'é'.
      with_buffer({ 'see café here' }, { 1, 0 }, function(ctx)
        link.wrap({ url = 'x' }, {
          bufnr = ctx.bufnr,
          range = { mode = 'char', start = { 1, 4 }, stop = { 1, 7 } },
        })
        assert.same(
          { 'see [café](x) here' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('errors without a charwise range', function()
      with_buffer({ 'docs' }, { 1, 0 }, function(ctx)
        assert.error_matches(function()
          link.wrap(nil, { bufnr = ctx.bufnr, cursor = { 1, 0 } })
        end, 'wrapping a link requires a charwise selection')
        assert.error_matches(function()
          link.wrap(nil, {
            bufnr = ctx.bufnr,
            range = { mode = 'line', start = { 1, 0 }, stop = { 1, 0 } },
          })
        end, 'wrapping a link requires a charwise selection')
      end)
    end)

    it('errors on a multiline range', function()
      with_buffer({ 'one', 'two' }, { 1, 0 }, function(ctx)
        assert.error_matches(function()
          link.wrap(nil, {
            bufnr = ctx.bufnr,
            range = { mode = 'char', start = { 1, 0 }, stop = { 2, 1 } },
          })
        end, 'cannot wrap multiple lines in a link')
      end)
    end)
  end)

  describe('remove', function()
    it('replaces an inline link with its text', function()
      with_buffer(
        { 'see [docs](https://example.com) here' },
        { 1, 6 },
        function(ctx)
          link.remove(ctx)
          assert.same(
            { 'see docs here' },
            vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
          )
        end
      )
    end)

    it('replaces an autolink with its URL', function()
      with_buffer(
        { 'go to <https://example.com> now' },
        { 1, 8 },
        function(ctx)
          link.remove(ctx)
          assert.same(
            { 'go to https://example.com now' },
            vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
          )
        end
      )
    end)

    it('replaces a reference link with its text', function()
      local lines =
        { 'see [docs][ref] here', '', '[ref]: https://example.com' }
      with_buffer(lines, { 1, 6 }, function(ctx)
        link.remove(ctx)
        assert.same(
          { 'see docs here', '', '[ref]: https://example.com' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('errors when the cursor is not on a link', function()
      with_buffer({ 'paragraph' }, { 1, 0 }, function(ctx)
        assert.error_matches(function()
          link.remove(ctx)
        end, 'cursor is not on a link')
      end)
    end)
  end)
end)
