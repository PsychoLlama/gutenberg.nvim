local tbl = require('gutenberg.api.table')

local with_buffer = require('gutenberg.tests.utils').with_buffer

describe('gutenberg.api.table', function()
  describe('render', function()
    it('renders a basic two-column table', function()
      local lines = tbl.render({
        alignments = { 'none', 'none' },
        headers = { 'Name', 'Score' },
        rows = { { 'Ann', '10' }, { 'Bob', '7' } },
      })
      assert.same({
        '| Name | Score |',
        '| ---- | ----- |',
        '| Ann  | 10    |',
        '| Bob  | 7     |',
      }, lines)
    end)

    it('applies left alignment marker', function()
      local lines = tbl.render({
        alignments = { 'left' },
        headers = { 'a' },
        rows = {},
      })
      assert.same({
        '| a   |',
        '| :-- |',
      }, lines)
    end)

    it('applies right alignment marker', function()
      local lines = tbl.render({
        alignments = { 'right' },
        headers = { 'a' },
        rows = {},
      })
      assert.same({
        '|   a |',
        '| --: |',
      }, lines)
    end)

    it('applies center alignment marker', function()
      local lines = tbl.render({
        alignments = { 'center' },
        headers = { 'a' },
        rows = {},
      })
      assert.same({
        '|  a  |',
        '| :-: |',
      }, lines)
    end)

    it('renders none alignment without colons', function()
      local lines = tbl.render({
        alignments = { 'none' },
        headers = { 'a' },
        rows = {},
      })
      assert.same({
        '| a   |',
        '| --- |',
      }, lines)
    end)

    it('pads columns to the max content width', function()
      local lines = tbl.render({
        alignments = { 'none', 'none' },
        headers = { 'h', 'b' },
        rows = { { 'short', 'longer-cell' } },
      })
      assert.same({
        '| h     | b           |',
        '| ----- | ----------- |',
        '| short | longer-cell |',
      }, lines)
    end)

    it('centers odd remainders to the right', function()
      local lines = tbl.render({
        alignments = { 'center' },
        headers = { 'ab' },
        rows = { { 'abcd' } },
      })
      assert.same({
        '|  ab  |',
        '| :--: |',
        '| abcd |',
      }, lines)
    end)

    it('renders a single column', function()
      local lines = tbl.render({
        alignments = { 'none' },
        headers = { 'only' },
        rows = { { 'a' }, { 'bb' } },
      })
      assert.same({
        '| only |',
        '| ---- |',
        '| a    |',
        '| bb   |',
      }, lines)
    end)

    it('renders an empty body', function()
      local lines = tbl.render({
        alignments = { 'none' },
        headers = { 'h' },
        rows = {},
      })
      assert.same({
        '| h   |',
        '| --- |',
      }, lines)
    end)

    it('pads ragged rows to the column count', function()
      local lines = tbl.render({
        alignments = { 'none', 'none', 'none' },
        headers = { 'a', 'b', 'c' },
        rows = { { 'x' } },
      })
      assert.same({
        '| a   | b   | c   |',
        '| --- | --- | --- |',
        '| x   |     |     |',
      }, lines)
    end)

    it(
      'extends column count when rows have more cells than headers',
      function()
        local lines = tbl.render({
          alignments = {},
          headers = { 'a' },
          rows = { { 'x', 'y' } },
        })
        assert.same({
          '| a   |     |',
          '| --- | --- |',
          '| x   | y   |',
        }, lines)
      end
    )
  end)

  describe('is_table', function()
    it('returns true on the header row', function()
      with_buffer({
        '| a | b |',
        '| - | - |',
        '| 1 | 2 |',
      }, { 1, 2 }, function(ctx)
        assert.is_true(tbl.is_table(ctx))
      end)
    end)

    it('returns true on the delimiter row', function()
      with_buffer({
        '| a | b |',
        '| - | - |',
        '| 1 | 2 |',
      }, { 2, 2 }, function(ctx)
        assert.is_true(tbl.is_table(ctx))
      end)
    end)

    it('returns true on a body row', function()
      with_buffer({
        '| a | b |',
        '| - | - |',
        '| 1 | 2 |',
      }, { 3, 2 }, function(ctx)
        assert.is_true(tbl.is_table(ctx))
      end)
    end)

    it('returns true in the leading indent of an indented table', function()
      with_buffer({
        '  | a | b |',
        '  | - | - |',
        '  | 1 | 2 |',
      }, { 1, 0 }, function(ctx)
        assert.is_true(tbl.is_table(ctx))
      end)
    end)

    it('returns false on a paragraph', function()
      with_buffer({ 'paragraph' }, { 1, 2 }, function(ctx)
        assert.is_false(tbl.is_table(ctx))
      end)
    end)

    it('returns false on a list', function()
      with_buffer({ '- foo' }, { 1, 2 }, function(ctx)
        assert.is_false(tbl.is_table(ctx))
      end)
    end)

    it('returns false on a heading', function()
      with_buffer({ '# heading' }, { 1, 2 }, function(ctx)
        assert.is_false(tbl.is_table(ctx))
      end)
    end)

    it('returns false on a blank line', function()
      with_buffer({ '' }, { 1, 0 }, function(ctx)
        assert.is_false(tbl.is_table(ctx))
      end)
    end)
  end)

  describe('read', function()
    it('reads a basic table', function()
      with_buffer({
        '| Name | Score |',
        '| :--- | ----: |',
        '| Ann  |    10 |',
        '| Bob  |     7 |',
      }, { 1, 2 }, function(ctx)
        local t = tbl.read(ctx)
        assert.same({ 'Name', 'Score' }, t.headers)
        assert.same({ 'left', 'right' }, t.alignments)
        assert.same({ { 'Ann', '10' }, { 'Bob', '7' } }, t.rows)
      end)
    end)

    it('parses every alignment kind', function()
      with_buffer({
        '| a | b | c | d |',
        '| :--- | ---: | :---: | --- |',
        '| 1 | 2 | 3 | 4 |',
      }, { 2, 2 }, function(ctx)
        local t = tbl.read(ctx)
        assert.same({ 'left', 'right', 'center', 'none' }, t.alignments)
      end)
    end)

    it('reads a table with no body rows', function()
      with_buffer({
        '| h |',
        '| - |',
        '',
        'paragraph',
      }, { 1, 2 }, function(ctx)
        local t = tbl.read(ctx)
        assert.same({ 'h' }, t.headers)
        assert.same({}, t.rows)
      end)
    end)

    it('trims surrounding whitespace from cells', function()
      with_buffer({
        '|   spaced   | tight |',
        '| --- | --- |',
        '|  a  |  b  |',
      }, { 1, 2 }, function(ctx)
        local t = tbl.read(ctx)
        assert.same({ 'spaced', 'tight' }, t.headers)
        assert.same({ { 'a', 'b' } }, t.rows)
      end)
    end)

    it('returns the pipe_table TSNode', function()
      with_buffer({
        '| a |',
        '| - |',
        '| 1 |',
      }, { 3, 2 }, function(ctx)
        local _, node = tbl.read(ctx)
        assert.equal('pipe_table', node:type())
      end)
    end)
  end)

  describe('create', function()
    it('returns a single-column table by default', function()
      local t = tbl.create({})
      assert.same({ '' }, t.headers)
      assert.same({ 'none' }, t.alignments)
      assert.same({}, t.rows)
    end)

    it('defaults alignments to none per header column', function()
      local t = tbl.create({ headers = { 'a', 'b', 'c' } })
      assert.same({ 'none', 'none', 'none' }, t.alignments)
    end)

    it('honors all explicit fields', function()
      local t = tbl.create({
        alignments = { 'left', 'right' },
        headers = { 'a', 'b' },
        rows = { { '1', '2' } },
      })
      assert.same({ 'left', 'right' }, t.alignments)
      assert.same({ 'a', 'b' }, t.headers)
      assert.same({ { '1', '2' } }, t.rows)
    end)
  end)

  describe('replace', function()
    it('rewrites a table in place', function()
      with_buffer({
        '| a | b |',
        '| - | - |',
        '| 1 | 2 |',
      }, { 1, 2 }, function(ctx)
        local t, node = tbl.read(ctx)
        t.headers[1] = 'edited'
        tbl.replace(node, { t }, ctx)
        assert.same({
          '| edited | b   |',
          '| ------ | --- |',
          '| 1      | 2   |',
        }, vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false))
      end)
    end)

    it('deletes the table when tables is empty', function()
      with_buffer({
        'before',
        '',
        '| a |',
        '| - |',
        '| 1 |',
        '',
        'after',
      }, { 3, 2 }, function(ctx)
        local _, node = tbl.read(ctx)
        tbl.replace(node, {}, ctx)
        assert.same(
          { 'before', '', '', 'after' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('expands one table into many separated by blank lines', function()
      with_buffer({
        '| a |',
        '| - |',
        '| 1 |',
      }, { 1, 2 }, function(ctx)
        local t, node = tbl.read(ctx)
        local other = tbl.create({ headers = { 'b' }, rows = { { '2' } } })
        tbl.replace(node, { t, other }, ctx)
        assert.same({
          '| a   |',
          '| --- |',
          '| 1   |',
          '',
          '| b   |',
          '| --- |',
          '| 2   |',
        }, vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false))
      end)
    end)

    it('preserves surrounding non-table content', function()
      with_buffer({
        '# heading',
        '',
        '| a |',
        '| - |',
        '| 1 |',
        '',
        'paragraph',
      }, { 3, 2 }, function(ctx)
        local t, node = tbl.read(ctx)
        t.rows[1][1] = 'edited'
        tbl.replace(node, { t }, ctx)
        assert.same({
          '# heading',
          '',
          '| a      |',
          '| ------ |',
          '| edited |',
          '',
          'paragraph',
        }, vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false))
      end)
    end)

    it('rewrites the last table in the buffer', function()
      with_buffer({
        '| a |',
        '| - |',
        '| 1 |',
      }, { 3, 2 }, function(ctx)
        local t, node = tbl.read(ctx)
        t.rows[1][1] = 'edited'
        tbl.replace(node, { t }, ctx)
        assert.same({
          '| a      |',
          '| ------ |',
          '| edited |',
        }, vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false))
      end)
    end)

    it('round-trips read and replace without semantic changes', function()
      with_buffer({
        '| Name | Score |',
        '| :--- | ----: |',
        '| Ann  |    10 |',
      }, { 1, 2 }, function(ctx)
        local t, node = tbl.read(ctx)
        tbl.replace(node, { t }, ctx)
        local t2 = tbl.read({ bufnr = ctx.bufnr, cursor = { 1, 2 } })
        assert.same(t.headers, t2.headers)
        assert.same(t.alignments, t2.alignments)
        assert.same(t.rows, t2.rows)
      end)
    end)

    it('preserves a block quote prefix on every rewritten row', function()
      with_buffer({
        '> | a | b |',
        '> | - | - |',
        '> | 1 | 2 |',
      }, { 1, 4 }, function(ctx)
        local t, node = tbl.read(ctx)
        t.rows[1][1] = 'x'
        tbl.replace(node, { t }, ctx)
        assert.same({
          '> | a   | b   |',
          '> | --- | --- |',
          '> | x   | 2   |',
        }, vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false))
      end)
    end)
  end)

  describe('get_alignment / set_alignment', function()
    it('reads the alignment for a column', function()
      local t = tbl.create({
        alignments = { 'left', 'right' },
        headers = { 'a', 'b' },
      })
      assert.equal('left', tbl.get_alignment(t, 1))
      assert.equal('right', tbl.get_alignment(t, 2))
    end)

    it('writes the alignment for a column', function()
      local t = tbl.create({ headers = { 'a', 'b' } })
      tbl.set_alignment(t, 1, 'center')
      assert.equal('center', t.alignments[1])
    end)

    it('errors on out-of-range column', function()
      local t = tbl.create({ headers = { 'a' } })
      assert.has_error(function()
        tbl.get_alignment(t, 2)
      end)
      assert.has_error(function()
        tbl.set_alignment(t, 0, 'left')
      end)
    end)
  end)

  describe('get_cell / set_cell', function()
    it('reads a header cell with row 0', function()
      local t = tbl.create({ headers = { 'a', 'b' } })
      assert.equal('a', tbl.get_cell(t, 0, 1))
      assert.equal('b', tbl.get_cell(t, 0, 2))
    end)

    it('reads a body cell with row >= 1', function()
      local t = tbl.create({
        headers = { 'a', 'b' },
        rows = { { '1', '2' }, { '3', '4' } },
      })
      assert.equal('1', tbl.get_cell(t, 1, 1))
      assert.equal('4', tbl.get_cell(t, 2, 2))
    end)

    it('writes a header cell with row 0', function()
      local t = tbl.create({ headers = { 'a' } })
      tbl.set_cell(t, 0, 1, 'edited')
      assert.equal('edited', t.headers[1])
    end)

    it('writes a body cell with row >= 1', function()
      local t = tbl.create({ headers = { 'a' }, rows = { { '1' } } })
      tbl.set_cell(t, 1, 1, 'edited')
      assert.equal('edited', t.rows[1][1])
    end)

    it('errors on out-of-range row', function()
      local t = tbl.create({ headers = { 'a' }, rows = { { '1' } } })
      assert.has_error(function()
        tbl.get_cell(t, 2, 1)
      end)
      assert.has_error(function()
        tbl.set_cell(t, 5, 1, 'x')
      end)
    end)

    it('errors on out-of-range column', function()
      local t = tbl.create({ headers = { 'a' }, rows = { { '1' } } })
      assert.has_error(function()
        tbl.get_cell(t, 0, 2)
      end)
      assert.has_error(function()
        tbl.set_cell(t, 1, 0, 'x')
      end)
    end)
  end)

  describe('column_at', function()
    it('resolves a cursor inside a header cell', function()
      with_buffer(
        { '| aa | bb |', '| -- | -- |', '| 11 | 22 |' },
        { 1, 7 },
        function(ctx)
          assert.equal(2, tbl.column_at(ctx))
        end
      )
    end)

    it('resolves a cursor inside a body cell', function()
      with_buffer(
        { '| aa | bb |', '| -- | -- |', '| 11 | 22 |' },
        { 3, 2 },
        function(ctx)
          assert.equal(1, tbl.column_at(ctx))
        end
      )
    end)

    it('resolves a cursor on the delimiter row', function()
      with_buffer(
        { '| aa | bb |', '| -- | -- |', '| 11 | 22 |' },
        { 2, 8 },
        function(ctx)
          assert.equal(2, tbl.column_at(ctx))
        end
      )
    end)

    it('counts a pipe as closing the column before it', function()
      -- Cursor on the middle pipe of `| aa | bb |`.
      with_buffer({ '| aa | bb |', '| -- | -- |' }, { 1, 5 }, function(ctx)
        assert.equal(1, tbl.column_at(ctx))
      end)
    end)

    it('resolves the leading pipe to column 1', function()
      with_buffer({ '| aa | bb |', '| -- | -- |' }, { 1, 0 }, function(ctx)
        assert.equal(1, tbl.column_at(ctx))
      end)
    end)

    it('returns nil off the table', function()
      with_buffer({ 'paragraph' }, { 1, 0 }, function(ctx)
        assert.is_nil(tbl.column_at(ctx))
      end)
    end)
  end)

  local GRID = {
    '| a  | b  |',
    '| -- | -- |',
    '| a1 | b1 |',
    '| a2 | b2 |',
  }

  describe('row_at', function()
    it('returns 0 on the header row', function()
      with_buffer(GRID, { 1, 2 }, function(ctx)
        assert.equal(0, tbl.row_at(ctx))
      end)
    end)

    it('returns 0 on the delimiter row', function()
      with_buffer(GRID, { 2, 2 }, function(ctx)
        assert.equal(0, tbl.row_at(ctx))
      end)
    end)

    it('returns the 1-based body row index', function()
      with_buffer(GRID, { 4, 2 }, function(ctx)
        assert.equal(2, tbl.row_at(ctx))
      end)
    end)

    it('returns nil off-table', function()
      with_buffer({ 'paragraph' }, { 1, 0 }, function(ctx)
        assert.is_nil(tbl.row_at(ctx))
      end)
    end)
  end)

  describe('find_next / find_prev', function()
    local TWO_TABLES = {
      '| a |',
      '| - |',
      '',
      'paragraph',
      '',
      '| b |',
      '| - |',
    }

    it('find_next returns the nearest table after the cursor', function()
      with_buffer(TWO_TABLES, { 4, 0 }, function(ctx)
        local t, node = tbl.find_next(ctx)
        assert.same({ 'b' }, t.headers)
        assert.equal(5, (node:range()))
      end)
    end)

    it('find_next returns nil with no table below', function()
      with_buffer(TWO_TABLES, { 6, 0 }, function(ctx)
        local t = tbl.find_next(ctx)
        assert.is_nil(t)
      end)
    end)

    it('find_prev returns the nearest table before the cursor', function()
      with_buffer(TWO_TABLES, { 4, 0 }, function(ctx)
        local t, node = tbl.find_prev(ctx)
        assert.same({ 'a' }, t.headers)
        assert.equal(0, (node:range()))
      end)
    end)

    it('find_prev returns nil with no table above', function()
      with_buffer(TWO_TABLES, { 1, 0 }, function(ctx)
        local t = tbl.find_prev(ctx)
        assert.is_nil(t)
      end)
    end)
  end)

  describe('cell_range', function()
    it('covers the trimmed text of a body cell', function()
      with_buffer(GRID, { 1, 0 }, function(ctx)
        local _, node = tbl.read(ctx)
        local range = tbl.cell_range(node, 1, 2, ctx)
        assert.same({
          mode = 'char',
          start = { 3, 7 },
          stop = { 3, 8 },
        }, range)
      end)
    end)

    it('addresses the header with row 0', function()
      with_buffer(GRID, { 3, 0 }, function(ctx)
        local _, node = tbl.read(ctx)
        local range = tbl.cell_range(node, 0, 1, ctx)
        assert.same({
          mode = 'char',
          start = { 1, 2 },
          stop = { 1, 2 },
        }, range)
      end)
    end)

    it('points the stop at the first byte of a multibyte tail', function()
      with_buffer({ '| héé |', '| --- |' }, { 1, 0 }, function(ctx)
        local _, node = tbl.read(ctx)
        local range = tbl.cell_range(node, 0, 1, ctx)
        -- 'héé' starts at byte col 2; the final 'é' occupies bytes 5-6.
        assert.same({
          mode = 'char',
          start = { 1, 2 },
          stop = { 1, 5 },
        }, range)
      end)
    end)

    it('returns nil for a blank cell', function()
      with_buffer({ '| a |  |', '| - | - |' }, { 1, 0 }, function(ctx)
        local _, node = tbl.read(ctx)
        assert.is_nil(tbl.cell_range(node, 0, 2, ctx))
      end)
    end)

    it('returns nil for a missing cell', function()
      with_buffer(GRID, { 1, 0 }, function(ctx)
        local _, node = tbl.read(ctx)
        assert.is_nil(tbl.cell_range(node, 1, 3, ctx))
        assert.is_nil(tbl.cell_range(node, 9, 1, ctx))
      end)
    end)
  end)

  describe('insert_row', function()
    it('inserts at a body index', function()
      local t = tbl.create({ headers = { 'a' }, rows = { { '1' }, { '3' } } })
      tbl.insert_row(t, 2, { '2' })
      assert.same({ { '1' }, { '2' }, { '3' } }, t.rows)
    end)

    it('appends with index #rows + 1', function()
      local t = tbl.create({ headers = { 'a' }, rows = { { '1' } } })
      tbl.insert_row(t, 2, { '2' })
      assert.same({ { '1' }, { '2' } }, t.rows)
    end)

    it('errors on out-of-range indices', function()
      local t = tbl.create({ headers = { 'a' } })
      assert.error_matches(function()
        tbl.insert_row(t, 0, { 'x' })
      end, 'row index out of range')
      assert.error_matches(function()
        tbl.insert_row(t, 3, { 'x' })
      end, 'row index out of range')
    end)
  end)

  describe('delete_row', function()
    it('deletes the body row at index', function()
      local t = tbl.create({ headers = { 'a' }, rows = { { '1' }, { '2' } } })
      tbl.delete_row(t, 1)
      assert.same({ { '2' } }, t.rows)
    end)

    it('refuses to delete the header row', function()
      local t = tbl.create({ headers = { 'a' }, rows = { { '1' } } })
      assert.error_matches(function()
        tbl.delete_row(t, 0)
      end, 'cannot delete the header row')
    end)

    it('errors on out-of-range indices', function()
      local t = tbl.create({ headers = { 'a' }, rows = { { '1' } } })
      assert.error_matches(function()
        tbl.delete_row(t, 2)
      end, 'row index out of range')
    end)
  end)

  describe('move_row', function()
    it('moves a body row to a new position', function()
      local t = tbl.create({
        headers = { 'a' },
        rows = { { '1' }, { '2' }, { '3' } },
      })
      tbl.move_row(t, 1, 3)
      assert.same({ { '2' }, { '3' }, { '1' } }, t.rows)
    end)

    it('errors on out-of-range indices', function()
      local t = tbl.create({ headers = { 'a' }, rows = { { '1' } } })
      assert.error_matches(function()
        tbl.move_row(t, 1, 2)
      end, 'row index out of range')
    end)
  end)

  describe('insert_column', function()
    it('inserts header, alignment, and cells at index', function()
      local t = tbl.create({
        headers = { 'a', 'c' },
        alignments = { 'left', 'right' },
        rows = { { 'a1', 'c1' } },
      })
      tbl.insert_column(t, 2, {
        header = 'b',
        alignment = 'center',
        cells = { 'b1' },
      })
      assert.same({ 'a', 'b', 'c' }, t.headers)
      assert.same({ 'left', 'center', 'right' }, t.alignments)
      assert.same({ { 'a1', 'b1', 'c1' } }, t.rows)
    end)

    it(
      'defaults missing fields to blanks and the configured alignment',
      function()
        local t = tbl.create({ headers = { 'a' }, rows = { { 'a1' } } })
        tbl.insert_column(t, 2)
        assert.same({ 'a', '' }, t.headers)
        assert.same({ 'none', 'none' }, t.alignments)
        assert.same({ { 'a1', '' } }, t.rows)
      end
    )

    it('pads ragged rows up to the insertion point', function()
      local t = tbl.create({
        headers = { 'a', 'b' },
        rows = { { 'a1' } },
      })
      tbl.insert_column(t, 3, { header = 'c', cells = { 'c1' } })
      assert.same({ { 'a1', '', 'c1' } }, t.rows)
    end)

    it('errors on out-of-range indices', function()
      local t = tbl.create({ headers = { 'a' } })
      assert.error_matches(function()
        tbl.insert_column(t, 3)
      end, 'column index out of range')
    end)
  end)

  describe('delete_column', function()
    it('deletes the column across header, alignments, and rows', function()
      local t = tbl.create({
        headers = { 'a', 'b' },
        alignments = { 'left', 'right' },
        rows = { { 'a1', 'b1' }, { 'a2' } },
      })
      tbl.delete_column(t, 1)
      assert.same({ 'b' }, t.headers)
      assert.same({ 'right' }, t.alignments)
      assert.same({ { 'b1' }, {} }, t.rows)
    end)

    it('refuses to delete the only column', function()
      local t = tbl.create({ headers = { 'a' } })
      assert.error_matches(function()
        tbl.delete_column(t, 1)
      end, 'cannot delete the only column')
    end)

    it('errors on out-of-range indices', function()
      local t = tbl.create({ headers = { 'a', 'b' } })
      assert.error_matches(function()
        tbl.delete_column(t, 3)
      end, 'column index out of range')
    end)
  end)

  describe('move_column', function()
    it('moves the column across header, alignments, and rows', function()
      local t = tbl.create({
        headers = { 'a', 'b', 'c' },
        alignments = { 'left', 'center', 'right' },
        rows = { { 'a1', 'b1', 'c1' } },
      })
      tbl.move_column(t, 3, 1)
      assert.same({ 'c', 'a', 'b' }, t.headers)
      assert.same({ 'right', 'left', 'center' }, t.alignments)
      assert.same({ { 'c1', 'a1', 'b1' } }, t.rows)
    end)

    it('pads ragged rows before moving', function()
      local t = tbl.create({
        headers = { 'a', 'b' },
        rows = { { 'a1' } },
      })
      tbl.move_column(t, 2, 1)
      assert.same({ { '', 'a1' } }, t.rows)
    end)

    it('errors on out-of-range indices', function()
      local t = tbl.create({ headers = { 'a' } })
      assert.error_matches(function()
        tbl.move_column(t, 1, 2)
      end, 'column index out of range')
    end)
  end)
end)
