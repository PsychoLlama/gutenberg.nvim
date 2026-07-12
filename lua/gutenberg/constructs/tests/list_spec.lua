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

    it('targets the cursor item plus the next count - 1', function()
      local lines = { '- [ ] a', '- b', '- [ ] c' }
      with_buffer(lines, { 1, 0 }, function(ctx)
        list.toggle_checkbox({
          bufnr = ctx.bufnr,
          cursor = ctx.cursor,
          count = 2,
        })
        assert.same(
          { '- [x] a', '- [x] b', '- [ ] c' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('counts through nested items in document order', function()
      local lines = { '- [ ] a', '  - [ ] nested', '- [ ] b' }
      with_buffer(lines, { 1, 0 }, function(ctx)
        list.toggle_checkbox({
          bufnr = ctx.bufnr,
          cursor = ctx.cursor,
          count = 2,
        })
        assert.same(
          { '- [x] a', '  - [x] nested', '- [ ] b' },
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
