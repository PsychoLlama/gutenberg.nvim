local api = require('gutenberg.api.code_block')
local code_block = require('gutenberg.constructs.code_block')

local with_buffer = require('gutenberg.tests.utils').with_buffer

describe('gutenberg.code_block', function()
  describe('update', function()
    it('writes the mutated block back in one update', function()
      with_buffer({ '```', 'code', '```' }, { 2, 0 }, function(ctx)
        code_block.update(function(block)
          api.set_info_string(block, 'lua')
        end, ctx)
        assert.same(
          { '```lua', 'code', '```' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('errors when the cursor is not on a code block', function()
      with_buffer({ 'paragraph' }, { 1, 0 }, function(ctx)
        assert.error_matches(function()
          code_block.update(function() end, ctx)
        end, 'cursor is not on a fenced code block')
      end)
    end)
  end)
end)
