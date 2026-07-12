local tbl = require('gutenberg.table')

---@param lines string[]
---@param cursor [integer, integer]
---@param fn fun(ctx: gutenberg.Context)
local function with_buffer(lines, cursor, fn)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[bufnr].filetype = 'markdown'
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  local ok, err = pcall(fn, { bufnr = bufnr, cursor = cursor })
  vim.api.nvim_buf_delete(bufnr, { force = true })
  if not ok then
    error(err)
  end
end

describe('gutenberg.table', function()
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
end)
