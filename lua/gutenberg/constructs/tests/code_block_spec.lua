local api = require('gutenberg.api.code_block')
local code_block = require('gutenberg.constructs.code_block')

local with_buffer = require('gutenberg.tests.utils').with_buffer

describe('gutenberg.code_block', function()
  describe('update', function()
    it('writes the mutated block back in one update', function()
      with_buffer({ '```', 'code', '```' }, { 2, 0 }, function(ctx)
        code_block.update(function(block)
          api.set_info_string(block, 'lua')
        end, ctx)
        assert.same(
          { '```lua', 'code', '```' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('errors when the cursor is not on a code block', function()
      with_buffer({ 'paragraph' }, { 1, 0 }, function(ctx)
        assert.error_matches(function()
          code_block.update(function() end, ctx)
        end, 'cursor is not on a fenced code block')
      end)
    end)
  end)

  describe('insert', function()
    it('replaces a blank cursor row with an empty block', function()
      with_buffer({ 'before', '', 'after' }, { 2, 0 }, function(ctx)
        code_block.insert(ctx)
        assert.same(
          { 'before', '```', '```', 'after' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('splices below a non-blank cursor row', function()
      with_buffer({ 'text', 'after' }, { 1, 0 }, function(ctx)
        code_block.insert(ctx)
        assert.same(
          { 'text', '```', '```', 'after' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('honors the configured fence', function()
      require('gutenberg.config').merge({
        code_block = { fence = '~', fence_length = 4 },
      })
      local ok, err = pcall(with_buffer, { '' }, { 1, 0 }, function(ctx)
        code_block.insert(ctx)
        assert.same(
          { '~~~~', '~~~~' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
      require('gutenberg.config').merge()
      if not ok then
        error(err)
      end
    end)
  end)

  describe('wrap', function()
    it('fences the cursor row by default', function()
      with_buffer({ 'code', 'after' }, { 1, 0 }, function(ctx)
        code_block.wrap(ctx)
        assert.same(
          { '```', 'code', '```', 'after' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('fences the cursor row plus count - 1', function()
      with_buffer({ 'one', 'two', 'three' }, { 1, 0 }, function(ctx)
        code_block.wrap({ bufnr = ctx.bufnr, cursor = ctx.cursor, count = 2 })
        assert.same(
          { '```', 'one', 'two', '```', 'three' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('fences a linewise range in one update', function()
      with_buffer({ 'one', 'two', 'three' }, { 1, 0 }, function(ctx)
        local tick = vim.b[ctx.bufnr].changedtick
        code_block.wrap({
          bufnr = ctx.bufnr,
          range = { mode = 'line', start = { 2, 0 }, stop = { 3, 0 } },
        })
        assert.same(
          { 'one', '```', 'two', 'three', '```' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
        assert.equal(tick + 1, vim.b[ctx.bufnr].changedtick)
      end)
    end)

    it('errors on a charwise range', function()
      with_buffer({ 'one two' }, { 1, 0 }, function(ctx)
        assert.error_matches(function()
          code_block.wrap({
            bufnr = ctx.bufnr,
            range = { mode = 'char', start = { 1, 0 }, stop = { 1, 2 } },
          })
        end, 'can only wrap whole lines in a code block')
      end)
    end)

    it('escalates the fence past content fence runs', function()
      local lines = { '````', 'nested', '````' }
      with_buffer(lines, { 1, 0 }, function(ctx)
        code_block.wrap({
          bufnr = ctx.bufnr,
          range = { mode = 'line', start = { 1, 0 }, stop = { 3, 0 } },
        })
        assert.same(
          { '`````', '````', 'nested', '````', '`````' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('ignores fence runs indented past a valid closing fence', function()
      with_buffer({ '    ```' }, { 1, 0 }, function(ctx)
        code_block.wrap(ctx)
        assert.same(
          { '```', '    ```', '```' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)
  end)
end)
