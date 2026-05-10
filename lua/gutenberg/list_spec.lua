local list = require('gutenberg.list')

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

describe('gutenberg.list', function()
  describe('render', function()
    it('renders a basic bullet item', function()
      local item = { indent = '', marker = '-', checkbox = nil, text = 'foo' }
      assert.equal('- foo', list.render(item))
    end)

    it('preserves the indent', function()
      local item =
        { indent = '  ', marker = '-', checkbox = nil, text = 'foo' }
      assert.equal('  - foo', list.render(item))
    end)

    it('uses the configured marker', function()
      local item = { indent = '', marker = '*', checkbox = nil, text = 'foo' }
      assert.equal('* foo', list.render(item))
    end)

    it('renders ordered markers', function()
      local item =
        { indent = '', marker = '1.', checkbox = nil, text = 'foo' }
      assert.equal('1. foo', list.render(item))
    end)

    it('renders an unchecked checkbox', function()
      local item = { indent = '', marker = '-', checkbox = ' ', text = 'foo' }
      assert.equal('- [ ] foo', list.render(item))
    end)

    it('renders a checked checkbox', function()
      local item = { indent = '', marker = '-', checkbox = 'x', text = 'foo' }
      assert.equal('- [x] foo', list.render(item))
    end)

    it('preserves arbitrary checkbox states', function()
      local item = { indent = '', marker = '-', checkbox = '/', text = 'foo' }
      assert.equal('- [/] foo', list.render(item))
    end)

    it(
      'handles empty text without a trailing space after the marker',
      function()
        local item = { indent = '', marker = '-', checkbox = nil, text = '' }
        assert.equal('-', list.render(item))
      end
    )

    it('handles empty text with a checkbox', function()
      local item = { indent = '', marker = '-', checkbox = ' ', text = '' }
      assert.equal('- [ ]', list.render(item))
    end)
  end)

  describe('is_list_item', function()
    it('returns true on a bullet item', function()
      with_buffer({ '- foo' }, { 1, 2 }, function(ctx)
        assert.is_true(list.is_list_item(ctx))
      end)
    end)

    it('returns true on a numbered item', function()
      with_buffer({ '1. foo' }, { 1, 3 }, function(ctx)
        assert.is_true(list.is_list_item(ctx))
      end)
    end)

    it('returns true on a nested item', function()
      with_buffer({ '- outer', '  - inner' }, { 2, 4 }, function(ctx)
        assert.is_true(list.is_list_item(ctx))
      end)
    end)

    it('returns true on a checkbox item', function()
      with_buffer({ '- [ ] foo' }, { 1, 6 }, function(ctx)
        assert.is_true(list.is_list_item(ctx))
      end)
    end)

    it('returns true when the cursor is on the marker itself', function()
      with_buffer({ '- foo' }, { 1, 0 }, function(ctx)
        assert.is_true(list.is_list_item(ctx))
      end)
    end)

    it('returns false on a heading', function()
      with_buffer({ '# heading' }, { 1, 2 }, function(ctx)
        assert.is_false(list.is_list_item(ctx))
      end)
    end)

    it('returns false on a paragraph', function()
      with_buffer({ 'just a paragraph' }, { 1, 2 }, function(ctx)
        assert.is_false(list.is_list_item(ctx))
      end)
    end)

    it('returns false on a blank line', function()
      with_buffer({ '' }, { 1, 0 }, function(ctx)
        assert.is_false(list.is_list_item(ctx))
      end)
    end)
  end)

  describe('read', function()
    it('reads a basic bullet item', function()
      with_buffer({ '- foo' }, { 1, 2 }, function(ctx)
        local item = list.read(ctx)
        assert.same(
          { indent = '', marker = '-', checkbox = nil, text = 'foo' },
          item
        )
      end)
    end)

    it('reads a star marker', function()
      with_buffer({ '* foo' }, { 1, 2 }, function(ctx)
        assert.equal('*', list.read(ctx).marker)
      end)
    end)

    it('reads a plus marker', function()
      with_buffer({ '+ foo' }, { 1, 2 }, function(ctx)
        assert.equal('+', list.read(ctx).marker)
      end)
    end)

    it('reads a numbered marker', function()
      with_buffer({ '1. foo' }, { 1, 3 }, function(ctx)
        assert.equal('1.', list.read(ctx).marker)
      end)
    end)

    it('preserves the indent of a nested item', function()
      with_buffer({ '- outer', '  - inner' }, { 2, 4 }, function(ctx)
        local item = list.read(ctx)
        assert.equal('  ', item.indent)
        assert.equal('inner', item.text)
      end)
    end)

    it('reads an unchecked checkbox', function()
      with_buffer({ '- [ ] foo' }, { 1, 6 }, function(ctx)
        local item = list.read(ctx)
        assert.equal(' ', item.checkbox)
        assert.equal('foo', item.text)
      end)
    end)

    it('reads a checked checkbox', function()
      with_buffer({ '- [x] foo' }, { 1, 6 }, function(ctx)
        local item = list.read(ctx)
        assert.equal('x', item.checkbox)
        assert.equal('foo', item.text)
      end)
    end)

    it('reads an empty item', function()
      with_buffer({ '- ' }, { 1, 2 }, function(ctx)
        local item = list.read(ctx)
        assert.equal('-', item.marker)
        assert.equal('', item.text)
        assert.is_nil(item.checkbox)
      end)
    end)

    it('returns the TSNode for the item', function()
      with_buffer({ '- foo' }, { 1, 2 }, function(ctx)
        local _, node = list.read(ctx)
        assert.equal('list_item', node:type())
      end)
    end)

    it('returns the inner item node when nested', function()
      with_buffer({ '- outer', '  - inner' }, { 2, 4 }, function(ctx)
        local _, node = list.read(ctx)
        local sr, _, er, _ = node:range()
        assert.equal(1, sr)
        assert.equal(2, er)
      end)
    end)
  end)

  describe('replace', function()
    it('rewrites a single item in place', function()
      with_buffer({ '- foo', '- bar' }, { 1, 2 }, function(ctx)
        local item, node = list.read(ctx)
        item.text = 'edited'
        list.replace(node, { item }, ctx)
        assert.same(
          { '- edited', '- bar' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('deletes the item when items is empty', function()
      with_buffer({ '- foo', '- bar' }, { 1, 2 }, function(ctx)
        local _, node = list.read(ctx)
        list.replace(node, {}, ctx)
        assert.same(
          { '- bar' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('expands one item into many', function()
      with_buffer({ '- foo' }, { 1, 2 }, function(ctx)
        local item, node = list.read(ctx)
        list.replace(node, { item, list.create({ text = 'new' }) }, ctx)
        assert.same(
          { '- foo', '- new' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('preserves surrounding non-list content', function()
      with_buffer(
        { '# heading', '', '- foo', '', 'paragraph' },
        { 3, 2 },
        function(ctx)
          local item, node = list.read(ctx)
          item.text = 'edited'
          list.replace(node, { item }, ctx)
          assert.same({
            '# heading',
            '',
            '- edited',
            '',
            'paragraph',
          }, vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false))
        end
      )
    end)

    it('rewrites a nested item without disturbing siblings', function()
      with_buffer(
        { '- outer', '  - inner', '- last' },
        { 2, 4 },
        function(ctx)
          local item, node = list.read(ctx)
          item.text = 'edited'
          list.replace(node, { item }, ctx)
          assert.same({
            '- outer',
            '  - edited',
            '- last',
          }, vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false))
        end
      )
    end)

    it('rewrites the last item in the buffer', function()
      with_buffer({ '- foo', '- bar' }, { 2, 2 }, function(ctx)
        local item, node = list.read(ctx)
        item.text = 'edited'
        list.replace(node, { item }, ctx)
        assert.same(
          { '- foo', '- edited' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it(
      'deletes the last item without leaving a trailing blank line',
      function()
        with_buffer({ '- foo', '- bar' }, { 2, 2 }, function(ctx)
          local _, node = list.read(ctx)
          list.replace(node, {}, ctx)
          assert.same(
            { '- foo' },
            vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
          )
        end)
      end
    )
  end)

  describe('read_list', function()
    it('returns every direct sibling at the cursor level', function()
      with_buffer({ '- foo', '- bar', '- baz' }, { 2, 2 }, function(ctx)
        local entries = list.read_list(ctx)
        assert.equal(3, #entries)
        assert.equal('foo', entries[1].item.text)
        assert.equal('bar', entries[2].item.text)
        assert.equal('baz', entries[3].item.text)
      end)
    end)

    it('returns the parent list TSNode', function()
      with_buffer({ '- foo' }, { 1, 2 }, function(ctx)
        local _, list_node = list.read_list(ctx)
        assert.equal('list', list_node:type())
      end)
    end)

    it('limits siblings to the cursor item level when nested', function()
      with_buffer(
        { '- outer', '  - inner1', '  - inner2', '- last' },
        { 2, 4 },
        function(ctx)
          local entries = list.read_list(ctx)
          assert.equal(2, #entries)
          assert.equal('inner1', entries[1].item.text)
          assert.equal('inner2', entries[2].item.text)
        end
      )
    end)

    it('errors when the cursor is not on a list item', function()
      with_buffer({ 'paragraph' }, { 1, 0 }, function(ctx)
        assert.has_error(function()
          list.read_list(ctx)
        end)
      end)
    end)
  end)

  describe('replace_list', function()
    it('rewrites the marker on every sibling in one update', function()
      with_buffer({ '- foo', '- bar', '- baz' }, { 1, 2 }, function(ctx)
        local entries, list_node = list.read_list(ctx)
        for i, entry in ipairs(entries) do
          list.set_marker(entry.item, i .. '.')
        end
        list.replace_list(list_node, entries, ctx)
        assert.same(
          { '1. foo', '2. bar', '3. baz' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('preserves nested children verbatim', function()
      with_buffer(
        { '- outer1', '  - inner', '- outer2' },
        { 1, 2 },
        function(ctx)
          local entries, list_node = list.read_list(ctx)
          for _, entry in ipairs(entries) do
            list.set_marker(entry.item, '*')
          end
          list.replace_list(list_node, entries, ctx)
          assert.same({
            '* outer1',
            '  - inner',
            '* outer2',
          }, vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false))
        end
      )
    end)

    it('preserves surrounding non-list content', function()
      with_buffer(
        { '# heading', '', '- foo', '- bar', '', 'paragraph' },
        { 3, 2 },
        function(ctx)
          local entries, list_node = list.read_list(ctx)
          list.set_marker(entries[1].item, '*')
          list.set_marker(entries[2].item, '*')
          list.replace_list(list_node, entries, ctx)
          assert.same({
            '# heading',
            '',
            '* foo',
            '* bar',
            '',
            'paragraph',
          }, vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false))
        end
      )
    end)

    it('rewrites a subset of siblings without touching the rest', function()
      with_buffer({ '- foo', '- bar', '- baz' }, { 1, 2 }, function(ctx)
        local entries, list_node = list.read_list(ctx)
        list.set_marker(entries[2].item, '*')
        list.replace_list(list_node, { entries[2] }, ctx)
        assert.same(
          { '- foo', '* bar', '- baz' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)
  end)

  describe('indent', function()
    it('shifts a leaf item right by config.list.indent', function()
      with_buffer({ '- foo', '- bar' }, { 1, 2 }, function(ctx)
        local _, node = list.read(ctx)
        list.indent(node, ctx)
        assert.same(
          { '  - foo', '- bar' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('shifts an item and its nested children together', function()
      with_buffer(
        { '- outer', '  - inner', '- last' },
        { 1, 2 },
        function(ctx)
          local _, node = list.read(ctx)
          list.indent(node, ctx)
          assert.same({
            '  - outer',
            '    - inner',
            '- last',
          }, vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false))
        end
      )
    end)

    it('honors a custom config.list.indent', function()
      require('gutenberg.config').merge({ list = { indent = '\t' } })
      local ok, err = pcall(function()
        with_buffer({ '- foo' }, { 1, 2 }, function(ctx)
          local _, node = list.read(ctx)
          list.indent(node, ctx)
          assert.same(
            { '\t- foo' },
            vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
          )
        end)
      end)
      require('gutenberg.config').merge({})
      if not ok then
        error(err)
      end
    end)
  end)

  describe('dedent', function()
    it('shifts a nested item left by config.list.indent', function()
      with_buffer({ '- outer', '  - inner' }, { 2, 4 }, function(ctx)
        local _, node = list.read(ctx)
        list.dedent(node, ctx)
        assert.same(
          { '- outer', '- inner' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('shifts an item and its nested children together', function()
      with_buffer(
        { '  - outer', '    - inner', '- last' },
        { 1, 4 },
        function(ctx)
          local _, node = list.read(ctx)
          list.dedent(node, ctx)
          assert.same({
            '- outer',
            '  - inner',
            '- last',
          }, vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false))
        end
      )
    end)

    it(
      'errors when the item lacks the required leading whitespace',
      function()
        with_buffer({ '- foo' }, { 1, 2 }, function(ctx)
          local _, node = list.read(ctx)
          assert.has_error(function()
            list.dedent(node, ctx)
          end)
        end)
      end
    )
  end)
end)
