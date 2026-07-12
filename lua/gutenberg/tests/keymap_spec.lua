local keymap = require('gutenberg.keymap')
local utils = require('gutenberg.tests.utils')

describe('gutenberg.keymap', function()
  ---@param keys string
  local function feed(keys)
    vim.api.nvim_feedkeys(
      vim.api.nvim_replace_termcodes(keys, true, false, true),
      'x',
      false
    )
  end

  --- Run `fn` with the scratch buffer displayed so mappings and
  --- feedkeys act on it, collecting notifications.
  ---@param lines string[]
  ---@param fn fun(bufnr: integer, notified: string[])
  local function with_keymap_buffer(lines, fn)
    utils.with_buffer(lines, { 1, 0 }, function(ctx)
      vim.api.nvim_win_set_buf(0, ctx.bufnr)
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      ---@type string[]
      local notified = {}
      local original = vim.notify
      vim.notify = function(msg)
        table.insert(notified, tostring(msg))
      end
      local ok, err = pcall(fn, ctx.bufnr, notified)
      vim.notify = original
      if not ok then
        error(err)
      end
    end)
  end

  describe('repeatable', function()
    it('delivers the count on the press, on ., and on 5.', function()
      with_keymap_buffer({ 'aaa', 'bbb' }, function(bufnr)
        ---@type integer[]
        local counts = {}
        vim.keymap.set(
          'n',
          'gT',
          keymap.repeatable(function(ctx)
            table.insert(counts, ctx.count)
          end),
          { buffer = bufnr, expr = true }
        )

        feed('gT')
        feed('3gT')
        feed('.')
        feed('5.')
        assert.same({ 1, 3, 3, 5 }, counts)
      end)
    end)

    it('notifies instead of throwing', function()
      with_keymap_buffer({ 'aaa' }, function(bufnr, notified)
        vim.keymap.set(
          'n',
          'gT',
          keymap.repeatable(function()
            error('gutenberg: boom', 0)
          end),
          { buffer = bufnr, expr = true }
        )

        feed('gT')
        assert.same({ 'gutenberg: boom' }, notified)
      end)
    end)
  end)

  describe('operator', function()
    it('hands the motion range to the callback', function()
      with_keymap_buffer({ 'hello world' }, function(bufnr)
        ---@type gutenberg.Range?
        local range
        vim.keymap.set(
          'n',
          'gT',
          keymap.operator(function(ctx)
            range = ctx.range
          end),
          { buffer = bufnr, expr = true }
        )

        feed('gTiw')
        assert.same({
          mode = 'char',
          start = { 1, 0 },
          stop = { 1, 4 },
        }, range)
      end)
    end)

    it('builds a linewise range from linewise motions', function()
      with_keymap_buffer({ 'one', 'two', 'three' }, function(bufnr)
        ---@type gutenberg.Range?
        local range
        vim.keymap.set(
          'n',
          'gT',
          keymap.operator(function(ctx)
            range = ctx.range
          end),
          { buffer = bufnr, expr = true }
        )

        feed('gTj')
        assert.equal('line', range.mode)
        assert.equal(1, range.start[1])
        assert.equal(2, range.stop[1])
      end)
    end)

    it('notifies on blockwise-forced motions', function()
      with_keymap_buffer({ 'one', 'two' }, function(bufnr, notified)
        local called = false
        vim.keymap.set(
          'n',
          'gT',
          keymap.operator(function()
            called = true
          end),
          { buffer = bufnr, expr = true }
        )

        feed('gT<C-v>j')
        assert.is_false(called)
        assert.same(
          { 'gutenberg: blockwise selections are not supported' },
          notified
        )
      end)
    end)
  end)

  describe('visual', function()
    it('reads the live charwise selection', function()
      with_keymap_buffer({ 'hello world' }, function(bufnr)
        ---@type gutenberg.Range?
        local range
        vim.keymap.set(
          'x',
          'gT',
          keymap.visual(function(ctx)
            range = ctx.range
          end),
          { buffer = bufnr }
        )

        feed('vllgT')
        assert.same({
          mode = 'char',
          start = { 1, 0 },
          stop = { 1, 2 },
        }, range)
        assert.equal('n', vim.fn.mode())
      end)
    end)

    it('normalizes a backwards selection', function()
      with_keymap_buffer({ 'hello world' }, function(bufnr)
        ---@type gutenberg.Range?
        local range
        vim.keymap.set(
          'x',
          'gT',
          keymap.visual(function(ctx)
            range = ctx.range
          end),
          { buffer = bufnr }
        )

        feed('$vhhgT')
        assert.same({
          mode = 'char',
          start = { 1, 8 },
          stop = { 1, 10 },
        }, range)
      end)
    end)

    it('reads linewise selections', function()
      with_keymap_buffer({ 'one', 'two', 'three' }, function(bufnr)
        ---@type gutenberg.Range?
        local range
        vim.keymap.set(
          'x',
          'gT',
          keymap.visual(function(ctx)
            range = ctx.range
          end),
          { buffer = bufnr }
        )

        feed('VjgT')
        assert.equal('line', range.mode)
        assert.equal(1, range.start[1])
        assert.equal(2, range.stop[1])
      end)
    end)

    it('notifies on blockwise selections', function()
      with_keymap_buffer({ 'one', 'two' }, function(bufnr, notified)
        local called = false
        vim.keymap.set(
          'x',
          'gT',
          keymap.visual(function()
            called = true
          end),
          { buffer = bufnr }
        )

        feed('<C-v>jgT')
        feed('<Esc>')
        assert.is_false(called)
        assert.same(
          { 'gutenberg: blockwise selections are not supported' },
          notified
        )
      end)
    end)

    it('notifies instead of throwing', function()
      with_keymap_buffer({ 'aaa' }, function(bufnr, notified)
        vim.keymap.set(
          'x',
          'gT',
          keymap.visual(function()
            error('gutenberg: boom', 0)
          end),
          { buffer = bufnr }
        )

        feed('vgT')
        assert.same({ 'gutenberg: boom' }, notified)
      end)
    end)
  end)
end)
