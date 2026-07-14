<div align="center">
  <h1>gutenberg.nvim</h1>
  <p>Tools for editing Markdown</p>
</div>

## Overview

`gutenberg.nvim` is a plugin for rich Markdown editing, built on Treesitter:
reshape tables, toggle checkboxes, promote headings, wrap links and inline
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

- **Tables**
  - Insert / delete / move columns, cell motions, an inner-cell textobject
  - Format to canonical widths, cycle column alignment
- **Lists**
  - Insert items, indent / dedent to nest, renumber ordered runs automatically, cycle ordered / unordered
  - Toggle checkboxes (bulk over a visual selection), navigation to checked / unchecked items
- **Code blocks**
  - Wrap a motion or selection in a code fence
- **Headings**
  - Promote / demote, count- and range-aware
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

Gutenberg ships with **opt-in keymaps**. They are not enabled by default.

```lua
require('gutenberg').setup({
  default_keymaps = { enable = true },
})
```

See `:help gutenberg-recommended-config` for the full keymap list and
`:help gutenberg.config` for every option.

## Interactive Tour

Explore gutenberg's features in a `:vimtutor`-style scratch buffer.

```vim
:lua require('gutenberg').tour()
```

## Installation

Requires the `markdown` / `markdown_inline` Treesitter parsers, both bundled
with Neovim since 0.10.

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

## Related Tools

- [markdown.nvim](https://github.com/tadmccorkle/markdown.nvim): gutenberg is
  heavily inspired by this plugin. I created Gutenberg to build on that
  experience, adding features like table editing and a richer Lua API.
- [prettier](https://prettier.io/) / [prettierd](https://github.com/fsouza/prettierd):
  grew out of the JS community as a general-purpose formatter. It has excellent
  markdown support. I recommend using it with [conform.nvim](https://github.com/stevearc/conform.nvim/).
