local api = require('gutenberg.api.table')
local tbl = require('gutenberg.constructs.table')

local with_buffer = require('gutenberg.tests.utils').with_buffer

describe('gutenberg.table', function()
  describe('update', function()
    it('writes the mutated table back in one update', function()
      with_buffer({ '| a |', '| - |', '| 1 |' }, { 1, 0 }, function(ctx)
        tbl.update(function(t)
          api.set_cell(t, 0, 1, 'header')
        end, ctx)
        assert.same(
          { '| header |', '| ------ |', '| 1      |' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('errors when the cursor is not on a table', function()
      with_buffer({ 'paragraph' }, { 1, 0 }, function(ctx)
        assert.error_matches(function()
          tbl.update(function() end, ctx)
        end, 'cursor is not on a pipe table')
      end)
    end)
  end)

  describe('format', function()
    it('normalizes ragged cells and pipes', function()
      with_buffer(
        { '| a | b |', '| - | - |', '|1|two|' },
        { 3, 0 },
        function(ctx)
          tbl.format(ctx)
          assert.same({
            '| a   | b   |',
            '| --- | --- |',
            '| 1   | two |',
          }, vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false))
        end
      )
    end)
  end)

  describe('cycle_alignment', function()
    it('advances none to left', function()
      with_buffer({ '| a |', '| - |', '| 1 |' }, { 1, 2 }, function(ctx)
        tbl.cycle_alignment(ctx)
        assert.same(
          { '| a   |', '| :-- |', '| 1   |' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('wraps right back around to none', function()
      with_buffer({ '| a |', '| -: |', '| 1 |' }, { 1, 2 }, function(ctx)
        tbl.cycle_alignment(ctx)
        assert.same(
          { '| a   |', '| --- |', '| 1   |' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('errors when the cursor is not on a table', function()
      with_buffer({ 'paragraph' }, { 1, 0 }, function(ctx)
        assert.error_matches(function()
          tbl.cycle_alignment(ctx)
        end, 'cursor is not on a pipe table')
      end)
    end)

    it('advances count steps', function()
      with_buffer({ '| a |', '| - |', '| 1 |' }, { 1, 2 }, function(ctx)
        tbl.cycle_alignment({
          bufnr = ctx.bufnr,
          cursor = ctx.cursor,
          count = 2,
        })
        assert.same(
          { '|  a  |', '| :-: |', '|  1  |' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('wraps a count shift around the cycle', function()
      with_buffer({ '| a |', '| :- |', '| 1 |' }, { 1, 2 }, function(ctx)
        tbl.cycle_alignment({
          bufnr = ctx.bufnr,
          cursor = ctx.cursor,
          count = 7,
        })
        assert.same(
          { '| a   |', '| --- |', '| 1   |' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)
  end)
end)
