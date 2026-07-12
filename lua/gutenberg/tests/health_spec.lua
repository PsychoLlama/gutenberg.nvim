local health = require('gutenberg.health')

--- Run `health.check` with `vim.health` reporters stubbed out,
--- returning every report as `{ kind, message }` pairs.
---@return { kind: string, message: string }[]
local function collect_reports()
  ---@type { kind: string, message: string }[]
  local reports = {}
  local original = vim.health
  ---@diagnostic disable-next-line: duplicate-set-field
  vim.health = setmetatable({}, {
    __index = function(_, kind)
      return function(message)
        table.insert(reports, { kind = kind, message = message })
      end
    end,
  })
  local ok, err = pcall(health.check)
  vim.health = original
  if not ok then
    error(err)
  end
  return reports
end

describe('gutenberg.health', function()
  it('reports no errors in a working install', function()
    local reports = collect_reports()
    for _, report in ipairs(reports) do
      assert.is_true(
        report.kind ~= 'error',
        'unexpected health error: ' .. tostring(report.message)
      )
    end
  end)

  it('confirms both grammars and query files', function()
    local reports = collect_reports()
    local messages = vim.tbl_map(function(report)
      return report.message
    end, reports)
    local blob = table.concat(messages, '\n')
    assert.truthy(blob:find('`markdown` parser found', 1, true))
    assert.truthy(blob:find('`markdown_inline` parser found', 1, true))
    assert.truthy(blob:find('queries/markdown/gutenberg.scm', 1, true))
    assert.truthy(blob:find('queries/markdown_inline/gutenberg.scm', 1, true))
  end)

  it('reports an error when a query file is missing', function()
    local original = vim.treesitter.query.get
    ---@diagnostic disable-next-line: duplicate-set-field
    vim.treesitter.query.get = function()
      return nil
    end
    local ok, reports = pcall(collect_reports)
    vim.treesitter.query.get = original
    if not ok then
      error(reports)
    end

    local found = false
    for _, report in ipairs(reports) do
      if
        report.kind == 'error'
        and report.message:find("not found on 'runtimepath'", 1, true)
      then
        found = true
      end
    end
    assert.is_true(found)
  end)
end)
