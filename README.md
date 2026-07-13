<div align="center">
  <h1>gutenberg.nvim</h1>
  <p>Tools for editing Markdown</p>
</div>

## Overview

`gutenberg.nvim` is a plugin for rich Markdown editing, built on Treesitter:
promote headings, reshape tables, toggle checkboxes, wrap links and inline
spans, and more. Every action you can trigger from a keybinding is also exposed
as a composable, fully-typed API, so you can rebind anything or script edits
directly.

The API has two tiers:

- **`require('gutenberg.api')`** provides the low-level primitives: probes,
  readers, renderers, accessors, navigation. Nothing here prompts, notifies, or
  moves the cursor.
- **`require('gutenberg')`** provides cursor-level verbs designed to be bound:
  count- and visual-range-aware edits, motions, and pickers, with error messages
  ready for `vim.notify`.

```lua
-- The primitives…
local list = require('gutenberg.api').list

if list.is_list_item() then
  local item, node = list.read()
  list.set_checked(item, not list.is_checked(item))
  list.replace(node, { item })
end

-- …or the verbs built on top of them.
require('gutenberg').list.toggle_checkbox()
```

## Features

- **Lists**
  - Insert items, indent / dedent to nest, renumber ordered runs automatically
  - Toggle checkboxes (bulk over a visual selection), switch ordered ↔ unordered
- **Headings**
  - Promote / demote, count- and range-aware
  - Jump to the next, previous, or parent heading
- **Tables** (GFM)
  - Format to canonical widths, cycle column alignment
  - Insert / delete / move rows and columns, cell motions, an inner-cell textobject
- **Code blocks**
  - Wrap lines in a fence, insert an empty block, edit the info string and content
- **Links**
  - Wrap a motion or selection in a link, unwrap a link but keep its text
  - Inline, reference (full / collapsed / shortcut), and autolink kinds
- **Inline spans**
  - Wrap / unwrap emphasis, strong, strikethrough, and code spans
  - Configurable `_` / `*` and `**` / `__` delimiters

Every verb accepts an optional `{ bufnr, cursor, count, range }` context, so
nothing assumes the current buffer, and `require('gutenberg.keymap')` turns a
verb into a complete mapping (counts, `.`-repeat, operators, live visual
selections) in a line per mode. Submodules load lazily; you pay nothing for
features you don't touch.

## Configuration

`setup` is optional; gutenberg works out of the box. Opt into the recommended
keymaps and you're editing:

```lua
require('gutenberg').setup({
  default_keymaps = { enable = true },
})
```

Prefer to learn by doing? Take the interactive tour, a scratch buffer with every
keybinding pre-wired and nothing to configure:

```vim
:lua require('gutenberg').tour()
```

See `:help gutenberg-recommended-config` for the full keymap list and
`:help gutenberg.config` for every option.

## Installation

Requires Neovim ≥ 0.10 and the `markdown` / `markdown_inline` Treesitter
parsers, both bundled with Neovim since 0.10.

<details>
<summary><b>lazy.nvim</b></summary>

```lua
{
  'PsychoLlama/gutenberg.nvim',
  ft = { 'markdown', 'markdown.mdx', 'mdx' },
  opts = {
    default_keymaps = { enable = true },
  },
}
```

</details>

<details>
<summary><b>packer.nvim</b></summary>

```lua
use({
  'PsychoLlama/gutenberg.nvim',
  config = function()
    require('gutenberg').setup({
      default_keymaps = { enable = true },
    })
  end,
})
```

</details>

<details>
<summary><b>home-manager (flake)</b></summary>

Add the flake as an input:

```nix
{
  inputs.gutenberg-nvim.url = "github:PsychoLlama/gutenberg.nvim";
}
```

Then install the plugin and call `setup` from your Neovim config:

```nix
{ inputs, pkgs, ... }:
{
  programs.neovim = {
    plugins = [ inputs.gutenberg-nvim.packages.${pkgs.system}.default ];
    extraLuaConfig = ''
      require('gutenberg').setup({
        default_keymaps = { enable = true },
      })
    '';
  };
}
```

</details>

## Documentation

Full reference in `:help gutenberg`, or read
[the docs online](https://github.com/PsychoLlama/gutenberg.nvim/blob/main/doc/gutenberg.txt).
