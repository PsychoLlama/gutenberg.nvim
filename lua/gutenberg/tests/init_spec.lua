describe('gutenberg', function()
  describe('lazy submodule access', function()
    before_each(function()
      -- Force a fresh require so package.loaded reflects a cold start.
      package.loaded['gutenberg'] = nil
      package.loaded['gutenberg.constructs.list'] = nil
      package.loaded['gutenberg.constructs.heading'] = nil
      package.loaded['gutenberg.constructs.table'] = nil
      package.loaded['gutenberg.constructs.code_block'] = nil
      package.loaded['gutenberg.constructs.link'] = nil
    end)

    it('does not load submodules on the root require', function()
      require('gutenberg')
      assert.is_nil(package.loaded['gutenberg.constructs.list'])
      assert.is_nil(package.loaded['gutenberg.constructs.heading'])
      assert.is_nil(package.loaded['gutenberg.constructs.table'])
      assert.is_nil(package.loaded['gutenberg.constructs.code_block'])
      assert.is_nil(package.loaded['gutenberg.constructs.link'])
    end)

    it('resolves submodules on first access', function()
      local gutenberg = require('gutenberg')
      assert.equal(require('gutenberg.constructs.list'), gutenberg.list)
      assert.equal(require('gutenberg.constructs.heading'), gutenberg.heading)
      assert.equal(require('gutenberg.constructs.table'), gutenberg.table)
      assert.equal(
        require('gutenberg.constructs.code_block'),
        gutenberg.code_block
      )
      assert.equal(require('gutenberg.constructs.link'), gutenberg.link)
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

    it('propagates submodule load errors instead of masking them', function()
      package.preload['gutenberg.constructs.broken'] = function()
        error('gutenberg: broken submodule', 0)
      end
      local gutenberg = require('gutenberg') ---@type table

      local ok, err = pcall(function()
        return gutenberg.broken
      end)
      package.preload['gutenberg.constructs.broken'] = nil
      package.loaded['gutenberg.constructs.broken'] = nil

      assert.is_false(ok)
      assert.matches('broken submodule', tostring(err))
    end)

    it(
      'propagates api submodule load errors instead of masking them',
      function()
        package.preload['gutenberg.api.broken'] = function()
          error('gutenberg: broken api submodule', 0)
        end
        local api = require('gutenberg.api') ---@type table

        local ok, err = pcall(function()
          return api.broken
        end)
        package.preload['gutenberg.api.broken'] = nil
        package.loaded['gutenberg.api.broken'] = nil

        assert.is_false(ok)
        assert.matches('broken api submodule', tostring(err))
      end
    )

    it('resolves the low-level api namespace', function()
      local gutenberg = require('gutenberg')
      assert.equal(require('gutenberg.api'), gutenberg.api)
      assert.equal(require('gutenberg.api.list'), gutenberg.api.list)
      assert.equal(require('gutenberg.api.heading'), gutenberg.api.heading)
    end)
  end)
end)
