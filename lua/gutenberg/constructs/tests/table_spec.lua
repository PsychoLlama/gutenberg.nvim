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

  --- Show the scratch buffer in the current window so cursor-moving
  --- motions have a window to act on.
  ---@param ctx gutenberg.Context
  local function display(ctx)
    vim.api.nvim_win_set_buf(0, ctx.bufnr)
    vim.api.nvim_win_set_cursor(0, ctx.cursor)
  end

  local GRID = {
    '| a  | b  |',
    '| -- | -- |',
    '| a1 | b1 |',
    '| a2 | b2 |',
  }

  describe('next_cell / prev_cell', function()
    it('moves to the next cell in the row', function()
      with_buffer(GRID, { 1, 2 }, function(ctx)
        display(ctx)
        tbl.next_cell(ctx)
        assert.same({ 1, 7 }, vim.api.nvim_win_get_cursor(0))
      end)
    end)

    it('wraps to the following body row', function()
      with_buffer(GRID, { 1, 7 }, function(ctx)
        display(ctx)
        tbl.next_cell(ctx)
        assert.same({ 3, 2 }, vim.api.nvim_win_get_cursor(0))
      end)
    end)

    it('steps count cells', function()
      with_buffer(GRID, { 1, 2 }, function(ctx)
        display(ctx)
        tbl.next_cell({ bufnr = ctx.bufnr, cursor = ctx.cursor, count = 3 })
        assert.same({ 3, 7 }, vim.api.nvim_win_get_cursor(0))
      end)
    end)

    it('skips blank cells', function()
      local lines = { '| a |   |', '| - | - |', '| 1 | 2 |' }
      with_buffer(lines, { 1, 2 }, function(ctx)
        display(ctx)
        tbl.next_cell(ctx)
        assert.same({ 3, 2 }, vim.api.nvim_win_get_cursor(0))
      end)
    end)

    it('returns nil and stays put at the last cell', function()
      with_buffer(GRID, { 4, 7 }, function(ctx)
        display(ctx)
        assert.is_nil(tbl.next_cell(ctx))
        assert.same({ 4, 7 }, vim.api.nvim_win_get_cursor(0))
      end)
    end)

    it('prev_cell steps backwards across rows', function()
      with_buffer(GRID, { 3, 2 }, function(ctx)
        display(ctx)
        tbl.prev_cell(ctx)
        assert.same({ 1, 7 }, vim.api.nvim_win_get_cursor(0))
      end)
    end)

    it('errors when the cursor is not on a table', function()
      with_buffer({ 'paragraph' }, { 1, 0 }, function(ctx)
        assert.error_matches(function()
          tbl.next_cell(ctx)
        end, 'cursor is not on a pipe table')
      end)
    end)
  end)

  describe('next_table / prev_table', function()
    local TWO_TABLES = {
      '| a |',
      '| - |',
      '',
      'paragraph',
      '',
      '| b |',
      '| - |',
    }

    it('next_table jumps to the following table', function()
      with_buffer(TWO_TABLES, { 4, 0 }, function(ctx)
        display(ctx)
        local found = tbl.next_table(ctx)
        assert.same({ 'b' }, found.headers)
        assert.same({ 6, 0 }, vim.api.nvim_win_get_cursor(0))
      end)
    end)

    it('next_table returns nil and stays put with none below', function()
      with_buffer(TWO_TABLES, { 6, 0 }, function(ctx)
        display(ctx)
        assert.is_nil(tbl.next_table(ctx))
        assert.same({ 6, 0 }, vim.api.nvim_win_get_cursor(0))
      end)
    end)

    it('prev_table jumps to the preceding table', function()
      with_buffer(TWO_TABLES, { 4, 0 }, function(ctx)
        display(ctx)
        local found = tbl.prev_table(ctx)
        assert.same({ 'a' }, found.headers)
        assert.same({ 1, 0 }, vim.api.nvim_win_get_cursor(0))
      end)
    end)
  end)

  describe('select_cell', function()
    it('selects the trimmed cell text charwise', function()
      with_buffer(GRID, { 3, 3 }, function(ctx)
        display(ctx)
        tbl.select_cell(ctx)
        assert.equal('v', vim.fn.mode())
        local anchor = vim.fn.getpos('v')
        local head = vim.fn.getpos('.')
        assert.same({ 3, 3 }, { anchor[2], anchor[3] })
        assert.same({ 3, 4 }, { head[2], head[3] })
        vim.api.nvim_feedkeys(
          vim.api.nvim_replace_termcodes('<Esc>', true, false, true),
          'nx',
          false
        )
      end)
    end)

    it('replaces an existing visual selection', function()
      with_buffer(GRID, { 3, 3 }, function(ctx)
        display(ctx)
        vim.cmd('normal! v')
        tbl.select_cell(ctx)
        assert.equal('v', vim.fn.mode())
        local anchor = vim.fn.getpos('v')
        assert.same({ 3, 3 }, { anchor[2], anchor[3] })
        vim.api.nvim_feedkeys(
          vim.api.nvim_replace_termcodes('<Esc>', true, false, true),
          'nx',
          false
        )
      end)
    end)

    it('errors on a blank cell', function()
      local lines = { '| a |   |', '| - | - |' }
      with_buffer(lines, { 1, 6 }, function(ctx)
        display(ctx)
        assert.error_matches(function()
          tbl.select_cell(ctx)
        end, 'no cell text under the cursor')
      end)
    end)

    it('errors when the cursor is not on a table', function()
      with_buffer({ 'paragraph' }, { 1, 0 }, function(ctx)
        assert.error_matches(function()
          tbl.select_cell(ctx)
        end, 'cursor is not on a pipe table')
      end)
    end)
  end)
end)
