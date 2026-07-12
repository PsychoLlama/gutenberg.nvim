local code_block = require('gutenberg.api.code_block')

local with_buffer = require('gutenberg.tests.utils').with_buffer

describe('gutenberg.api.code_block', function()
  describe('render', function()
    it('renders a backtick fence with a language', function()
      local block = {
        indent = '',
        fence = '`',
        fence_length = 3,
        info_string = 'lua',
        content = { "print('hi')" },
      }
      assert.same(
        { '```lua', "print('hi')", '```' },
        code_block.render(block)
      )
    end)

    it('renders a tilde fence', function()
      local block = {
        indent = '',
        fence = '~',
        fence_length = 3,
        info_string = 'python',
        content = { 'def f():', '    pass' },
      }
      assert.same(
        { '~~~python', 'def f():', '    pass', '~~~' },
        code_block.render(block)
      )
    end)

    it('renders a longer fence', function()
      local block = {
        indent = '',
        fence = '`',
        fence_length = 5,
        info_string = '',
        content = { 'foo' },
      }
      assert.same({ '`````', 'foo', '`````' }, code_block.render(block))
    end)

    it('renders without an info string', function()
      local block = {
        indent = '',
        fence = '`',
        fence_length = 3,
        info_string = '',
        content = { 'foo' },
      }
      assert.same({ '```', 'foo', '```' }, code_block.render(block))
    end)

    it('renders an empty block as just the two fences', function()
      local block = {
        indent = '',
        fence = '`',
        fence_length = 3,
        info_string = '',
        content = {},
      }
      assert.same({ '```', '```' }, code_block.render(block))
    end)

    it('preserves embedded blank lines in content', function()
      local block = {
        indent = '',
        fence = '`',
        fence_length = 3,
        info_string = 'lua',
        content = { 'a', '', 'b' },
      }
      assert.same({ '```lua', 'a', '', 'b', '```' }, code_block.render(block))
    end)

    it('applies indent to the fences but emits content verbatim', function()
      local block = {
        indent = '  ',
        fence = '`',
        fence_length = 3,
        info_string = 'lua',
        content = { 'inner', '    deeper' },
      }
      assert.same(
        { '  ```lua', 'inner', '    deeper', '  ```' },
        code_block.render(block)
      )
    end)

    it(
      'does NOT auto-escalate fence_length when content contains a closing-fence-like line',
      function()
        local block = {
          indent = '',
          fence = '`',
          fence_length = 3,
          info_string = '',
          content = { '```' },
        }
        assert.same({ '```', '```', '```' }, code_block.render(block))
      end
    )

    it(
      'round-trips cleanly when fence_length is bumped past embedded fences',
      function()
        with_buffer({
          '`````',
          'outer',
          '```',
          'inner',
          '```',
          '`````',
        }, { 1, 0 }, function(ctx)
          local block, _ = code_block.read(ctx)
          assert.same(
            { '`````', 'outer', '```', 'inner', '```', '`````' },
            code_block.render(block)
          )
        end)
      end
    )
  end)

  describe('is_code_block', function()
    it('returns true on the opening fence', function()
      with_buffer({ '```lua', "print('hi')", '```' }, { 1, 0 }, function(ctx)
        assert.is_true(code_block.is_code_block(ctx))
      end)
    end)

    it('returns true on a content line', function()
      with_buffer({ '```lua', "print('hi')", '```' }, { 2, 2 }, function(ctx)
        assert.is_true(code_block.is_code_block(ctx))
      end)
    end)

    it('returns true on the closing fence', function()
      with_buffer({ '```lua', "print('hi')", '```' }, { 3, 1 }, function(ctx)
        assert.is_true(code_block.is_code_block(ctx))
      end)
    end)

    it('returns true in the leading indent of an indented fence', function()
      with_buffer(
        { '  ```lua', "  print('hi')", '  ```' },
        { 1, 0 },
        function(ctx)
          assert.is_true(code_block.is_code_block(ctx))
        end
      )
    end)

    it('returns false on a paragraph', function()
      with_buffer({ 'just a paragraph' }, { 1, 2 }, function(ctx)
        assert.is_false(code_block.is_code_block(ctx))
      end)
    end)

    it('returns false on a list item', function()
      with_buffer({ '- foo' }, { 1, 2 }, function(ctx)
        assert.is_false(code_block.is_code_block(ctx))
      end)
    end)

    it('returns false on a heading', function()
      with_buffer({ '# heading' }, { 1, 2 }, function(ctx)
        assert.is_false(code_block.is_code_block(ctx))
      end)
    end)
  end)

  describe('read', function()
    it('reads a basic backtick block', function()
      with_buffer({ '```lua', "print('hi')", '```' }, { 2, 0 }, function(ctx)
        local block = code_block.read(ctx)
        assert.same({
          indent = '',
          fence = '`',
          fence_length = 3,
          info_string = 'lua',
          content = { "print('hi')" },
        }, block)
      end)
    end)

    it('parses a tilde fence', function()
      with_buffer(
        { '~~~python', 'def f():', '    pass', '~~~' },
        { 2, 0 },
        function(ctx)
          local block = code_block.read(ctx)
          assert.equal('~', block.fence)
          assert.equal(3, block.fence_length)
        end
      )
    end)

    it('captures a longer opening fence', function()
      with_buffer(
        { '`````lua', "print('hi')", '`````' },
        { 2, 0 },
        function(ctx)
          local block = code_block.read(ctx)
          assert.equal('`', block.fence)
          assert.equal(5, block.fence_length)
        end
      )
    end)

    it('preserves the info string verbatim including attributes', function()
      with_buffer(
        { '```{lua title="example"}', '-- code', '```' },
        { 2, 0 },
        function(ctx)
          local block = code_block.read(ctx)
          assert.equal('{lua title="example"}', block.info_string)
        end
      )
    end)

    it('reads an empty info string when none is present', function()
      with_buffer({ '```', 'foo', '```' }, { 2, 0 }, function(ctx)
        local block = code_block.read(ctx)
        assert.equal('', block.info_string)
      end)
    end)

    it('reads multi-line content with embedded blanks', function()
      with_buffer({ '```lua', 'a', '', 'b', '```' }, { 2, 0 }, function(ctx)
        local block = code_block.read(ctx)
        assert.same({ 'a', '', 'b' }, block.content)
      end)
    end)

    it('reads an empty content list', function()
      with_buffer({ '```lua', '```' }, { 1, 0 }, function(ctx)
        local block = code_block.read(ctx)
        assert.same({}, block.content)
      end)
    end)

    it('captures the indent of a top-level indented block', function()
      with_buffer({ '   ```lua', '   foo', '   ```' }, { 1, 3 }, function(ctx)
        local block = code_block.read(ctx)
        assert.equal('   ', block.indent)
      end)
    end)

    it('captures a block quote prefix as the indent', function()
      with_buffer({ '> ```lua', '> foo', '> ```' }, { 1, 4 }, function(ctx)
        local block = code_block.read(ctx)
        assert.equal('> ', block.indent)
        assert.equal('lua', block.info_string)
        assert.same({ '> foo' }, block.content)
      end)
    end)

    it('returns the fenced_code_block TSNode', function()
      with_buffer({ '```lua', 'foo', '```' }, { 1, 0 }, function(ctx)
        local _, node = code_block.read(ctx)
        assert.equal('fenced_code_block', node:type())
      end)
    end)

    it('round-trips read -> render', function()
      local lines = { '```lua', "print('hi')", '', "print('bye')", '```' }
      with_buffer(lines, { 2, 0 }, function(ctx)
        local block = code_block.read(ctx)
        assert.same(lines, code_block.render(block))
      end)
    end)
  end)

  describe('create', function()
    it('uses configured defaults when fields are omitted', function()
      local block = code_block.create({})
      assert.equal('', block.indent)
      assert.equal('`', block.fence)
      assert.equal(3, block.fence_length)
      assert.equal('', block.info_string)
      assert.same({}, block.content)
    end)

    it('honors an explicit indent', function()
      local block = code_block.create({ indent = '  ' })
      assert.equal('  ', block.indent)
    end)

    it('honors an explicit fence', function()
      local block = code_block.create({ fence = '~' })
      assert.equal('~', block.fence)
    end)

    it('honors an explicit fence_length', function()
      local block = code_block.create({ fence_length = 5 })
      assert.equal(5, block.fence_length)
    end)

    it('honors an explicit info_string', function()
      local block = code_block.create({ info_string = 'lua' })
      assert.equal('lua', block.info_string)
    end)

    it('honors explicit content', function()
      local block = code_block.create({ content = { 'a', 'b' } })
      assert.same({ 'a', 'b' }, block.content)
    end)
  end)

  describe('replace', function()
    it('rewrites the content of a block', function()
      with_buffer({ '```lua', "print('old')", '```' }, { 2, 0 }, function(ctx)
        local block, node = code_block.read(ctx)
        block.content = { "print('new')" }
        code_block.replace(node, { block }, ctx)
        assert.same(
          { '```lua', "print('new')", '```' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('changes the info string', function()
      with_buffer({ '```lua', "print('hi')", '```' }, { 1, 0 }, function(ctx)
        local block, node = code_block.read(ctx)
        code_block.set_info_string(block, 'python')
        code_block.replace(node, { block }, ctx)
        assert.same(
          { '```python', "print('hi')", '```' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('deletes the block when blocks is empty', function()
      with_buffer(
        { 'before', '```lua', 'foo', '```', 'after' },
        { 2, 0 },
        function(ctx)
          local _, node = code_block.read(ctx)
          code_block.replace(node, {}, ctx)
          assert.same(
            { 'before', 'after' },
            vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
          )
        end
      )
    end)

    it('swaps the fence type', function()
      with_buffer({ '```lua', 'foo', '```' }, { 1, 0 }, function(ctx)
        local block, node = code_block.read(ctx)
        block.fence = '~'
        code_block.replace(node, { block }, ctx)
        assert.same(
          { '~~~lua', 'foo', '~~~' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('preserves surrounding content', function()
      with_buffer({
        '# heading',
        '',
        '```lua',
        'foo',
        '```',
        '',
        'paragraph',
      }, { 3, 0 }, function(ctx)
        local block, node = code_block.read(ctx)
        block.content = { 'edited' }
        code_block.replace(node, { block }, ctx)
        assert.same({
          '# heading',
          '',
          '```lua',
          'edited',
          '```',
          '',
          'paragraph',
        }, vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false))
      end)
    end)

    it('rewrites the last block in the buffer', function()
      with_buffer(
        { 'before', '```lua', 'foo', '```' },
        { 2, 0 },
        function(ctx)
          local block, node = code_block.read(ctx)
          block.content = { 'edited' }
          code_block.replace(node, { block }, ctx)
          assert.same(
            { 'before', '```lua', 'edited', '```' },
            vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
          )
        end
      )
    end)

    it(
      'deletes the last block without leaving a trailing blank line',
      function()
        with_buffer(
          { 'before', '```lua', 'foo', '```' },
          { 2, 0 },
          function(ctx)
            local _, node = code_block.read(ctx)
            code_block.replace(node, {}, ctx)
            assert.same(
              { 'before' },
              vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
            )
          end
        )
      end
    )
  end)

  describe('get_info_string / set_info_string', function()
    it('reads and writes the info string verbatim', function()
      local block = code_block.create({ info_string = 'lua' })
      assert.equal('lua', code_block.get_info_string(block))
      code_block.set_info_string(block, '{python title="x"}')
      assert.equal('{python title="x"}', code_block.get_info_string(block))
    end)
  end)

  describe('get_content / set_content', function()
    it('reads and replaces the content array', function()
      local block = code_block.create({ content = { 'a' } })
      assert.same({ 'a' }, code_block.get_content(block))
      code_block.set_content(block, { 'b', 'c' })
      assert.same({ 'b', 'c' }, code_block.get_content(block))
    end)
  end)
end)
