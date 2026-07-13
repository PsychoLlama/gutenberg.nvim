local strikethrough = require('gutenberg.api.strikethrough')

local with_buffer = require('gutenberg.tests.utils').with_buffer

describe('gutenberg.api.strikethrough', function()
  describe('is_strikethrough', function()
    it('returns true inside a strikethrough', function()
      with_buffer({ 'a ~~gone~~ b' }, { 1, 5 }, function(ctx)
        assert.is_true(strikethrough.is_strikethrough(ctx))
      end)
    end)

    it('returns false on plain text', function()
      with_buffer({ 'plain text' }, { 1, 3 }, function(ctx)
        assert.is_false(strikethrough.is_strikethrough(ctx))
      end)
    end)
  end)

  describe('read', function()
    -- The grammar renders `~~x~~` as a strikethrough nested inside a
    -- strikethrough; read must resolve the OUTER node so `replace` covers
    -- both `~~` runs.
    it('strips both `~~` runs and returns the outer node', function()
      with_buffer({ 'a ~~gone~~ b' }, { 1, 5 }, function(ctx)
        local value, node = strikethrough.read(ctx)
        assert.equal('gone', value.text)
        local _, sc, _, ec = node:range()
        assert.equal(2, sc)
        assert.equal(10, ec)
      end)
    end)

    it('errors off a span', function()
      with_buffer({ 'plain' }, { 1, 0 }, function(ctx)
        assert.error_matches(function()
          strikethrough.read(ctx)
        end, 'cursor is not on strikethrough')
      end)
    end)
  end)

  describe('render', function()
    it('emits `~~` delimiters', function()
      assert.equal('~~x~~', strikethrough.render({ text = 'x' }))
    end)

    it('round-trips through read', function()
      with_buffer({ 'a ~~gone~~ b' }, { 1, 5 }, function(ctx)
        assert.equal(
          '~~gone~~',
          strikethrough.render(strikethrough.read(ctx))
        )
      end)
    end)
  end)

  describe('replace', function()
    it('rewrites the whole span in place', function()
      with_buffer({ 'a ~~gone~~ b' }, { 1, 5 }, function(ctx)
        local value, node = strikethrough.read(ctx)
        strikethrough.set_text(value, 'new')
        strikethrough.replace(node, { value }, ctx)
        assert.same(
          { 'a ~~new~~ b' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('deletes both delimiter runs for an empty list', function()
      with_buffer({ 'a ~~gone~~ b' }, { 1, 5 }, function(ctx)
        local _, node = strikethrough.read(ctx)
        strikethrough.replace(node, {}, ctx)
        assert.same(
          { 'a  b' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)
  end)
end)
