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

  describe('move_column_left / move_column_right', function()
    local COLUMNS = {
      '| a  | b  | c  |',
      '| -- | -- | -- |',
      '| a1 | b1 | c1 |',
    }

    it('swaps the cursor column with its right neighbor', function()
      with_buffer(COLUMNS, { 1, 2 }, function(ctx)
        tbl.move_column_right(ctx)
        assert.same({
          '| b   | a   | c   |',
          '| --- | --- | --- |',
          '| b1  | a1  | c1  |',
        }, vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false))
      end)
    end)

    it('moves the cursor column left from a body row', function()
      with_buffer(COLUMNS, { 3, 7 }, function(ctx)
        tbl.move_column_left(ctx)
        assert.same({
          '| b   | a   | c   |',
          '| --- | --- | --- |',
          '| b1  | a1  | c1  |',
        }, vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false))
      end)
    end)

    it('clamps a count shift at the table edge', function()
      with_buffer(COLUMNS, { 1, 2 }, function(ctx)
        tbl.move_column_right({
          bufnr = ctx.bufnr,
          cursor = ctx.cursor,
          count = 5,
        })
        assert.same({
          '| b   | c   | a   |',
          '| --- | --- | --- |',
          '| b1  | c1  | a1  |',
        }, vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false))
      end)
    end)

    it('follows the column with the cursor', function()
      with_buffer(COLUMNS, { 1, 2 }, function(ctx)
        display(ctx)
        tbl.move_column_right(ctx)
        assert.same({ 1, 8 }, vim.api.nvim_win_get_cursor(0))
      end)
    end)

    it('errors when the column is already at the edge', function()
      with_buffer(COLUMNS, { 1, 2 }, function(ctx)
        local tick = vim.b[ctx.bufnr].changedtick
        assert.error_matches(function()
          tbl.move_column_left(ctx)
        end, 'column is already leftmost')
        assert.equal(tick, vim.b[ctx.bufnr].changedtick)
      end)
    end)

    it('errors when the cursor is not on a table', function()
      with_buffer({ 'paragraph' }, { 1, 0 }, function(ctx)
        assert.error_matches(function()
          tbl.move_column_right(ctx)
        end, 'cursor is not on a pipe table')
      end)
    end)
  end)

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

  describe('actions', function()
    --- Run `fn` with `vim.ui.select` answering each prompt with the
    --- next label from `choices` (nil = cancel) and `vim.ui.input`
    --- answering `input`. Offered top-level labels are captured.
    ---@param choices (string | nil)[]
    ---@param input string?
    ---@param fn fun(offered: string[])
    local function with_ui(choices, input, fn)
      local queue = vim.deepcopy(choices)
      ---@type string[]
      local offered = {}
      local original_select = vim.ui.select
      local original_input = vim.ui.input

      ---@diagnostic disable-next-line: duplicate-set-field
      vim.ui.select = function(items, opts, on_choice)
        local labels = {}
        for _, item in ipairs(items) do
          local label = opts and opts.format_item and opts.format_item(item)
            or item
          table.insert(labels, label)
        end
        if #offered == 0 then
          for _, label in ipairs(labels) do
            table.insert(offered, label)
          end
        end
        local want = table.remove(queue, 1)
        for i, label in ipairs(labels) do
          if label == want then
            return on_choice(items[i], i)
          end
        end
        return on_choice(nil, nil)
      end
      ---@diagnostic disable-next-line: duplicate-set-field
      vim.ui.input = function(_, on_confirm)
        on_confirm(input)
      end

      local ok, err = pcall(fn, offered)
      vim.ui.select = original_select
      vim.ui.input = original_input
      if not ok then
        error(err)
      end
    end

    it('errors synchronously off-table', function()
      with_buffer({ 'paragraph' }, { 1, 0 }, function(ctx)
        assert.error_matches(function()
          tbl.actions(ctx)
        end, 'cursor is not on a pipe table')
      end)
    end)

    it('prompts for the header when inserting a column right', function()
      with_buffer(GRID, { 1, 2 }, function(ctx)
        with_ui({ 'Insert column right' }, 'c', function()
          local tick = vim.b[ctx.bufnr].changedtick
          tbl.actions(ctx)
          assert.same({
            '| a   | c   | b   |',
            '| --- | --- | --- |',
            '| a1  |     | b1  |',
            '| a2  |     | b2  |',
          }, vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false))
          assert.equal(tick + 1, vim.b[ctx.bufnr].changedtick)
        end)
      end)
    end)

    it('inserts a column left of the cursor', function()
      with_buffer(GRID, { 1, 7 }, function(ctx)
        with_ui({ 'Insert column left' }, 'c', function()
          tbl.actions(ctx)
          assert.same({
            '| a   | c   | b   |',
            '| --- | --- | --- |',
            '| a1  |     | b1  |',
            '| a2  |     | b2  |',
          }, vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false))
        end)
      end)
    end)

    it('deletes the cursor column', function()
      with_buffer(GRID, { 1, 7 }, function(ctx)
        with_ui({ 'Delete column' }, nil, function()
          tbl.actions(ctx)
          assert.same({
            '| a   |',
            '| --- |',
            '| a1  |',
            '| a2  |',
          }, vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false))
        end)
      end)
    end)

    it('offers only column operations', function()
      with_buffer(GRID, { 3, 2 }, function(ctx)
        with_ui({}, nil, function(offered)
          tbl.actions(ctx)
          assert.same({
            'Insert column left',
            'Insert column right',
            'Delete column',
          }, offered)
        end)
      end)
    end)

    it('omits column deletion on a single-column table', function()
      with_buffer({ '| a |', '| - |' }, { 1, 2 }, function(ctx)
        with_ui({}, nil, function(offered)
          tbl.actions(ctx)
          local set = {}
          for _, label in ipairs(offered) do
            set[label] = true
          end
          assert.is_nil(set['Delete column'])
        end)
      end)
    end)

    it('cancelling the picker changes nothing', function()
      with_buffer(GRID, { 3, 2 }, function(ctx)
        with_ui({ nil }, nil, function()
          local tick = vim.b[ctx.bufnr].changedtick
          tbl.actions(ctx)
          assert.equal(tick, vim.b[ctx.bufnr].changedtick)
        end)
      end)
    end)

    it('lands the cursor on the affected cell', function()
      with_buffer(GRID, { 3, 7 }, function(ctx)
        display(ctx)
        with_ui({ 'Delete column' }, nil, function()
          tbl.actions(ctx)
          -- Column b is gone; the cursor lands in the surviving column.
          assert.same({ 3, 2 }, vim.api.nvim_win_get_cursor(0))
        end)
      end)
    end)
  end)

  describe('insert_row', function()
    it('inserts a blank row below the cursor row', function()
      with_buffer(GRID, { 3, 2 }, function(ctx)
        tbl.insert_row({ where = 'below' }, ctx)
        assert.same({
          '| a   | b   |',
          '| --- | --- |',
          '| a1  | b1  |',
          '|     |     |',
          '| a2  | b2  |',
        }, vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false))
      end)
    end)

    it('defaults to inserting below', function()
      with_buffer(GRID, { 3, 2 }, function(ctx)
        tbl.insert_row(nil, ctx)
        assert.same({
          '| a   | b   |',
          '| --- | --- |',
          '| a1  | b1  |',
          '|     |     |',
          '| a2  | b2  |',
        }, vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false))
      end)
    end)

    it('inserts a blank row above the cursor row', function()
      with_buffer(GRID, { 4, 2 }, function(ctx)
        tbl.insert_row({ where = 'above' }, ctx)
        assert.same({
          '| a   | b   |',
          '| --- | --- |',
          '| a1  | b1  |',
          '|     |     |',
          '| a2  | b2  |',
        }, vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false))
      end)
    end)

    it('inserts below the header when the cursor is on it', function()
      with_buffer(GRID, { 1, 2 }, function(ctx)
        tbl.insert_row({ where = 'below' }, ctx)
        assert.same({
          '| a   | b   |',
          '| --- | --- |',
          '|     |     |',
          '| a1  | b1  |',
          '| a2  | b2  |',
        }, vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false))
      end)
    end)

    it('lands the cursor in the new row', function()
      with_buffer(GRID, { 3, 2 }, function(ctx)
        display(ctx)
        tbl.insert_row({ where = 'below' }, ctx)
        assert.same({ 4, 2 }, vim.api.nvim_win_get_cursor(0))
      end)
    end)

    it('refuses to insert above the header', function()
      with_buffer(GRID, { 1, 2 }, function(ctx)
        assert.error_matches(function()
          tbl.insert_row({ where = 'above' }, ctx)
        end, 'cannot insert a row above the header')
      end)
    end)

    it('errors on an unknown `where`', function()
      with_buffer(GRID, { 3, 2 }, function(ctx)
        assert.error_matches(function()
          ---@diagnostic disable-next-line: assign-type-mismatch
          tbl.insert_row({ where = 'sideways' }, ctx)
        end, "'where' must be 'above' or 'below'")
      end)
    end)

    it('errors when the cursor is not on a pipe table', function()
      with_buffer({ 'paragraph' }, { 1, 0 }, function(ctx)
        assert.error_matches(function()
          tbl.insert_row({ where = 'below' }, ctx)
        end, 'cursor is not on a pipe table')
      end)
    end)
  end)
end)
