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
end)
