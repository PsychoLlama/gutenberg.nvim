local link = require('gutenberg.link')

local with_buffer = require('gutenberg.tests.utils').with_buffer

describe('gutenberg.link', function()
  describe('render', function()
    it('renders an inline link without a title', function()
      assert.equal(
        '[hi](https://example.com)',
        link.render({
          kind = 'inline',
          text = 'hi',
          url = 'https://example.com',
        })
      )
    end)

    it('renders an inline link with a title', function()
      assert.equal(
        '[hi](https://example.com "site")',
        link.render({
          kind = 'inline',
          text = 'hi',
          url = 'https://example.com',
          title = 'site',
        })
      )
    end)

    it('renders a reference_full link', function()
      assert.equal(
        '[hi][L]',
        link.render({ kind = 'reference_full', text = 'hi', label = 'L' })
      )
    end)

    it('renders a reference_collapsed link', function()
      assert.equal(
        '[hi][]',
        link.render({
          kind = 'reference_collapsed',
          text = 'hi',
          label = 'hi',
        })
      )
    end)

    it('renders a reference_shortcut link', function()
      assert.equal(
        '[hi]',
        link.render({ kind = 'reference_shortcut', text = 'hi', label = 'hi' })
      )
    end)

    it('renders an autolink', function()
      assert.equal(
        '<https://example.com>',
        link.render({ kind = 'autolink', url = 'https://example.com' })
      )
    end)

    it('does NOT escape special characters', function()
      assert.equal(
        '[a]b](c)d)',
        link.render({ kind = 'inline', text = 'a]b', url = 'c)d' })
      )
    end)
  end)

  describe('is_link', function()
    it('returns true on an inline link', function()
      with_buffer(
        { 'see [foo](https://x.example) end' },
        { 1, 5 },
        function(ctx)
          assert.is_true(link.is_link(ctx))
        end
      )
    end)

    it('returns true on a reference_full link', function()
      with_buffer({ 'see [foo][bar] end' }, { 1, 6 }, function(ctx)
        assert.is_true(link.is_link(ctx))
      end)
    end)

    it('returns true on a reference_collapsed link', function()
      with_buffer({ 'see [foo][] end' }, { 1, 6 }, function(ctx)
        assert.is_true(link.is_link(ctx))
      end)
    end)

    it('returns true on a reference_shortcut link', function()
      with_buffer({ 'see [foo] end' }, { 1, 6 }, function(ctx)
        assert.is_true(link.is_link(ctx))
      end)
    end)

    it('returns true on an autolink', function()
      with_buffer({ 'see <https://x.example> end' }, { 1, 8 }, function(ctx)
        assert.is_true(link.is_link(ctx))
      end)
    end)

    it('returns false on plain text', function()
      with_buffer({ 'just some prose' }, { 1, 4 }, function(ctx)
        assert.is_false(link.is_link(ctx))
      end)
    end)

    it('returns false on an image', function()
      with_buffer({ '![alt](pic.png)' }, { 1, 3 }, function(ctx)
        assert.is_false(link.is_link(ctx))
      end)
    end)

    it('returns false on a link reference definition', function()
      with_buffer({ '[L]: https://x.example' }, { 1, 1 }, function(ctx)
        assert.is_false(link.is_link(ctx))
      end)
    end)

    it('returns false on a list item', function()
      with_buffer({ '- foo' }, { 1, 2 }, function(ctx)
        assert.is_false(link.is_link(ctx))
      end)
    end)
  end)

  describe('is_definition', function()
    it('returns true on a definition', function()
      with_buffer({ '[L]: https://x.example' }, { 1, 1 }, function(ctx)
        assert.is_true(link.is_definition(ctx))
      end)
    end)

    it(
      'returns true in the leading indent of an indented definition',
      function()
        with_buffer({ '  [L]: https://x.example' }, { 1, 0 }, function(ctx)
          assert.is_true(link.is_definition(ctx))
        end)
      end
    )

    it('returns false inside a regular link', function()
      with_buffer({ '[foo](bar)' }, { 1, 1 }, function(ctx)
        assert.is_false(link.is_definition(ctx))
      end)
    end)

    it('returns false on plain text', function()
      with_buffer({ 'just text' }, { 1, 2 }, function(ctx)
        assert.is_false(link.is_definition(ctx))
      end)
    end)
  end)

  describe('read_definition', function()
    it('reads a definition with no title', function()
      with_buffer({ '[L]: https://x.example' }, { 1, 1 }, function(ctx)
        local def = link.read_definition(ctx)
        assert.equal('L', def.label)
        assert.equal('https://x.example', def.url)
        assert.is_nil(def.title)
      end)
    end)

    it('reads a definition with a quoted title', function()
      with_buffer({ '[L]: https://x.example "site"' }, { 1, 1 }, function(ctx)
        local def = link.read_definition(ctx)
        assert.equal('L', def.label)
        assert.equal('https://x.example', def.url)
        assert.equal('site', def.title)
      end)
    end)

    it('returns the TSNode for the definition', function()
      with_buffer({ '[L]: https://x.example' }, { 1, 1 }, function(ctx)
        local _, node = link.read_definition(ctx)
        assert.equal('link_reference_definition', node:type())
      end)
    end)

    it('errors when not on a definition', function()
      with_buffer({ 'plain' }, { 1, 0 }, function(ctx)
        assert.has_error(function()
          link.read_definition(ctx)
        end)
      end)
    end)
  end)

  describe('read', function()
    it('reads an inline link without a title', function()
      with_buffer(
        { 'pre [foo](https://x.example) post' },
        { 1, 6 },
        function(ctx)
          local result = link.read(ctx)
          assert.equal('inline', result.kind)
          assert.equal('foo', result.text)
          assert.equal('https://x.example', result.url)
          assert.is_nil(result.title)
          assert.is_nil(result.label)
        end
      )
    end)

    it('reads an inline link with a title', function()
      with_buffer(
        { 'pre [foo](https://x.example "site") post' },
        { 1, 6 },
        function(ctx)
          local result = link.read(ctx)
          assert.equal('inline', result.kind)
          assert.equal('foo', result.text)
          assert.equal('https://x.example', result.url)
          assert.equal('site', result.title)
        end
      )
    end)

    it('reads a reference_full link', function()
      with_buffer({ 'pre [foo][L] post' }, { 1, 6 }, function(ctx)
        local result = link.read(ctx)
        assert.equal('reference_full', result.kind)
        assert.equal('foo', result.text)
        assert.equal('L', result.label)
        assert.is_nil(result.url)
      end)
    end)

    it('reads a reference_collapsed link', function()
      with_buffer({ 'pre [foo][] post' }, { 1, 6 }, function(ctx)
        local result = link.read(ctx)
        assert.equal('reference_collapsed', result.kind)
        assert.equal('foo', result.text)
        assert.equal('foo', result.label)
        assert.is_nil(result.url)
      end)
    end)

    it('reads a reference_shortcut link', function()
      with_buffer({ 'pre [foo] post' }, { 1, 6 }, function(ctx)
        local result = link.read(ctx)
        assert.equal('reference_shortcut', result.kind)
        assert.equal('foo', result.text)
        assert.equal('foo', result.label)
      end)
    end)

    it('reads an autolink', function()
      with_buffer({ 'pre <https://x.example> post' }, { 1, 6 }, function(ctx)
        local result = link.read(ctx)
        assert.equal('autolink', result.kind)
        assert.equal('https://x.example', result.url)
        assert.is_nil(result.text)
      end)
    end)

    it('returns a TSNode covering the link', function()
      with_buffer(
        { 'pre [foo](https://x.example) post' },
        { 1, 6 },
        function(ctx)
          local _, node = link.read(ctx)
          local sr, sc, er, ec = node:range()
          assert.equal(0, sr)
          assert.equal(4, sc)
          assert.equal(0, er)
          assert.equal(28, ec)
        end
      )
    end)

    it('errors when the cursor is not on a link', function()
      with_buffer({ 'plain' }, { 1, 0 }, function(ctx)
        assert.has_error(function()
          link.read(ctx)
        end)
      end)
    end)
  end)

  describe('create', function()
    it('builds an inline link', function()
      local result = link.create({
        kind = 'inline',
        text = 'foo',
        url = 'https://x.example',
      })
      assert.equal('inline', result.kind)
      assert.equal('foo', result.text)
      assert.equal('https://x.example', result.url)
    end)

    it('preserves the title on an inline link', function()
      local result = link.create({
        kind = 'inline',
        text = 'foo',
        url = 'https://x.example',
        title = 'site',
      })
      assert.equal('site', result.title)
    end)

    it('builds a reference_full link', function()
      local result =
        link.create({ kind = 'reference_full', text = 'foo', label = 'L' })
      assert.equal('foo', result.text)
      assert.equal('L', result.label)
    end)

    it('mirrors text into label for reference_collapsed', function()
      local result =
        link.create({ kind = 'reference_collapsed', text = 'foo' })
      assert.equal('foo', result.label)
    end)

    it('mirrors text into label for reference_shortcut', function()
      local result =
        link.create({ kind = 'reference_shortcut', text = 'foo' })
      assert.equal('foo', result.label)
    end)

    it('builds an autolink', function()
      local result =
        link.create({ kind = 'autolink', url = 'https://x.example' })
      assert.equal('autolink', result.kind)
      assert.equal('https://x.example', result.url)
    end)

    it('defaults kind from config', function()
      local result = link.create({ text = 'foo', url = 'https://x.example' })
      assert.equal('inline', result.kind)
    end)

    it('errors when inline lacks url', function()
      assert.has_error(function()
        link.create({ kind = 'inline', text = 'foo' })
      end)
    end)

    it('errors when inline lacks text', function()
      assert.has_error(function()
        link.create({ kind = 'inline', url = 'https://x.example' })
      end)
    end)

    it('errors when reference_full lacks label', function()
      assert.has_error(function()
        link.create({ kind = 'reference_full', text = 'foo' })
      end)
    end)

    it('errors when reference_full lacks text', function()
      assert.has_error(function()
        link.create({ kind = 'reference_full', label = 'L' })
      end)
    end)

    it('errors when autolink lacks url', function()
      assert.has_error(function()
        link.create({ kind = 'autolink' })
      end)
    end)
  end)

  describe('replace', function()
    it('rewrites an inline link in the middle of a paragraph', function()
      with_buffer(
        { 'see [foo](https://old.example) here' },
        { 1, 6 },
        function(ctx)
          local result, node = link.read(ctx)
          result.url = 'https://new.example'
          link.replace(node, { result }, ctx)
          assert.same(
            { 'see [foo](https://new.example) here' },
            vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
          )
        end
      )
    end)

    it('preserves surrounding non-link content', function()
      with_buffer(
        { 'before [a](u) middle [b](v) after' },
        { 1, 8 },
        function(ctx)
          local result, node = link.read(ctx)
          result.text = 'edited'
          link.replace(node, { result }, ctx)
          assert.same(
            { 'before [edited](u) middle [b](v) after' },
            vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
          )
        end
      )
    end)

    it('deletes the link when given an empty list', function()
      with_buffer({ 'a [foo](https://x.example) b' }, { 1, 4 }, function(ctx)
        local _, node = link.read(ctx)
        link.replace(node, {}, ctx)
        assert.same(
          { 'a  b' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('swaps the link kind in place', function()
      with_buffer(
        { 'see [foo](https://x.example) end' },
        { 1, 6 },
        function(ctx)
          local _, node = link.read(ctx)
          local rebuilt =
            link.create({ kind = 'reference_shortcut', text = 'foo' })
          link.replace(node, { rebuilt }, ctx)
          assert.same(
            { 'see [foo] end' },
            vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
          )
        end
      )
    end)

    it('concatenates multiple links with no separator', function()
      with_buffer({ 'pre [a](u) post' }, { 1, 5 }, function(ctx)
        local _, node = link.read(ctx)
        local first = link.create({ kind = 'inline', text = 'a', url = 'u' })
        local second = link.create({ kind = 'inline', text = 'b', url = 'v' })
        link.replace(node, { first, second }, ctx)
        assert.same(
          { 'pre [a](u)[b](v) post' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)
  end)

  describe('definitions', function()
    it('returns an empty table when there are no definitions', function()
      with_buffer({ 'just prose' }, { 1, 0 }, function(ctx)
        assert.same({}, link.definitions(ctx))
      end)
    end)

    it('keys multiple definitions by lowercased label', function()
      with_buffer({
        '[Foo]: https://foo.example',
        '[BAR]: https://bar.example "title"',
      }, { 1, 0 }, function(ctx)
        local defs = link.definitions(ctx)
        assert.equal('https://foo.example', defs.foo.url)
        assert.equal('https://bar.example', defs.bar.url)
        assert.equal('title', defs.bar.title)
      end)
    end)

    it('preserves the original label casing in the value', function()
      with_buffer({ '[Foo]: https://foo.example' }, { 1, 0 }, function(ctx)
        local defs = link.definitions(ctx)
        assert.equal('Foo', defs.foo.label)
      end)
    end)

    it('keys labels by their CommonMark-normalized form', function()
      with_buffer({
        '[A  B]: https://x.example',
      }, { 1, 0 }, function(ctx)
        local defs = link.definitions(ctx)
        assert.equal('https://x.example', defs['a b'].url)
      end)
    end)
  end)

  describe('resolve', function()
    it('resolves a reference link via lowercased label', function()
      with_buffer({
        'see [foo][L] end',
        '',
        '[l]: https://x.example',
      }, { 1, 6 }, function(ctx)
        local result = link.read(ctx)
        local defs = link.definitions(ctx)
        local def = link.resolve(result, defs)
        assert.is_not_nil(def)
        assert.equal('https://x.example', def.url)
      end)
    end)

    it('returns nil when the label is unknown', function()
      with_buffer({ 'see [foo][missing] end' }, { 1, 6 }, function(ctx)
        local result = link.read(ctx)
        local defs = link.definitions(ctx)
        assert.is_nil(link.resolve(result, defs))
      end)
    end)

    it('matches labels with collapsed whitespace and case folding', function()
      with_buffer({
        'see [text][A  B] end',
        '',
        '[a b]: https://x.example',
      }, { 1, 6 }, function(ctx)
        local result = link.read(ctx)
        local defs = link.definitions(ctx)
        local def = link.resolve(result, defs)
        assert.is_not_nil(def)
        assert.equal('https://x.example', def.url)
      end)
    end)

    it('returns nil for inline links', function()
      local result = link.create({ kind = 'inline', text = 'foo', url = 'u' })
      assert.is_nil(link.resolve(result, {}))
    end)

    it('returns nil for autolinks', function()
      local result =
        link.create({ kind = 'autolink', url = 'https://x.example' })
      assert.is_nil(link.resolve(result, {}))
    end)
  end)

  describe('field accessors', function()
    it('get/set url on inline links', function()
      local result = link.create({ kind = 'inline', text = 'a', url = 'u' })
      assert.equal('u', link.get_url(result))
      link.set_url(result, 'v')
      assert.equal('v', link.get_url(result))
    end)

    it('get/set url on autolinks', function()
      local result =
        link.create({ kind = 'autolink', url = 'https://x.example' })
      link.set_url(result, 'https://y.example')
      assert.equal('https://y.example', link.get_url(result))
    end)

    it('errors setting url on reference_full', function()
      local result =
        link.create({ kind = 'reference_full', text = 'a', label = 'L' })
      assert.has_error(function()
        link.set_url(result, 'u')
      end)
    end)

    it('errors setting url on reference_collapsed', function()
      local result = link.create({ kind = 'reference_collapsed', text = 'a' })
      assert.has_error(function()
        link.set_url(result, 'u')
      end)
    end)

    it('get/set text mirrors into label for collapsed links', function()
      local result = link.create({ kind = 'reference_collapsed', text = 'a' })
      link.set_text(result, 'b')
      assert.equal('b', link.get_text(result))
      assert.equal('b', link.get_label(result))
    end)

    it('errors setting text on autolinks', function()
      local result =
        link.create({ kind = 'autolink', url = 'https://x.example' })
      assert.has_error(function()
        link.set_text(result, 'foo')
      end)
    end)

    it('get/set title on inline links', function()
      local result = link.create({ kind = 'inline', text = 'a', url = 'u' })
      link.set_title(result, 'site')
      assert.equal('site', link.get_title(result))
      link.set_title(result, nil)
      assert.is_nil(link.get_title(result))
    end)

    it('errors setting title on reference_full', function()
      local result =
        link.create({ kind = 'reference_full', text = 'a', label = 'L' })
      assert.has_error(function()
        link.set_title(result, 'site')
      end)
    end)

    it('get/set label on reference_full', function()
      local result =
        link.create({ kind = 'reference_full', text = 'a', label = 'L' })
      link.set_label(result, 'M')
      assert.equal('M', link.get_label(result))
    end)

    it('errors setting label on reference_collapsed', function()
      local result = link.create({ kind = 'reference_collapsed', text = 'a' })
      assert.has_error(function()
        link.set_label(result, 'foo')
      end)
    end)

    it('errors setting label on inline', function()
      local result = link.create({ kind = 'inline', text = 'a', url = 'u' })
      assert.has_error(function()
        link.set_label(result, 'foo')
      end)
    end)

    it('get/set kind round-trips', function()
      local result = link.create({ kind = 'inline', text = 'a', url = 'u' })
      assert.equal('inline', link.get_kind(result))
      link.set_kind(result, 'autolink')
      assert.equal('autolink', link.get_kind(result))
    end)
  end)

  describe('special characters', function()
    it('does not escape special characters in render', function()
      assert.equal(
        '[a "b"](u (with parens))',
        link.render({
          kind = 'inline',
          text = 'a "b"',
          url = 'u (with parens)',
        })
      )
    end)
  end)
end)
