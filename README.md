<div align="center">
  <h1>gutenberg.nvim</h1>
  <p>Tools for editing Markdown</p>
</div>

## Overview

`gutenberg.nvim` is a library of composable APIs for editing Markdown,
built on Treesitter. It ships no keymaps and no commands — it provides the
primitives to build your own:

- **Ask** what the cursor is on: `list.is_list_item()`, `heading.is_heading()`,
  `table.is_table()`, `code_block.is_code_block()`, `link.is_link()`.
- **Read** the construct into a plain Lua value: `read()`.
- **Transform** the value in memory with explicit getters and setters —
  check a checkbox, renumber a list, realign a column, retitle a heading.
- **Write** it back in a single buffer update: `replace()`.

Every API accepts an optional `{ bufnr, cursor }` context, so nothing
assumes the current buffer. Submodules load lazily;
`require('gutenberg')` costs nothing for features you don't touch.

```lua
local list = require('gutenberg.list')

if list.is_list_item() then
  local item, node = list.read()
  list.set_checked(item, not list.is_checked(item))
  list.replace(node, { item })
end
```

## [Documentation](https://github.com/PsychoLlama/gutenberg.nvim/blob/main/doc/gutenberg.txt)

```viml
:help gutenberg
```
