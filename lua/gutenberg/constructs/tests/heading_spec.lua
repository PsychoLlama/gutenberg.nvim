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

    it('shifts count levels', function()
      with_buffer({ '# title' }, { 1, 0 }, function(ctx)
        heading.demote({ bufnr = ctx.bufnr, cursor = ctx.cursor, count = 3 })
        assert.same(
          { '#### title' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('clamps a count shift at the boundary', function()
      with_buffer({ '#### title' }, { 1, 0 }, function(ctx)
        heading.promote({ bufnr = ctx.bufnr, cursor = ctx.cursor, count = 9 })
        assert.same(
          { '# title' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)
  end)

  describe('promote / demote with a range', function()
    local DOC = {
      '# one',
      'body',
      '## two',
      '### three',
    }

    it('shifts every heading starting in the range', function()
      with_buffer(DOC, { 1, 0 }, function(ctx)
        heading.demote({
          bufnr = ctx.bufnr,
          range = { mode = 'line', start = { 1, 0 }, stop = { 3, 0 } },
        })
        assert.same(
          { '## one', 'body', '### two', '### three' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('applies the whole shift as one buffer update', function()
      with_buffer(DOC, { 1, 0 }, function(ctx)
        local tick = vim.b[ctx.bufnr].changedtick
        heading.demote({
          bufnr = ctx.bufnr,
          range = { mode = 'line', start = { 1, 0 }, stop = { 4, 0 } },
        })
        assert.equal(tick + 1, vim.b[ctx.bufnr].changedtick)
      end)
    end)

    it('combines the range with a count', function()
      with_buffer(DOC, { 1, 0 }, function(ctx)
        heading.promote({
          bufnr = ctx.bufnr,
          count = 2,
          range = { mode = 'line', start = { 3, 0 }, stop = { 4, 0 } },
        })
        assert.same(
          { '# one', 'body', '# two', '# three' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('errors when the range holds no heading', function()
      with_buffer(DOC, { 1, 0 }, function(ctx)
        assert.error_matches(function()
          heading.demote({
            bufnr = ctx.bufnr,
            range = { mode = 'line', start = { 2, 0 }, stop = { 2, 0 } },
          })
        end, 'no heading in the selected range')
      end)
    end)
  end)
end)
