local code_span = require('gutenberg.api.code_span')

local with_buffer = require('gutenberg.tests.utils').with_buffer

describe('gutenberg.api.code_span', function()
  describe('is_code_span', function()
    it('returns true inside a code span', function()
      with_buffer({ 'a `code` b' }, { 1, 5 }, function(ctx)
        assert.is_true(code_span.is_code_span(ctx))
      end)
    end)

    it('returns false on plain text', function()
      with_buffer({ 'plain text' }, { 1, 3 }, function(ctx)
        assert.is_false(code_span.is_code_span(ctx))
      end)
    end)
  end)

  describe('read', function()
    it('strips single backtick delimiters', function()
      with_buffer({ 'a `code` b' }, { 1, 5 }, function(ctx)
        assert.equal('code', code_span.read(ctx).text)
      end)
    end)

    it('strips one space of padding around a backtick', function()
      with_buffer({ 'a `` `x` `` b' }, { 1, 6 }, function(ctx)
        assert.equal('`x`', code_span.read(ctx).text)
      end)
    end)

    it('strips a single space of padding', function()
      with_buffer({ 'a ` x ` b' }, { 1, 5 }, function(ctx)
        assert.equal('x', code_span.read(ctx).text)
      end)
    end)

    it('keeps all-space content verbatim', function()
      with_buffer({ 'a `  ` b' }, { 1, 4 }, function(ctx)
        assert.equal('  ', code_span.read(ctx).text)
      end)
    end)

    it('does not strip a lone trailing space', function()
      with_buffer({ 'a `x ` b' }, { 1, 4 }, function(ctx)
        assert.equal('x ', code_span.read(ctx).text)
      end)
    end)

    it('errors off a span', function()
      with_buffer({ 'plain' }, { 1, 0 }, function(ctx)
        assert.error_matches(function()
          code_span.read(ctx)
        end, 'cursor is not on a code span')
      end)
    end)
  end)

  describe('render', function()
    it('wraps plain text in a single backtick', function()
      assert.equal('`x`', code_span.render({ text = 'x' }))
    end)

    it('escalates the fence past interior backtick runs', function()
      assert.equal('``a`b``', code_span.render({ text = 'a`b' }))
    end)

    it('pads text that begins or ends with a backtick', function()
      assert.equal('`` `x` ``', code_span.render({ text = '`x`' }))
    end)

    it('pads text with edge spaces', function()
      assert.equal('` x  `', code_span.render({ text = 'x ' }))
    end)

    it('does not pad all-space text', function()
      assert.equal('`  `', code_span.render({ text = '  ' }))
    end)

    it('round-trips the padded/escalated forms through read', function()
      for _, text in ipairs({ '`x`', 'a`b', 'x ', '  ', 'code' }) do
        with_buffer(
          { 'pre ' .. code_span.render({ text = text }) .. ' post' },
          { 1, 5 },
          function(ctx)
            assert.equal(text, code_span.read(ctx).text)
          end
        )
      end
    end)
  end)

  describe('replace', function()
    it('rewrites the span, re-escalating the fence', function()
      with_buffer({ 'a `code` b' }, { 1, 5 }, function(ctx)
        local value, node = code_span.read(ctx)
        code_span.set_text(value, 'a`b')
        code_span.replace(node, { value }, ctx)
        assert.same(
          { 'a ``a`b`` b' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)
  end)
end)
