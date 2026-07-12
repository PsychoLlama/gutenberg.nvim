local context = require('gutenberg.context')

describe('gutenberg.context', function()
  describe('resolve', function()
    it('defaults bufnr to the current buffer', function()
      local ctx = context.resolve()
      assert.equal(vim.api.nvim_get_current_buf(), ctx.bufnr)
    end)

    it('defaults cursor to the current window position', function()
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      local ctx = context.resolve()
      assert.same({ 1, 0 }, ctx.cursor)
    end)

    it('preserves bufnr when provided', function()
      local ctx = context.resolve({ bufnr = 42 })
      assert.equal(42, ctx.bufnr)
    end)

    it('preserves cursor when provided', function()
      local ctx = context.resolve({ cursor = { 5, 3 } })
      assert.same({ 5, 3 }, ctx.cursor)
    end)

    it('handles a nil argument', function()
      assert.has_no.error(function()
        context.resolve(nil)
      end)
    end)

    it('does not mutate the input', function()
      local input = { bufnr = 7 }
      context.resolve(input)
      assert.is_nil(input.cursor)
    end)

    it('returns a fresh table each call', function()
      local input = { bufnr = 7, cursor = { 1, 0 } }
      local a = context.resolve(input)
      local b = context.resolve(input)
      assert.are_not.equal(a, b)
      assert.are_not.equal(input, a)
    end)

    it('defaults count to 1', function()
      assert.equal(1, context.resolve().count)
    end)

    it('preserves count when provided', function()
      assert.equal(4, context.resolve({ count = 4 }).count)
    end)

    it('rejects non-positive counts', function()
      assert.has_error(function()
        context.resolve({ count = 0 })
      end, 'gutenberg: count must be a positive integer, got 0')
    end)

    it('rejects fractional counts', function()
      assert.has_error(function()
        context.resolve({ count = 1.5 })
      end, 'gutenberg: count must be a positive integer, got 1.5')
    end)

    it('passes a normalized range through', function()
      local ctx = context.resolve({
        range = { mode = 'char', start = { 2, 1 }, stop = { 3, 4 } },
      })
      assert.same(
        { mode = 'char', start = { 2, 1 }, stop = { 3, 4 } },
        ctx.range
      )
    end)

    it('swaps flipped range endpoints', function()
      local ctx = context.resolve({
        range = { mode = 'char', start = { 3, 4 }, stop = { 2, 1 } },
      })
      assert.same(
        { mode = 'char', start = { 2, 1 }, stop = { 3, 4 } },
        ctx.range
      )
    end)

    it('swaps flipped endpoints on the same row', function()
      local ctx = context.resolve({
        range = { mode = 'char', start = { 2, 6 }, stop = { 2, 1 } },
      })
      assert.same(
        { mode = 'char', start = { 2, 1 }, stop = { 2, 6 } },
        ctx.range
      )
    end)

    it('zeroes columns on line ranges', function()
      local ctx = context.resolve({
        range = { mode = 'line', start = { 2, 5 }, stop = { 4, 3 } },
      })
      assert.same(
        { mode = 'line', start = { 2, 0 }, stop = { 4, 0 } },
        ctx.range
      )
    end)

    it('rejects unknown range modes', function()
      assert.has_error(function()
        context.resolve({
          range = { mode = 'block', start = { 1, 0 }, stop = { 2, 0 } },
        })
      end, "gutenberg: range mode must be 'line' or 'char', got block")
    end)

    it('rejects ranges with malformed endpoints', function()
      assert.has_error(function()
        context.resolve({
          range = { mode = 'char', start = { 1 }, stop = { 2, 0 } },
        })
      end, 'gutenberg: range start/stop must be {row, col} pairs')
    end)

    it('does not mutate the input range', function()
      local range = { mode = 'line', start = { 4, 3 }, stop = { 2, 5 } }
      context.resolve({ range = range })
      assert.same({ mode = 'line', start = { 4, 3 }, stop = { 2, 5 } }, range)
    end)

    it('defaults cursor to the range start', function()
      local ctx = context.resolve({
        range = { mode = 'char', start = { 3, 2 }, stop = { 5, 1 } },
      })
      assert.same({ 3, 2 }, ctx.cursor)
    end)

    it('prefers an explicit cursor over the range start', function()
      local ctx = context.resolve({
        cursor = { 9, 0 },
        range = { mode = 'char', start = { 3, 2 }, stop = { 5, 1 } },
      })
      assert.same({ 9, 0 }, ctx.cursor)
    end)
  end)

  describe('range_from_visual', function()
    --- Make a visual selection in a scratch buffer, leave visual mode,
    --- and return the built range.
    ---@param lines string[]
    ---@param keys string
    ---@return gutenberg.Range
    local function select_and_build(lines, keys)
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
      vim.api.nvim_win_set_buf(0, bufnr)
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      vim.api.nvim_feedkeys(
        vim.api.nvim_replace_termcodes(keys, true, false, true),
        'nx',
        false
      )
      local ok, result = pcall(context.range_from_visual, bufnr)
      vim.api.nvim_buf_delete(bufnr, { force = true })
      if not ok then
        error(result)
      end
      return result
    end

    it('builds a charwise range from the last selection', function()
      local range = select_and_build({ 'alpha', 'beta' }, 'vjl<Esc>')
      assert.same({ mode = 'char', start = { 1, 0 }, stop = { 2, 1 } }, range)
    end)

    it('builds a linewise range with zeroed columns', function()
      local range =
        select_and_build({ 'alpha', 'beta', 'gamma' }, 'llVj<Esc>')
      assert.same({ mode = 'line', start = { 1, 0 }, stop = { 2, 0 } }, range)
    end)

    it('normalizes selections made bottom-up', function()
      local range = select_and_build({ 'alpha', 'beta' }, 'jVk<Esc>')
      assert.same({ mode = 'line', start = { 1, 0 }, stop = { 2, 0 } }, range)
    end)

    it('errors on blockwise selections', function()
      assert.has_error(function()
        select_and_build({ 'alpha', 'beta' }, '<C-v>j<Esc>')
      end, 'gutenberg: blockwise visual ranges are not supported')
    end)
  end)
end)
