local heading = require('gutenberg.constructs.heading')

local with_buffer = require('gutenberg.tests.utils').with_buffer

describe('gutenberg.heading', function()
  describe('render', function()
    it('renders an h1', function()
      assert.equal('# foo', heading.render({ level = 1, text = 'foo' }))
    end)

    it('renders an h2', function()
      assert.equal('## foo', heading.render({ level = 2, text = 'foo' }))
    end)

    it('renders an h3', function()
      assert.equal('### foo', heading.render({ level = 3, text = 'foo' }))
    end)

    it('renders an h4', function()
      assert.equal('#### foo', heading.render({ level = 4, text = 'foo' }))
    end)

    it('renders an h5', function()
      assert.equal('##### foo', heading.render({ level = 5, text = 'foo' }))
    end)

    it('renders an h6', function()
      assert.equal('###### foo', heading.render({ level = 6, text = 'foo' }))
    end)

    it(
      'omits the trailing space when text is empty for every level',
      function()
        for level = 1, 6 do
          assert.equal(
            string.rep('#', level),
            heading.render({ level = level, text = '' })
          )
        end
      end
    )
  end)

  describe('is_heading', function()
    it('returns true on every level', function()
      for level = 1, 6 do
        local line = string.rep('#', level) .. ' heading'
        with_buffer({ line }, { 1, level + 1 }, function(ctx)
          assert.is_true(heading.is_heading(ctx))
        end)
      end
    end)

    it('returns true in the leading indent of an indented heading', function()
      with_buffer({ '  ## indented' }, { 1, 0 }, function(ctx)
        assert.is_true(heading.is_heading(ctx))
      end)
    end)

    it('returns false on a list item', function()
      with_buffer({ '- foo' }, { 1, 2 }, function(ctx)
        assert.is_false(heading.is_heading(ctx))
      end)
    end)

    it('returns false on a paragraph', function()
      with_buffer({ 'just a paragraph' }, { 1, 2 }, function(ctx)
        assert.is_false(heading.is_heading(ctx))
      end)
    end)

    it('returns false on a blank line', function()
      with_buffer({ '' }, { 1, 0 }, function(ctx)
        assert.is_false(heading.is_heading(ctx))
      end)
    end)

    it('returns false inside a fenced code block', function()
      with_buffer({ '```', '# not a heading', '```' }, { 2, 2 }, function(ctx)
        assert.is_false(heading.is_heading(ctx))
      end)
    end)
  end)

  describe('read', function()
    it('reads each level', function()
      for level = 1, 6 do
        local line = string.rep('#', level) .. ' heading'
        with_buffer({ line }, { 1, level + 1 }, function(ctx)
          local h = heading.read(ctx)
          assert.equal(level, h.level)
          assert.equal('heading', h.text)
        end)
      end
    end)

    it('reads multi-word text', function()
      with_buffer({ '## hello there friends' }, { 1, 5 }, function(ctx)
        local h = heading.read(ctx)
        assert.equal('hello there friends', h.text)
      end)
    end)

    it('reads an empty heading', function()
      with_buffer({ '#' }, { 1, 0 }, function(ctx)
        local h = heading.read(ctx)
        assert.equal(1, h.level)
        assert.equal('', h.text)
      end)
    end)

    it('returns the atx_heading TSNode', function()
      with_buffer({ '# foo' }, { 1, 2 }, function(ctx)
        local _, node = heading.read(ctx)
        assert.equal('atx_heading', node:type())
      end)
    end)

    it('errors when the cursor is not on a heading', function()
      with_buffer({ 'paragraph' }, { 1, 0 }, function(ctx)
        assert.has_error(function()
          heading.read(ctx)
        end)
      end)
    end)
  end)

  describe('create', function()
    it('uses the configured default level', function()
      require('gutenberg.config').merge()
      local h = heading.create({})
      assert.equal(1, h.level)
      assert.equal('', h.text)
    end)

    it('overrides the level', function()
      local h = heading.create({ level = 3 })
      assert.equal(3, h.level)
    end)

    it('overrides the text', function()
      local h = heading.create({ text = 'hi' })
      assert.equal('hi', h.text)
    end)

    it('errors when level is out of range', function()
      assert.has_error(function()
        heading.create({ level = 7 })
      end)
      assert.has_error(function()
        heading.create({ level = 0 })
      end)
    end)
  end)

  describe('replace', function()
    it('rewrites a single heading in place', function()
      with_buffer({ '# foo', '# bar' }, { 1, 2 }, function(ctx)
        local h, node = heading.read(ctx)
        h.text = 'edited'
        heading.replace(node, { h }, ctx)
        assert.same(
          { '# edited', '# bar' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('promotes a heading by adjusting level', function()
      with_buffer({ '# foo' }, { 1, 2 }, function(ctx)
        local h, node = heading.read(ctx)
        heading.set_level(h, 3)
        heading.replace(node, { h }, ctx)
        assert.same(
          { '### foo' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('deletes the heading when headings is empty', function()
      with_buffer({ '# foo', 'paragraph' }, { 1, 2 }, function(ctx)
        local _, node = heading.read(ctx)
        heading.replace(node, {}, ctx)
        assert.same(
          { 'paragraph' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('expands one heading into many', function()
      with_buffer({ '# foo' }, { 1, 2 }, function(ctx)
        local h, node = heading.read(ctx)
        heading.replace(node, {
          h,
          heading.create({ level = 2, text = 'new' }),
        }, ctx)
        assert.same(
          { '# foo', '## new' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('preserves surrounding non-heading content', function()
      with_buffer(
        { 'paragraph', '', '# foo', '', '- list' },
        { 3, 2 },
        function(ctx)
          local h, node = heading.read(ctx)
          h.text = 'edited'
          heading.replace(node, { h }, ctx)
          assert.same({
            'paragraph',
            '',
            '# edited',
            '',
            '- list',
          }, vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false))
        end
      )
    end)

    it('rewrites the last heading in the buffer', function()
      with_buffer({ '# foo', '## bar' }, { 2, 2 }, function(ctx)
        local h, node = heading.read(ctx)
        h.text = 'edited'
        heading.replace(node, { h }, ctx)
        assert.same(
          { '# foo', '## edited' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('preserves a block quote prefix when rewriting in place', function()
      with_buffer({ '> # foo' }, { 1, 4 }, function(ctx)
        local h, node = heading.read(ctx)
        h.text = 'bar'
        heading.replace(node, { h }, ctx)
        assert.same(
          { '> # bar' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('skips the buffer write when nothing changed', function()
      with_buffer({ '# foo' }, { 1, 2 }, function(ctx)
        local h, node = heading.read(ctx)
        local tick = vim.b[ctx.bufnr].changedtick
        heading.set_level(h, 1)
        heading.replace(node, { h }, ctx)
        assert.equal(tick, vim.b[ctx.bufnr].changedtick)
      end)
    end)

    it('preserves a block quote prefix when expanding to many', function()
      with_buffer({ '> # foo' }, { 1, 4 }, function(ctx)
        local h, node = heading.read(ctx)
        heading.replace(node, {
          h,
          heading.create({ level = 2, text = 'extra' }),
        }, ctx)
        assert.same(
          { '> # foo', '> ## extra' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)
  end)

  describe('set_level', function()
    it('errors on level 0', function()
      assert.has_error(function()
        heading.set_level({ level = 1, text = '' }, 0)
      end)
    end)

    it('errors on level 7', function()
      assert.has_error(function()
        heading.set_level({ level = 1, text = '' }, 7)
      end)
    end)

    it('errors on negative levels', function()
      assert.has_error(function()
        heading.set_level({ level = 1, text = '' }, -1)
      end)
    end)

    it('errors on absurdly large levels', function()
      assert.has_error(function()
        heading.set_level({ level = 1, text = '' }, 100)
      end)
    end)

    it('accepts each valid level', function()
      for level = 1, 6 do
        local h = { level = 1, text = '' }
        heading.set_level(h, level)
        assert.equal(level, h.level)
      end
    end)
  end)

  describe('get_level / get_text / set_text', function()
    it('reads and writes fields', function()
      local h = { level = 2, text = 'hi' }
      assert.equal(2, heading.get_level(h))
      assert.equal('hi', heading.get_text(h))
      heading.set_text(h, 'bye')
      assert.equal('bye', heading.get_text(h))
    end)
  end)

  describe('list', function()
    it('returns headings in document order', function()
      with_buffer({
        '# one',
        '',
        'paragraph',
        '',
        '## two',
        '',
        '### three',
        '',
        '## four',
      }, { 1, 0 }, function(ctx)
        local entries = heading.list(ctx)
        assert.equal(4, #entries)
        assert.equal('one', entries[1].heading.text)
        assert.equal(1, entries[1].heading.level)
        assert.equal('two', entries[2].heading.text)
        assert.equal(2, entries[2].heading.level)
        assert.equal('three', entries[3].heading.text)
        assert.equal(3, entries[3].heading.level)
        assert.equal('four', entries[4].heading.text)
        assert.equal(2, entries[4].heading.level)
        assert.equal('atx_heading', entries[1].node:type())
      end)
    end)

    it('returns an empty table when there are no headings', function()
      with_buffer({ 'just a paragraph' }, { 1, 0 }, function(ctx)
        assert.same({}, heading.list(ctx))
      end)
    end)

    it('returns an empty table for an empty buffer', function()
      with_buffer({ '' }, { 1, 0 }, function(ctx)
        assert.same({}, heading.list(ctx))
      end)
    end)
  end)

  describe('find_next', function()
    it('finds the nearest heading after the cursor', function()
      with_buffer(
        { '# one', 'body', '## two', 'more', '### three' },
        { 1, 0 },
        function(ctx)
          local h, node = heading.find_next(ctx)
          assert.equal('two', h.text)
          assert.equal(2, h.level)
          assert.equal('atx_heading', node:type())
        end
      )
    end)

    it('respects min_level', function()
      with_buffer(
        { '# one', '## two', '### three', '# four' },
        { 1, 0 },
        function(ctx)
          local h = heading.find_next(ctx, { min_level = 3 })
          assert.equal('three', h.text)
        end
      )
    end)

    it('respects max_level', function()
      with_buffer(
        { '# one', '## two', '### three', '# four' },
        { 1, 0 },
        function(ctx)
          local h = heading.find_next(ctx, { max_level = 1 })
          assert.equal('four', h.text)
        end
      )
    end)

    it('returns nil when there is no next heading', function()
      with_buffer({ '# only' }, { 1, 0 }, function(ctx)
        local h, node = heading.find_next(ctx)
        assert.is_nil(h)
        assert.is_nil(node)
      end)
    end)
  end)

  describe('find_prev', function()
    it('finds the nearest heading before the cursor', function()
      with_buffer(
        { '# one', '## two', 'body', '### cursor', '## after' },
        { 4, 0 },
        function(ctx)
          local h, node = heading.find_prev(ctx)
          assert.equal('two', h.text)
          assert.equal('atx_heading', node:type())
        end
      )
    end)

    it('respects min_level', function()
      with_buffer(
        { '# one', '## two', '### three', 'body' },
        { 4, 0 },
        function(ctx)
          local h = heading.find_prev(ctx, { min_level = 3 })
          assert.equal('three', h.text)
        end
      )
    end)

    it('respects max_level', function()
      with_buffer(
        { '# one', '## two', '### three', 'body' },
        { 4, 0 },
        function(ctx)
          local h = heading.find_prev(ctx, { max_level = 1 })
          assert.equal('one', h.text)
        end
      )
    end)

    it('returns nil when there is no preceding heading', function()
      with_buffer({ 'body', '# only' }, { 1, 0 }, function(ctx)
        local h, node = heading.find_prev(ctx)
        assert.is_nil(h)
        assert.is_nil(node)
      end)
    end)
  end)

  describe('find_parent', function()
    it(
      'finds the most recent heading governing the cursor section',
      function()
        with_buffer({
          '# one',
          '## two',
          '### three',
          'body',
        }, { 4, 0 }, function(ctx)
          local h = heading.find_parent(ctx)
          assert.equal('three', h.text)
          assert.equal(3, h.level)
        end)
      end
    )

    it('on a heading, returns the parent heading', function()
      with_buffer({
        '# one',
        '## two',
        '### three',
      }, { 3, 0 }, function(ctx)
        local h = heading.find_parent(ctx)
        assert.equal('two', h.text)
        assert.equal(2, h.level)
      end)
    end)

    it('on h2 with siblings, returns the enclosing h1', function()
      with_buffer({
        '# one',
        '## two',
        '### three',
        '## four',
      }, { 4, 0 }, function(ctx)
        local h = heading.find_parent(ctx)
        assert.equal('one', h.text)
        assert.equal(1, h.level)
      end)
    end)

    it('returns nil when there is no preceding heading', function()
      with_buffer({ 'body', '# only' }, { 1, 0 }, function(ctx)
        local h, node = heading.find_parent(ctx)
        assert.is_nil(h)
        assert.is_nil(node)
      end)
    end)

    it('returns nil for the first heading in the buffer', function()
      with_buffer({ '# only', 'body' }, { 1, 0 }, function(ctx)
        local h = heading.find_parent(ctx)
        assert.is_nil(h)
      end)
    end)
  end)

  describe('update', function()
    it('writes the mutated heading back in one update', function()
      with_buffer({ '# title', 'body' }, { 1, 0 }, function(ctx)
        heading.update(function(h)
          h.text = 'edited'
        end, ctx)
        assert.same(
          { '# edited', 'body' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('errors when the cursor is not on a heading', function()
      with_buffer({ 'paragraph' }, { 1, 0 }, function(ctx)
        assert.error_matches(function()
          heading.update(function() end, ctx)
        end, 'cursor is not on a heading')
      end)
    end)
  end)

  describe('promote / demote', function()
    it('promote raises the heading one level', function()
      with_buffer({ '### title' }, { 1, 0 }, function(ctx)
        heading.promote(ctx)
        assert.same(
          { '## title' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('promote leaves a level-1 heading unchanged', function()
      with_buffer({ '# title' }, { 1, 0 }, function(ctx)
        heading.promote(ctx)
        assert.same(
          { '# title' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('demote sinks the heading one level', function()
      with_buffer({ '# title' }, { 1, 0 }, function(ctx)
        heading.demote(ctx)
        assert.same(
          { '## title' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)

    it('demote leaves a level-6 heading unchanged', function()
      with_buffer({ '###### title' }, { 1, 0 }, function(ctx)
        heading.demote(ctx)
        assert.same(
          { '###### title' },
          vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        )
      end)
    end)
  end)
end)
