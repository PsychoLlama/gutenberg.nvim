describe('gutenberg', function()
  describe('lazy submodule access', function()
    before_each(function()
      -- Force a fresh require so package.loaded reflects a cold start.
      package.loaded['gutenberg'] = nil
      package.loaded['gutenberg.list'] = nil
      package.loaded['gutenberg.heading'] = nil
      package.loaded['gutenberg.table'] = nil
      package.loaded['gutenberg.code_block'] = nil
      package.loaded['gutenberg.link'] = nil
    end)

    it('does not load submodules on the root require', function()
      require('gutenberg')
      assert.is_nil(package.loaded['gutenberg.list'])
      assert.is_nil(package.loaded['gutenberg.heading'])
      assert.is_nil(package.loaded['gutenberg.table'])
      assert.is_nil(package.loaded['gutenberg.code_block'])
      assert.is_nil(package.loaded['gutenberg.link'])
    end)

    it('resolves submodules on first access', function()
      local gutenberg = require('gutenberg')
      assert.equal(require('gutenberg.list'), gutenberg.list)
      assert.equal(require('gutenberg.heading'), gutenberg.heading)
      assert.equal(require('gutenberg.table'), gutenberg.table)
      assert.equal(require('gutenberg.code_block'), gutenberg.code_block)
      assert.equal(require('gutenberg.link'), gutenberg.link)
    end)

    it('caches resolved submodules', function()
      local gutenberg = require('gutenberg')
      local first = gutenberg.list
      local second = gutenberg.list
      assert.equal(first, second)
    end)

    it('returns nil for unknown keys', function()
      local gutenberg = require('gutenberg') ---@type table
      assert.is_nil(gutenberg.does_not_exist)
    end)
  end)
end)
