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

  describe('next / prev', function()
    local DOC = {
      '# one',
      'body',
      '## two',
      'body',
      '# three',
    }

    --- Show the scratch buffer in the current window so cursor-moving
    --- motions have a window to act on.
    ---@param ctx gutenberg.Context
    local function display(ctx)
      vim.api.nvim_win_set_buf(0, ctx.bufnr)
      vim.api.nvim_win_set_cursor(0, ctx.cursor)
    end

    it('next moves the cursor to the following heading', function()
      with_buffer(DOC, { 1, 0 }, function(ctx)
        display(ctx)
        local found = heading.next(ctx)
        assert.equal('two', found.text)
        assert.same({ 3, 0 }, vim.api.nvim_win_get_cursor(0))
      end)
    end)

    it('next steps count headings', function()
      with_buffer(DOC, { 1, 0 }, function(ctx)
        display(ctx)
        heading.next({ bufnr = ctx.bufnr, cursor = ctx.cursor, count = 2 })
        assert.same({ 5, 0 }, vim.api.nvim_win_get_cursor(0))
      end)
    end)

    it('next clamps an overshooting count at the last heading', function()
      with_buffer(DOC, { 1, 0 }, function(ctx)
        display(ctx)
        heading.next({ bufnr = ctx.bufnr, cursor = ctx.cursor, count = 9 })
        assert.same({ 5, 0 }, vim.api.nvim_win_get_cursor(0))
      end)
    end)

    it('next returns nil and stays put with nothing below', function()
      with_buffer(DOC, { 5, 0 }, function(ctx)
        display(ctx)
        local found = heading.next(ctx)
        assert.is_nil(found)
        assert.same({ 5, 0 }, vim.api.nvim_win_get_cursor(0))
      end)
    end)

    it('prev moves the cursor to the preceding heading', function()
      with_buffer(DOC, { 4, 0 }, function(ctx)
        display(ctx)
        local found = heading.prev(ctx)
        assert.equal('two', found.text)
        assert.same({ 3, 0 }, vim.api.nvim_win_get_cursor(0))
      end)
    end)

    it('respects level filters', function()
      with_buffer(DOC, { 1, 0 }, function(ctx)
        display(ctx)
        local found = heading.next(ctx, { max_level = 1 })
        assert.equal('three', found.text)
        assert.same({ 5, 0 }, vim.api.nvim_win_get_cursor(0))
      end)
    end)
  end)
end)
