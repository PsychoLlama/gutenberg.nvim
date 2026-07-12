<div align="center">
  <h1>gutenberg.nvim</h1>
  <p>Tools for editing Markdown</p>
</div>

## Overview

`gutenberg.nvim` is a library of composable APIs for editing Markdown,
built on Treesitter. It ships no keymaps and no commands — it provides
the primitives to build your own.

The API has two tiers:

- **`require('gutenberg.api')`** holds the low-level primitives —
  probes, readers, renderers, accessors, navigation. Nothing here
  prompts, notifies, or moves the cursor.
- **`require('gutenberg')`** holds cursor-level sugar designed to be
  bound: count- and visual-range-aware edits, motions, and pickers,
  with error messages ready for `vim.notify`.

```lua
-- The primitives…
local list = require('gutenberg.api').list

if list.is_list_item() then
  local item, node = list.read()
  list.set_checked(item, not list.is_checked(item))
  list.replace(node, { item })
end

-- …or the sugar built on top of them.
require('gutenberg').list.toggle_checkbox()
```

The `gutenberg.keymap` adapters turn those verbs into complete
mappings — counts, `.`-repeat, operators, and live visual selections —
in a line per mode. Every API accepts an optional
`{ bufnr, cursor, count, range }` context, so nothing assumes the
current buffer. Submodules load lazily; `require('gutenberg')` costs
nothing for features you don't touch.

## Getting Started

Take the interactive tour — it opens a scratch buffer with keybindings
pre-wired so you can try every feature without configuring anything:

```viml
:lua require('gutenberg').tour()
```

Then copy the recommended keymaps into your config and adjust to taste:

```viml
:help gutenberg-recommended-config
```

If something misbehaves, ask the doctor:

```viml
:checkhealth gutenberg
```

## [Documentation](https://github.com/PsychoLlama/gutenberg.nvim/blob/main/doc/gutenberg.txt)

```viml
:help gutenberg
```
