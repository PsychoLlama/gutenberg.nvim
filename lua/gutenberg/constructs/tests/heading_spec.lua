local heading = require('gutenberg.constructs.heading')

local with_buffer = require('gutenberg.tests.utils').with_buffer

describe('gutenberg.heading', function()
  describe('update', function()
    it('writes the mutated heading back in one update', function()
      with_buffer({ '# title', 'body' }, { 1, 0 }, function(ctx)
        heading.update(function(h)
          h.text = 'edited'
        end, ctx)
        assert.same(
          { '# edited', 'body' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('errors when the cursor is not on a heading', function()
      with_buffer({ 'paragraph' }, { 1, 0 }, function(ctx)
        assert.error_matches(function()
          heading.update(function() end, ctx)
        end, 'cursor is not on a heading')
      end)
    end)
  end)

  describe('promote / demote', function()
    it('promote raises the heading one level', function()
      with_buffer({ '### title' }, { 1, 0 }, function(ctx)
        heading.promote(ctx)
        assert.same(
          { '## title' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('promote leaves a level-1 heading unchanged', function()
      with_buffer({ '# title' }, { 1, 0 }, function(ctx)
        heading.promote(ctx)
        assert.same(
          { '# title' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('demote sinks the heading one level', function()
      with_buffer({ '# title' }, { 1, 0 }, function(ctx)
        heading.demote(ctx)
        assert.same(
          { '## title' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('demote leaves a level-6 heading unchanged', function()
      with_buffer({ '###### title' }, { 1, 0 }, function(ctx)
        heading.demote(ctx)
        assert.same(
          { '###### title' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)
  end)
end)
