local buffer = require('gutenberg.buffer')
local utils = require('gutenberg.tests.utils')

describe('gutenberg.buffer', function()
  describe('get_range', function()
    it('reads whole lines for line ranges', function()
      utils.with_buffer({ 'one', 'two', 'three' }, { 1, 0 }, function(ctx)
        local lines = buffer.get_range(ctx.bufnr, {
          mode = 'line',
          start = { 2, 0 },
          stop = { 3, 0 },
        })
        assert.same({ 'two', 'three' }, lines)
      end)
    end)

    it('reads covered text for charwise ranges', function()
      utils.with_buffer({ 'alpha beta' }, { 1, 0 }, function(ctx)
        local lines = buffer.get_range(ctx.bufnr, {
          mode = 'char',
          start = { 1, 6 },
          stop = { 1, 9 },
        })
        assert.same({ 'beta' }, lines)
      end)
    end)

    it('reads multiline charwise ranges', function()
      utils.with_buffer({ 'alpha', 'beta' }, { 1, 0 }, function(ctx)
        local lines = buffer.get_range(ctx.bufnr, {
          mode = 'char',
          start = { 1, 3 },
          stop = { 2, 1 },
        })
        assert.same({ 'ha', 'be' }, lines)
      end)
    end)

    it('widens the charwise stop to the full character', function()
      -- 'é' is two bytes; the stop column points at its first byte.
      utils.with_buffer({ 'café!' }, { 1, 0 }, function(ctx)
        local lines = buffer.get_range(ctx.bufnr, {
          mode = 'char',
          start = { 1, 0 },
          stop = { 1, 3 },
        })
        assert.same({ 'café' }, lines)
      end)
    end)

    it('clamps a charwise stop past the line end', function()
      utils.with_buffer({ 'abc' }, { 1, 0 }, function(ctx)
        local lines = buffer.get_range(ctx.bufnr, {
          mode = 'char',
          start = { 1, 0 },
          stop = { 1, 99 },
        })
        assert.same({ 'abc' }, lines)
      end)
    end)

    it(
      'returns an empty string for a charwise range on an empty line',
      function()
        utils.with_buffer({ '' }, { 1, 0 }, function(ctx)
          local lines = buffer.get_range(ctx.bufnr, {
            mode = 'char',
            start = { 1, 0 },
            stop = { 1, 0 },
          })
          assert.same({ '' }, lines)
        end)
      end
    )
  end)

  describe('set_range', function()
    it('replaces whole lines for line ranges', function()
      utils.with_buffer({ 'one', 'two', 'three' }, { 1, 0 }, function(ctx)
        buffer.set_range(ctx.bufnr, {
          mode = 'line',
          start = { 2, 0 },
          stop = { 3, 0 },
        }, { 'TWO' })
        local lines = vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        assert.same({ 'one', 'TWO' }, lines)
      end)
    end)

    it('splices text for charwise ranges', function()
      utils.with_buffer({ 'alpha beta gamma' }, { 1, 0 }, function(ctx)
        buffer.set_range(ctx.bufnr, {
          mode = 'char',
          start = { 1, 6 },
          stop = { 1, 9 },
        }, { 'BETA' })
        local lines = vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        assert.same({ 'alpha BETA gamma' }, lines)
      end)
    end)

    it('replaces the full character at a multibyte stop', function()
      utils.with_buffer({ 'café!' }, { 1, 0 }, function(ctx)
        buffer.set_range(ctx.bufnr, {
          mode = 'char',
          start = { 1, 3 },
          stop = { 1, 3 },
        }, { 'e' })
        local lines = vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        assert.same({ 'cafe!' }, lines)
      end)
    end)

    it('skips the write when nothing changes', function()
      utils.with_buffer({ 'alpha' }, { 1, 0 }, function(ctx)
        local tick = vim.b[ctx.bufnr].changedtick
        buffer.set_range(ctx.bufnr, {
          mode = 'line',
          start = { 1, 0 },
          stop = { 1, 0 },
        }, { 'alpha' })
        assert.equal(tick, vim.b[ctx.bufnr].changedtick)
      end)
    end)
  end)

  describe('set_rows', function()
    it('rewrites scattered rows and preserves the rest', function()
      local lines = { 'one', 'two', 'three', 'four', 'five' }
      utils.with_buffer(lines, { 1, 0 }, function(ctx)
        buffer.set_rows(
          ctx.bufnr,
          { [0] = 'ONE', [2] = 'THREE', [4] = 'FIVE' }
        )
        local result = vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        assert.same({ 'ONE', 'two', 'THREE', 'four', 'FIVE' }, result)
      end)
    end)

    it('applies all edits in a single buffer update', function()
      local lines = { 'one', 'two', 'three' }
      utils.with_buffer(lines, { 1, 0 }, function(ctx)
        local tick = vim.b[ctx.bufnr].changedtick
        buffer.set_rows(ctx.bufnr, { [0] = 'ONE', [2] = 'THREE' })
        assert.equal(tick + 1, vim.b[ctx.bufnr].changedtick)
      end)
    end)

    it('is a no-op with no edits', function()
      utils.with_buffer({ 'one' }, { 1, 0 }, function(ctx)
        local tick = vim.b[ctx.bufnr].changedtick
        buffer.set_rows(ctx.bufnr, {})
        assert.equal(tick, vim.b[ctx.bufnr].changedtick)
      end)
    end)

    it('skips the write when the edits change nothing', function()
      utils.with_buffer({ 'one', 'two' }, { 1, 0 }, function(ctx)
        local tick = vim.b[ctx.bufnr].changedtick
        buffer.set_rows(ctx.bufnr, { [0] = 'one', [1] = 'two' })
        assert.equal(tick, vim.b[ctx.bufnr].changedtick)
      end)
    end)
  end)
end)
