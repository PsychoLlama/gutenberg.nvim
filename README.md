<div align="center">
  <h1>gutenberg.nvim</h1>
  <p>Tools for editing Markdown</p>
</div>

## Overview

`gutenberg.nvim` is a library of composable APIs for editing Markdown,
built on Treesitter. It ships no keymaps and no commands — it provides
the primitives to build your own.

Everything it exposes is one of three kinds:

- **Interpretation** — ask what the cursor is on and decode it into a
  plain Lua value: `list.is_list_item()`, `list.read()`, and friends.
- **Navigation** — locate constructs without moving anything:
  `heading.find_next()`, `heading.list()`.
- **Codemods** — transform values in memory and write them back in a
  single buffer update: setters, `replace()`, and sugar like
  `list.toggle_checkbox()` or `table.format()`.

```lua
local list = require('gutenberg').list

-- The primitives…
if list.is_list_item() then
  local item, node = list.read()
  list.set_checked(item, not list.is_checked(item))
  list.replace(node, { item })
end

-- …or the sugar built on top of them.
list.toggle_checkbox()
```

Every API accepts an optional `{ bufnr, cursor }` context, so nothing
assumes the current buffer. Submodules load lazily;
`require('gutenberg')` costs nothing for features you don't touch.

## Getting Started

Take the interactive tutor for a spin — it opens a scratch buffer with
keybindings pre-wired so you can try every feature without configuring
anything:

```viml
:lua require('gutenberg').tutor()
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
