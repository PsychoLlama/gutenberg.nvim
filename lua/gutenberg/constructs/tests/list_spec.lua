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
          { '- [ ] foo' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('honors default_checked = true for new checkboxes', function()
      require('gutenberg.config').merge({
        list = { default_checked = true },
      })
      local ok, err = pcall(with_buffer, { '- foo' }, { 1, 0 }, function(ctx)
        list.toggle_checkbox(ctx)
        assert.same(
          { '- [x] foo' },
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

  describe('remove_checkbox', function()
    it('strips the checkbox from the item at the cursor', function()
      with_buffer({ '- [x] foo' }, { 1, 0 }, function(ctx)
        list.remove_checkbox(ctx)
        assert.same(
          { '- foo' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('strips an unchecked checkbox too', function()
      with_buffer({ '- [ ] foo' }, { 1, 0 }, function(ctx)
        list.remove_checkbox(ctx)
        assert.same(
          { '- foo' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('leaves a plain item untouched', function()
      with_buffer({ '- foo' }, { 1, 0 }, function(ctx)
        local tick = vim.b[ctx.bufnr].changedtick
        list.remove_checkbox(ctx)
        assert.same(
          { '- foo' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
        assert.equal(tick, vim.b[ctx.bufnr].changedtick)
      end)
    end)

    it('preserves the ordered marker', function()
      with_buffer({ '1. [x] foo' }, { 1, 0 }, function(ctx)
        list.remove_checkbox(ctx)
        assert.same(
          { '1. foo' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('strips every item in a range in one update', function()
      local lines = { '- [x] a', '- b', '- [ ] c' }
      with_buffer(lines, { 1, 0 }, function(ctx)
        local tick = vim.b[ctx.bufnr].changedtick
        list.remove_checkbox({
          bufnr = ctx.bufnr,
          range = { mode = 'line', start = { 1, 0 }, stop = { 3, 0 } },
        })
        assert.same(
          { '- a', '- b', '- c' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
        assert.equal(tick + 1, vim.b[ctx.bufnr].changedtick)
      end)
    end)

    it('returns the written items', function()
      with_buffer({ '- [x] foo' }, { 1, 0 }, function(ctx)
        local written = list.remove_checkbox(ctx)
        assert.equal(1, #written)
        assert.is_nil(written[1].checkbox)
      end)
    end)

    it('errors when the cursor is not on a list item', function()
      with_buffer({ 'paragraph' }, { 1, 0 }, function(ctx)
        assert.error_matches(function()
          list.remove_checkbox(ctx)
        end, 'cursor is not on a list item')
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

    it('refuses to indent an item with no previous sibling', function()
      local lines = { '- a', '- b' }
      with_buffer(lines, { 1, 0 }, function(ctx)
        local tick = vim.b[ctx.bufnr].changedtick
        assert.error_matches(function()
          list.indent(ctx)
        end, 'no previous sibling to nest under')
        assert.equal(tick, vim.b[ctx.bufnr].changedtick)
      end)
    end)

    it('refuses to indent an only child further', function()
      local lines = { '- a', '  - a1' }
      with_buffer(lines, { 2, 4 }, function(ctx)
        assert.error_matches(function()
          list.indent(ctx)
        end, 'no previous sibling to nest under')
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

    it('widens the shift so ordered items actually nest', function()
      -- A 2-space unit alone leaves `3.` a sibling of `2.` — CommonMark
      -- needs the sibling's content column (3) — and nothing renumbers.
      local lines = { '1. first', '2. second', '3. third', '4. fourth' }
      with_buffer(lines, { 3, 0 }, function(ctx)
        list.indent(ctx)
        assert.same(
          { '1. first', '2. second', '   1. third', '3. fourth' },
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
      -- Selecting b and its child b1 indents only b (b1 travels with
      -- its parent); b nests under its previous sibling a.
      local lines = { '- a', '- b', '  - b1', '- c' }
      with_buffer(lines, { 1, 0 }, function(ctx)
        list.indent({
          bufnr = ctx.bufnr,
          range = { mode = 'line', start = { 2, 0 }, stop = { 3, 0 } },
        })
        assert.same(
          { '- a', '  - b', '    - b1', '- c' },
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

    it('strips the full nesting distance, not one unit', function()
      -- Nested at 3 columns with a 2-space unit: a unit strip would
      -- leave a stray column instead of landing on the parent's level.
      local lines = { '1. one', '   1. two', '2. three' }
      with_buffer(lines, { 2, 3 }, function(ctx)
        list.dedent(ctx)
        assert.same(
          { '1. one', '2. two', '3. three' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('clamps a count at the outermost level', function()
      local lines = { '- a', '  - b', '    - c' }
      with_buffer(lines, { 3, 4 }, function(ctx)
        list.dedent({ bufnr = ctx.bufnr, cursor = ctx.cursor, count = 5 })
        assert.same(
          { '- a', '  - b', '- c' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('errors before writing on a top-level item', function()
      local lines = { '- a', '  - b' }
      with_buffer(lines, { 1, 0 }, function(ctx)
        local tick = vim.b[ctx.bufnr].changedtick
        assert.error_matches(function()
          list.dedent(ctx)
        end, 'cannot dedent: item is already top%-level')
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

  --- Show the scratch buffer in the current window so a cursor-moving
  --- verb has a window to act on.
  ---@param ctx gutenberg.Context
  local function display(ctx)
    vim.api.nvim_win_set_buf(0, ctx.bufnr)
    vim.api.nvim_win_set_cursor(0, ctx.cursor)
  end

  describe('insert_item', function()
    it('appends a blank sibling below, cloning the bullet', function()
      with_buffer({ '- foo', '- bar' }, { 1, 0 }, function(ctx)
        list.insert_item({ where = 'below' }, ctx)
        assert.same(
          { '- foo', '- ', '- bar' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('defaults to inserting below', function()
      with_buffer({ '- foo' }, { 1, 0 }, function(ctx)
        list.insert_item(nil, ctx)
        assert.same(
          { '- foo', '- ' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('prepends a blank sibling above', function()
      with_buffer({ '- foo', '- bar' }, { 2, 0 }, function(ctx)
        list.insert_item({ where = 'above' }, ctx)
        assert.same(
          { '- foo', '- ', '- bar' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('renumbers ordered siblings around the new item', function()
      with_buffer(
        { '1. first', '2. second', '3. third' },
        { 1, 0 },
        function(ctx)
          list.insert_item({ where = 'below' }, ctx)
          assert.same(
            { '1. first', '2. ', '3. second', '4. third' },
            vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
          )
        end
      )
    end)

    it('renumbers when prepending to an ordered list', function()
      with_buffer({ '1. first', '2. second' }, { 1, 0 }, function(ctx)
        list.insert_item({ where = 'above' }, ctx)
        assert.same(
          { '1. ', '2. first', '3. second' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('clones an unchecked checkbox when the item has one', function()
      with_buffer({ '- [x] done' }, { 1, 0 }, function(ctx)
        list.insert_item({ where = 'below' }, ctx)
        assert.same(
          { '- [x] done', '- [ ] ' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('lands the new sibling past nested children', function()
      with_buffer({ '- foo', '  - child', '- bar' }, { 1, 0 }, function(ctx)
        list.insert_item({ where = 'below' }, ctx)
        assert.same(
          { '- foo', '  - child', '- ', '- bar' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('matches the nesting depth of the cursor item', function()
      with_buffer({ '- foo', '  - child' }, { 2, 4 }, function(ctx)
        list.insert_item({ where = 'below' }, ctx)
        assert.same(
          { '- foo', '  - child', '  - ' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('moves the cursor onto the new item', function()
      with_buffer({ '- foo' }, { 1, 0 }, function(ctx)
        display(ctx)
        list.insert_item({ where = 'below' }, ctx)
        -- End of the fresh '- ' line; normal mode clamps to the last
        -- column, and the keymap edge's `startinsert!` appends past it.
        assert.same({ 2, 1 }, vim.api.nvim_win_get_cursor(0))
      end)
    end)

    it('returns the inserted item', function()
      with_buffer({ '- foo' }, { 1, 0 }, function(ctx)
        local inserted = list.insert_item({ where = 'below' }, ctx)
        assert.equal('-', inserted.marker)
        assert.equal('', inserted.text)
      end)
    end)

    it('errors on an unknown `where`', function()
      with_buffer({ '- foo' }, { 1, 0 }, function(ctx)
        assert.error_matches(function()
          ---@diagnostic disable-next-line: assign-type-mismatch
          list.insert_item({ where = 'sideways' }, ctx)
        end, "'where' must be 'above' or 'below'")
      end)
    end)

    it('errors when the cursor is not on a list item', function()
      with_buffer({ 'paragraph' }, { 1, 0 }, function(ctx)
        assert.error_matches(function()
          list.insert_item({ where = 'below' }, ctx)
        end, 'cursor is not on a list item')
      end)
    end)
  end)

  describe('next_checkbox / prev_checkbox', function()
    local DOC = {
      '- [ ] a', -- row 1, unchecked
      '- [x] b', -- row 2, checked
      '- [ ] c', -- row 3, unchecked
      '- [x] d', -- row 4, checked
      '- [ ] e', -- row 5, unchecked
    }

    it('next_checkbox jumps to the next unchecked item', function()
      with_buffer(DOC, { 1, 0 }, function(ctx)
        display(ctx)
        local item = list.next_checkbox(ctx, { checked = false })
        assert.equal('c', item.text)
        assert.same({ 3, 0 }, vim.api.nvim_win_get_cursor(0))
      end)
    end)

    it('next_checkbox jumps to the next checked item', function()
      with_buffer(DOC, { 1, 0 }, function(ctx)
        display(ctx)
        local item = list.next_checkbox(ctx, { checked = true })
        assert.equal('b', item.text)
        assert.same({ 2, 0 }, vim.api.nvim_win_get_cursor(0))
      end)
    end)

    it('next_checkbox steps count matches', function()
      with_buffer(DOC, { 1, 0 }, function(ctx)
        display(ctx)
        list.next_checkbox(
          { bufnr = ctx.bufnr, cursor = ctx.cursor, count = 2 },
          { checked = false }
        )
        assert.same({ 5, 0 }, vim.api.nvim_win_get_cursor(0))
      end)
    end)

    it('next_checkbox clamps an overshooting count', function()
      with_buffer(DOC, { 1, 0 }, function(ctx)
        display(ctx)
        list.next_checkbox(
          { bufnr = ctx.bufnr, cursor = ctx.cursor, count = 9 },
          { checked = false }
        )
        assert.same({ 5, 0 }, vim.api.nvim_win_get_cursor(0))
      end)
    end)

    it('next_checkbox stays put and returns nil with no match', function()
      with_buffer(DOC, { 5, 0 }, function(ctx)
        display(ctx)
        local item = list.next_checkbox(ctx, { checked = false })
        assert.is_nil(item)
        assert.same({ 5, 0 }, vim.api.nvim_win_get_cursor(0))
      end)
    end)

    it('prev_checkbox jumps to the previous unchecked item', function()
      with_buffer(DOC, { 5, 0 }, function(ctx)
        display(ctx)
        local item = list.prev_checkbox(ctx, { checked = false })
        assert.equal('c', item.text)
        assert.same({ 3, 0 }, vim.api.nvim_win_get_cursor(0))
      end)
    end)

    it('prev_checkbox jumps to the previous checked item', function()
      with_buffer(DOC, { 5, 0 }, function(ctx)
        display(ctx)
        local item = list.prev_checkbox(ctx, { checked = true })
        assert.equal('d', item.text)
        assert.same({ 4, 0 }, vim.api.nvim_win_get_cursor(0))
      end)
    end)
  end)
end)
