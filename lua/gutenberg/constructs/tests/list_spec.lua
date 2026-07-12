local api = require('gutenberg.api.list')
local list = require('gutenberg.constructs.list')

local with_buffer = require('gutenberg.tests.utils').with_buffer

describe('gutenberg.list', function()
  describe('update', function()
    it('writes the mutated item back in one update', function()
      with_buffer({ '- foo', '- bar' }, { 1, 0 }, function(ctx)
        list.update(function(item)
          item.text = 'edited'
        end, ctx)
        assert.same(
          { '- edited', '- bar' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('writes the returned replacement list', function()
      with_buffer({ '- foo' }, { 1, 0 }, function(ctx)
        list.update(function(item)
          return { item, api.create({ text = 'new' }) }
        end, ctx)
        assert.same(
          { '- foo', '- new' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('deletes the item when fn returns an empty list', function()
      with_buffer({ '- foo', '- bar' }, { 1, 0 }, function(ctx)
        list.update(function()
          return {}
        end, ctx)
        assert.same(
          { '- bar' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('returns the written items', function()
      with_buffer({ '- foo' }, { 1, 0 }, function(ctx)
        local written = list.update(function(item)
          item.text = 'edited'
        end, ctx)
        assert.equal(1, #written)
        assert.equal('edited', written[1].text)
      end)
    end)

    it('errors when the cursor is not on a list item', function()
      with_buffer({ 'paragraph' }, { 1, 0 }, function(ctx)
        assert.error_matches(function()
          list.update(function() end, ctx)
        end, 'cursor is not on a list item')
      end)
    end)
  end)

  describe('update_list', function()
    it('rewrites every sibling in one update', function()
      with_buffer({ '- foo', '- bar' }, { 1, 0 }, function(ctx)
        list.update_list(function(entries)
          for _, entry in ipairs(entries) do
            entry.item.text = entry.item.text .. '!'
          end
        end, ctx)
        assert.same(
          { '- foo!', '- bar!' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)
  end)

  describe('toggle_checkbox', function()
    it('adds a checkbox in the configured default state', function()
      with_buffer({ '- foo' }, { 1, 0 }, function(ctx)
        list.toggle_checkbox(ctx)
        assert.same(
          { '- [x] foo' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('honors default_checked = false for new checkboxes', function()
      require('gutenberg.config').merge({
        list = { default_checked = false },
      })
      local ok, err = pcall(with_buffer, { '- foo' }, { 1, 0 }, function(ctx)
        list.toggle_checkbox(ctx)
        assert.same(
          { '- [ ] foo' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
      require('gutenberg.config').merge()
      if not ok then
        error(err)
      end
    end)

    it('unchecks a checked item', function()
      with_buffer({ '- [x] foo' }, { 1, 0 }, function(ctx)
        list.toggle_checkbox(ctx)
        assert.same(
          { '- [ ] foo' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('checks an unchecked item', function()
      with_buffer({ '- [ ] foo' }, { 1, 0 }, function(ctx)
        list.toggle_checkbox(ctx)
        assert.same(
          { '- [x] foo' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('ignores counts — bulk toggles come from ranges', function()
      local lines = { '- [ ] a', '- [ ] b' }
      with_buffer(lines, { 1, 0 }, function(ctx)
        list.toggle_checkbox({
          bufnr = ctx.bufnr,
          cursor = ctx.cursor,
          count = 2,
        })
        assert.same(
          { '- [x] a', '- [ ] b' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('checks all when any range target is unchecked or bare', function()
      local lines = { '- [x] a', '- b', '- [ ] c' }
      with_buffer(lines, { 1, 0 }, function(ctx)
        list.toggle_checkbox({
          bufnr = ctx.bufnr,
          range = { mode = 'line', start = { 1, 0 }, stop = { 3, 0 } },
        })
        assert.same(
          { '- [x] a', '- [x] b', '- [x] c' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('unchecks all when every range target is checked', function()
      local lines = { '- [x] a', '- [x] b' }
      with_buffer(lines, { 1, 0 }, function(ctx)
        list.toggle_checkbox({
          bufnr = ctx.bufnr,
          range = { mode = 'line', start = { 1, 0 }, stop = { 2, 0 } },
        })
        assert.same(
          { '- [ ] a', '- [ ] b' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('applies a bulk toggle as one buffer update', function()
      local lines = { '- [ ] a', 'paragraph splits the lists', '- [ ] b' }
      with_buffer(lines, { 1, 0 }, function(ctx)
        local tick = vim.b[ctx.bufnr].changedtick
        list.toggle_checkbox({
          bufnr = ctx.bufnr,
          range = { mode = 'line', start = { 1, 0 }, stop = { 3, 0 } },
        })
        assert.same(
          { '- [x] a', 'paragraph splits the lists', '- [x] b' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
        assert.equal(tick + 1, vim.b[ctx.bufnr].changedtick)
      end)
    end)

    it('errors when the range holds no list item', function()
      with_buffer({ 'paragraph' }, { 1, 0 }, function(ctx)
        assert.error_matches(function()
          list.toggle_checkbox({
            bufnr = ctx.bufnr,
            range = { mode = 'line', start = { 1, 0 }, stop = { 1, 0 } },
          })
        end, 'no list item in the selected range')
      end)
    end)
  end)

  describe('toggle_ordered', function()
    it('switches a bullet to an ordered marker', function()
      with_buffer({ '- foo', '- bar' }, { 2, 0 }, function(ctx)
        list.toggle_ordered(ctx)
        assert.same(
          { '- foo', '1. bar' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('switches an ordered marker back to a bullet', function()
      with_buffer({ '1. foo' }, { 1, 0 }, function(ctx)
        list.toggle_ordered(ctx)
        assert.same(
          { '- foo' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('renumbers count targets from the first target direction', function()
      local lines = { '- a', '- b', '- c' }
      with_buffer(lines, { 1, 0 }, function(ctx)
        list.toggle_ordered({
          bufnr = ctx.bufnr,
          cursor = ctx.cursor,
          count = 2,
        })
        assert.same(
          { '1. a', '2. b', '- c' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it(
      'switches a range to bullets when the first target is ordered',
      function()
        local lines = { '1. a', '2. b', '- c' }
        with_buffer(lines, { 1, 0 }, function(ctx)
          list.toggle_ordered({
            bufnr = ctx.bufnr,
            range = { mode = 'line', start = { 1, 0 }, stop = { 3, 0 } },
          })
          assert.same(
            { '- a', '- b', '- c' },
            vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
          )
        end)
      end
    )

    it('applies a range toggle as one buffer update', function()
      local lines = { '- a', '- b' }
      with_buffer(lines, { 1, 0 }, function(ctx)
        local tick = vim.b[ctx.bufnr].changedtick
        list.toggle_ordered({
          bufnr = ctx.bufnr,
          range = { mode = 'line', start = { 1, 0 }, stop = { 2, 0 } },
        })
        assert.same(
          { '1. a', '2. b' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
        assert.equal(tick + 1, vim.b[ctx.bufnr].changedtick)
      end)
    end)
  end)

  describe('indent', function()
    it('nests the item and renumbers both sibling groups', function()
      local lines = { '1. one', '2. two', '3. three' }
      with_buffer(lines, { 2, 0 }, function(ctx)
        list.indent(ctx)
        assert.same(
          { '1. one', '   1. two', '2. three' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end, { tabstop = 3 })
    end)

    it('preserves paren markers while renumbering', function()
      local lines = { '1) one', '2) two', '3) three' }
      with_buffer(lines, { 2, 0 }, function(ctx)
        list.indent(ctx)
        assert.same(
          { '1) one', '   1) two', '2) three' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end, { tabstop = 3 })
    end)

    it('moves nested children with the item', function()
      local lines = { '- a', '- b', '  - b1' }
      with_buffer(lines, { 2, 0 }, function(ctx)
        list.indent(ctx)
        assert.same(
          { '- a', '  - b', '    - b1' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('indents the first sibling with no new group', function()
      local lines = { '- a', '- b' }
      with_buffer(lines, { 1, 0 }, function(ctx)
        list.indent(ctx)
        assert.same(
          { '  - a', '- b' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('shifts count units', function()
      local lines = { '- a', '- b' }
      with_buffer(lines, { 2, 0 }, function(ctx)
        list.indent({ bufnr = ctx.bufnr, cursor = ctx.cursor, count = 2 })
        assert.same(
          { '- a', '    - b' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('uses a tab per unit when noexpandtab', function()
      local lines = { '- a', '- b' }
      with_buffer(lines, { 2, 0 }, function(ctx)
        list.indent(ctx)
        assert.same(
          { '- a', '\t- b' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end, { expandtab = false })
    end)

    it('shift and renumber land in one buffer update', function()
      local lines = { '1. one', '2. two', '3. three' }
      with_buffer(lines, { 2, 0 }, function(ctx)
        local tick = vim.b[ctx.bufnr].changedtick
        list.indent(ctx)
        assert.equal(tick + 1, vim.b[ctx.bufnr].changedtick)
      end, { tabstop = 3 })
    end)

    it('range: skips items whose parent item is also selected', function()
      local lines = { '- a', '  - a1', '- b', '- c' }
      with_buffer(lines, { 1, 0 }, function(ctx)
        list.indent({
          bufnr = ctx.bufnr,
          range = { mode = 'line', start = { 1, 0 }, stop = { 2, 0 } },
        })
        assert.same(
          { '  - a', '    - a1', '- b', '- c' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('errors when the cursor is not on a list item', function()
      with_buffer({ 'paragraph' }, { 1, 0 }, function(ctx)
        assert.error_matches(function()
          list.indent(ctx)
        end, 'cursor is not on a list item')
      end)
    end)
  end)

  describe('dedent', function()
    it('lifts the item and renumbers both sibling groups', function()
      local lines = { '1. one', '   1. two', '   2. three', '2. four' }
      with_buffer(lines, { 3, 0 }, function(ctx)
        list.dedent(ctx)
        assert.same(
          { '1. one', '   1. two', '2. three', '3. four' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end, { tabstop = 3 })
    end)

    it('renumbers across a marker-type boundary', function()
      local lines = { '- one', '  1. sub1', '  2. sub2', '- two' }
      with_buffer(lines, { 3, 0 }, function(ctx)
        list.dedent(ctx)
        assert.same(
          { '- one', '  1. sub1', '1. sub2', '- two' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('strips a tab per unit when noexpandtab', function()
      local lines = { '- a', '\t- b' }
      with_buffer(lines, { 2, 0 }, function(ctx)
        list.dedent(ctx)
        assert.same(
          { '- a', '- b' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end, { expandtab = false })
    end)

    it('errors before writing when whitespace is short', function()
      local lines = { '- a', '  - b' }
      with_buffer(lines, { 1, 0 }, function(ctx)
        local tick = vim.b[ctx.bufnr].changedtick
        assert.error_matches(function()
          list.dedent(ctx)
        end, 'cannot dedent: line lacks 2 leading whitespace')
        assert.equal(tick, vim.b[ctx.bufnr].changedtick)
      end)
    end)
  end)

  describe('toggle_ordered_list', function()
    it('numbers every sibling sequentially', function()
      with_buffer({ '- foo', '- bar', '- baz' }, { 2, 0 }, function(ctx)
        list.toggle_ordered_list(ctx)
        assert.same(
          { '1. foo', '2. bar', '3. baz' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('switches an ordered list back to bullets', function()
      with_buffer({ '1. foo', '2. bar' }, { 1, 0 }, function(ctx)
        list.toggle_ordered_list(ctx)
        assert.same(
          { '- foo', '- bar' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('preserves nested children', function()
      with_buffer({ '- foo', '  - nested', '- bar' }, { 1, 0 }, function(ctx)
        list.toggle_ordered_list(ctx)
        assert.same(
          { '1. foo', '  - nested', '2. bar' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)
  end)
end)
