--- Support for `:checkhealth gutenberg`. Verifies what the plugin
--- depends on at runtime: a supported Neovim, the markdown treesitter
--- grammars, and the query files that drive construct recognition.

---@class gutenberg.health
local M = {}

--- Captures each query file must define. Losing one silently disables
--- the corresponding construct module, so surface it here.
---@type table<string, string[]>
local REQUIRED_CAPTURES = {
  markdown = {
    'heading',
    'code_block',
    'list_item',
    'table',
    'link_definition',
  },
  markdown_inline = { 'link' },
}

--- Whether the treesitter parser for `lang` can be loaded.
--- `vim.treesitter.language.add` returns nil for a missing parser on
--- newer Neovim and throws on older versions; normalize both.
---@param lang string
---@return boolean
local function has_parser(lang)
  local ok, result = pcall(vim.treesitter.language.add, lang)
  return ok and result == true
end

---@param lang string
local function check_lang(lang)
  if not has_parser(lang) then
    vim.health.error(
      ('the `%s` treesitter parser is not installed'):format(lang),
      {
        'Neovim 0.10+ bundles this parser; your build may have stripped runtime files.',
        ('With nvim-treesitter, install it via `:TSInstall %s`.'):format(
          lang
        ),
      }
    )
    return
  end

  local parsers =
    vim.api.nvim_get_runtime_file(('parser/%s.*'):format(lang), true)
  vim.health.ok(
    ('`%s` parser found: %s'):format(lang, parsers[1] or 'built-in')
  )

  -- query.get both finds the file and compiles it against the
  -- installed grammar, so one call distinguishes "not installed"
  -- from "grammar too old/new for the query".
  local ok, query = pcall(vim.treesitter.query.get, lang, 'gutenberg')
  if not ok then
    vim.health.error(
      ('queries/%s/gutenberg.scm does not compile against the installed `%s` grammar'):format(
        lang,
        lang
      ),
      {
        'The parser version does not match what the query expects; update the parser or Neovim.',
        tostring(query),
      }
    )
    return
  end
  if query == nil then
    vim.health.error(
      ("queries/%s/gutenberg.scm not found on 'runtimepath'"):format(lang),
      {
        'The plugin looks partially installed.',
        'Reinstall gutenberg.nvim and check that your plugin manager ships its queries/ directory.',
      }
    )
    return
  end

  ---@type string[]
  local missing = {}
  for _, capture in ipairs(REQUIRED_CAPTURES[lang]) do
    if not vim.tbl_contains(query.captures, capture) then
      table.insert(missing, '@' .. capture)
    end
  end
  if #missing > 0 then
    vim.health.error(
      ('the `%s` gutenberg query is missing captures: %s'):format(
        lang,
        table.concat(missing, ', ')
      ),
      {
        "A query on your 'runtimepath' probably replaced the plugin's instead of extending it.",
        'Start user queries with `;; extends` — see :h gutenberg-queries.',
      }
    )
  else
    vim.health.ok(
      ('queries/%s/gutenberg.scm compiles and defines every required capture'):format(
        lang
      )
    )
  end
end

--- Entry point for `:checkhealth gutenberg`.
function M.check()
  vim.health.start('gutenberg.nvim')

  if vim.fn.has('nvim-0.10') == 1 then
    vim.health.ok(('Neovim %s'):format(tostring(vim.version())))
  else
    vim.health.error('gutenberg requires Neovim 0.10 or newer')
  end

  check_lang('markdown')
  check_lang('markdown_inline')
end

return M
