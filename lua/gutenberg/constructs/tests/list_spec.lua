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
