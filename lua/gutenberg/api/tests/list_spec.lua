local list = require('gutenberg.api.list')
local with_buffer = require('gutenberg.tests.utils').with_buffer

describe('gutenberg.api.list', function()
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

    it('returns true when the cursor is in the leading indent', function()
      with_buffer({ '  - foo' }, { 1, 0 }, function(ctx)
        assert.is_true(list.is_list_item(ctx))
      end)
    end)

    it('finds the nested item when the cursor is in its indent', function()
      with_buffer({ '- outer', '  - inner' }, { 2, 0 }, function(ctx)
        local item = list.read(ctx)
        assert.equal('inner', item.text)
      end)
    end)

    it('dedents an item with the cursor in the leading indent', function()
      with_buffer({ '- outer', '  - inner' }, { 2, 0 }, function(ctx)
        local _, node = list.read(ctx)
        list.dedent(node, ctx)
        assert.same(
          { '- outer', '- inner' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
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

  describe('replace_items', function()
    it('rewrites the marker on every sibling in one update', function()
      with_buffer({ '- foo', '- bar', '- baz' }, { 1, 2 }, function(ctx)
        local entries = list.read_list(ctx)
        for i, entry in ipairs(entries) do
          list.set_marker(entry.item, i .. '.')
        end
        list.replace_items(entries, ctx)
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
          local entries = list.read_list(ctx)
          for _, entry in ipairs(entries) do
            list.set_marker(entry.item, '*')
          end
          list.replace_items(entries, ctx)
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
          local entries = list.read_list(ctx)
          list.set_marker(entries[1].item, '*')
          list.set_marker(entries[2].item, '*')
          list.replace_items(entries, ctx)
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
        local entries = list.read_list(ctx)
        list.set_marker(entries[2].item, '*')
        list.replace_items({ entries[2] }, ctx)
        assert.same(
          { '- foo', '* bar', '- baz' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('rewrites entries from separate lists in one call', function()
      with_buffer(
        { '- foo', '', 'paragraph', '', '- bar' },
        { 1, 2 },
        function(ctx)
          local entries = list.items(ctx)
          for _, entry in ipairs(entries) do
            list.set_marker(entry.item, '*')
          end
          list.replace_items(entries, ctx)
          assert.same(
            { '* foo', '', 'paragraph', '', '* bar' },
            vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
          )
        end
      )
    end)
  end)

  describe('config.default_checked', function()
    it('defaults to true', function()
      require('gutenberg.config').merge()
      assert.is_true(require('gutenberg.config').get().list.default_checked)
    end)

    it('honors an override from setup', function()
      require('gutenberg.config').merge({ list = { default_checked = false } })
      local ok, err = pcall(function()
        assert.is_false(
          require('gutenberg.config').get().list.default_checked
        )
      end)
      require('gutenberg.config').merge()
      if not ok then
        error(err)
      end
    end)
  end)

  describe('is_ordered', function()
    it('returns true for `1.` markers', function()
      assert.is_true(list.is_ordered({ marker = '1.' }))
    end)

    it('returns true for `1)` markers', function()
      assert.is_true(list.is_ordered({ marker = '1)' }))
    end)

    it('returns true for multi-digit markers', function()
      assert.is_true(list.is_ordered({ marker = '42.' }))
    end)

    it('returns false for bullet markers', function()
      assert.is_false(list.is_ordered({ marker = '-' }))
      assert.is_false(list.is_ordered({ marker = '*' }))
      assert.is_false(list.is_ordered({ marker = '+' }))
    end)
  end)

  describe('set_ordered', function()
    it('promotes an unordered item to `1.`', function()
      local item = { marker = '-' }
      list.set_ordered(item, true)
      assert.equal('1.', item.marker)
    end)

    it('leaves an already-ordered marker untouched', function()
      local item = { marker = '3.' }
      list.set_ordered(item, true)
      assert.equal('3.', item.marker)
    end)

    it('demotes to the configured bullet marker', function()
      require('gutenberg.config').merge({ list = { marker = '*' } })
      local ok, err = pcall(function()
        local item = { marker = '1.' }
        list.set_ordered(item, false)
        assert.equal('*', item.marker)
      end)
      require('gutenberg.config').merge()
      if not ok then
        error(err)
      end
    end)

    it('leaves an already-bullet marker untouched', function()
      local item = { marker = '+' }
      list.set_ordered(item, false)
      assert.equal('+', item.marker)
    end)

    it('composes with replace_items to renumber siblings', function()
      with_buffer({ '- foo', '- bar', '- baz' }, { 1, 2 }, function(ctx)
        local entries = list.read_list(ctx)
        for i, entry in ipairs(entries) do
          list.set_ordered(entry.item, true)
          list.set_marker(entry.item, i .. '.')
        end
        list.replace_items(entries, ctx)
        assert.same(
          { '1. foo', '2. bar', '3. baz' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)
  end)

  describe('items', function()
    it('returns every item in document order, any depth', function()
      local lines = {
        '- one',
        '  - nested',
        '- two',
        '',
        'paragraph',
        '',
        '1. other list',
      }
      with_buffer(lines, { 1, 0 }, function(ctx)
        local entries = list.items(ctx)
        local texts = {}
        for _, entry in ipairs(entries) do
          table.insert(texts, entry.item.text)
        end
        assert.same({ 'one', 'nested', 'two', 'other list' }, texts)
      end)
    end)

    it('returns an empty table with no lists', function()
      with_buffer({ 'paragraph' }, { 1, 0 }, function(ctx)
        assert.same({}, list.items(ctx))
      end)
    end)
  end)

  describe('find_next / find_prev', function()
    local DOC = {
      '- [ ] a', -- row 1, unchecked
      '- [x] b', -- row 2, checked
      '- plain', -- row 3, no checkbox
      '- [ ] c', -- row 4, unchecked
      '- [x] d', -- row 5, checked
    }

    it('find_next returns the nearest item after the cursor row', function()
      with_buffer(DOC, { 1, 0 }, function(ctx)
        local item = list.find_next(ctx)
        assert.equal('b', item.text)
      end)
    end)

    it('find_next filters to unchecked items', function()
      with_buffer(DOC, { 1, 0 }, function(ctx)
        local item = list.find_next(ctx, { checked = false })
        assert.equal('c', item.text)
      end)
    end)

    it('find_next filters to checked items', function()
      with_buffer(DOC, { 1, 0 }, function(ctx)
        local item = list.find_next(ctx, { checked = true })
        assert.equal('b', item.text)
      end)
    end)

    it('find_next skips items without a checkbox under a filter', function()
      with_buffer(DOC, { 2, 0 }, function(ctx)
        -- Row 3 has no checkbox, so an unchecked filter jumps past it.
        local item = list.find_next(ctx, { checked = false })
        assert.equal('c', item.text)
      end)
    end)

    it('find_next returns nil when nothing qualifies', function()
      with_buffer(DOC, { 5, 0 }, function(ctx)
        assert.is_nil(list.find_next(ctx, { checked = true }))
      end)
    end)

    it('find_prev returns the nearest item before the cursor row', function()
      with_buffer(DOC, { 5, 0 }, function(ctx)
        local item = list.find_prev(ctx)
        assert.equal('c', item.text)
      end)
    end)

    it('find_prev filters to checked items', function()
      with_buffer(DOC, { 5, 0 }, function(ctx)
        local item = list.find_prev(ctx, { checked = true })
        assert.equal('b', item.text)
      end)
    end)

    it('find_prev filters to unchecked items', function()
      with_buffer(DOC, { 5, 0 }, function(ctx)
        local item = list.find_prev(ctx, { checked = false })
        assert.equal('c', item.text)
      end)
    end)

    it('find_prev returns nil when nothing qualifies', function()
      with_buffer(DOC, { 1, 0 }, function(ctx)
        assert.is_nil(list.find_prev(ctx, { checked = true }))
      end)
    end)
  end)

  describe('prepend', function()
    it('inserts rendered items above the node', function()
      with_buffer({ '- one', '- two' }, { 2, 0 }, function(ctx)
        local _, node = list.read(ctx)
        list.prepend(node, { list.create({ text = 'new' }) }, ctx)
        assert.same(
          { '- one', '- new', '- two' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('is a no-op with no items', function()
      with_buffer({ '- one' }, { 1, 0 }, function(ctx)
        local _, node = list.read(ctx)
        local tick = vim.b[ctx.bufnr].changedtick
        list.prepend(node, {}, ctx)
        assert.equal(tick, vim.b[ctx.bufnr].changedtick)
      end)
    end)
  end)

  describe('append', function()
    it('inserts rendered items below the node', function()
      with_buffer({ '- one', '- two' }, { 1, 0 }, function(ctx)
        local _, node = list.read(ctx)
        list.append(node, { list.create({ text = 'new' }) }, ctx)
        assert.same(
          { '- one', '- new', '- two' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('lands past nested children', function()
      with_buffer({ '- one', '  - nested', '- two' }, { 1, 0 }, function(ctx)
        local _, node = list.read(ctx)
        list.append(node, { list.create({ text = 'new' }) }, ctx)
        assert.same(
          { '- one', '  - nested', '- new', '- two' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('inserts multiple items in one update', function()
      with_buffer({ '- one' }, { 1, 0 }, function(ctx)
        local _, node = list.read(ctx)
        local tick = vim.b[ctx.bufnr].changedtick
        list.append(node, {
          list.create({ text = 'a' }),
          list.create({ text = 'b' }),
        }, ctx)
        assert.same(
          { '- one', '- a', '- b' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
        assert.equal(tick + 1, vim.b[ctx.bufnr].changedtick)
      end)
    end)

    it('is a no-op with no items', function()
      with_buffer({ '- one' }, { 1, 0 }, function(ctx)
        local _, node = list.read(ctx)
        local tick = vim.b[ctx.bufnr].changedtick
        list.append(node, {}, ctx)
        assert.equal(tick, vim.b[ctx.bufnr].changedtick)
      end)
    end)
  end)

  describe('insert', function()
    it('inserts before the item at index', function()
      with_buffer({ '- one', '- two' }, { 1, 0 }, function(ctx)
        local _, list_node = list.read_list(ctx)
        list.insert(list_node, 2, { list.create({ text = 'new' }) }, ctx)
        assert.same(
          { '- one', '- new', '- two' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('inserts at the head with index 1', function()
      with_buffer({ '- one' }, { 1, 0 }, function(ctx)
        local _, list_node = list.read_list(ctx)
        list.insert(list_node, 1, { list.create({ text = 'new' }) }, ctx)
        assert.same(
          { '- new', '- one' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('appends past the last item when index exceeds the list', function()
      with_buffer({ '- one', '  - nested' }, { 1, 0 }, function(ctx)
        local _, list_node = list.read_list(ctx)
        list.insert(list_node, 99, { list.create({ text = 'new' }) }, ctx)
        assert.same(
          { '- one', '  - nested', '- new' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('errors on a non-positive index', function()
      with_buffer({ '- one' }, { 1, 0 }, function(ctx)
        local _, list_node = list.read_list(ctx)
        assert.error_matches(function()
          list.insert(list_node, 0, { list.create({ text = 'new' }) }, ctx)
        end, 'index must be a positive integer')
      end)
    end)
  end)

  describe('renumber', function()
    it('renumbers ordered markers from 1', function()
      local items = {
        list.create({ marker = '4.' }),
        list.create({ marker = '9.' }),
      }
      list.renumber(items)
      assert.equal('1.', items[1].marker)
      assert.equal('2.', items[2].marker)
    end)

    it('preserves the paren delimiter', function()
      local items = {
        list.create({ marker = '7)' }),
        list.create({ marker = '2.' }),
      }
      list.renumber(items)
      assert.equal('1)', items[1].marker)
      assert.equal('2.', items[2].marker)
    end)

    it('skips unordered items without consuming a number', function()
      local items = {
        list.create({ marker = '5.' }),
        list.create({ marker = '-' }),
        list.create({ marker = '5.' }),
      }
      list.renumber(items)
      assert.equal('1.', items[1].marker)
      assert.equal('-', items[2].marker)
      assert.equal('2.', items[3].marker)
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

    it("falls back to the buffer's tabstop when expandtab is on", function()
      with_buffer({ '- foo' }, { 1, 2 }, function(ctx)
        local _, node = list.read(ctx)
        list.indent(node, ctx)
        assert.same(
          { '    - foo' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end, { expandtab = true, tabstop = 4 })
    end)

    it('falls back to a literal tab when expandtab is off', function()
      with_buffer({ '- foo' }, { 1, 2 }, function(ctx)
        local _, node = list.read(ctx)
        list.indent(node, ctx)
        assert.same(
          { '\t- foo' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end, { expandtab = false })
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
