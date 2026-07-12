# The Gutenberg Tour

This is a scratch buffer: nothing is saved, and the keybindings shown
below are bound to this buffer alone. Edit freely, undo with `u`, and
reopen a fresh copy any time:

    :lua require('gutenberg').tour()

`<leader>` is your leader key — backslash by default. Every binding
here is a thin wrapper over the public API; the last section points at
the reference. If a binding does nothing, run `:checkhealth gutenberg`.

---

## Headings

`<leader>m<` promotes the heading under the cursor (`##` becomes `#`)
and `<leader>m>` demotes it. Both clamp at levels 1 and 6 — a boundary
call changes nothing and adds no undo entry.

#### A heading to move around

`]h` and `[h` jump to the next and previous heading. Neither changes
the document. (For an outline, Neovim's built-in `gO` already covers
markdown.)

---

## Lists

`<leader>mx` toggles the checkbox on a list item; items without one
gain a checkbox first:

- [x] oranges
- [ ] apples
- pears

`<leader>mo` switches every sibling at the cursor's level between
bullets and numbers, renumbering from 1 as it goes:

- preheat the oven
- whisk the batter
- bake for 25 minutes

`<leader>m>` and `<leader>m<` — the same depth bindings that demote and
promote headings — indent and dedent list items here. Nested children
move with their parent, and a dedent that would mangle the list (an
item already flush left) raises an error before touching the buffer:

- coffee
- espresso
- pour over
- tea

Try nesting "espresso" and "pour over" under "coffee", then dedenting
"tea" to see the error.

---

## Tables

| Keybinding   | What it does                                          |
| ------------ | ----------------------------------------------------- |
| `<leader>mf` | Format the table: pad cells, align pipes              |
| `<leader>ma` | Cycle the cursor column: none → left → center → right |

A ragged table to work with — `<leader>ma` rewrites the delimiter row
and realigns the cells in one edit:

<!-- prettier-ignore -->
| Item | Price | Notes |
| - | - | - |
|apples|1.50|on sale|
| oranges |   2.00 |organic|
|pears  | 1.75|local|

---

## Links

`<leader>me` edits the URL of the link under the cursor. `<leader>mE`
edits the link text:

[an editor](https://example.com)

---

## Beyond the Bindings

Every binding in this buffer is a few lines over the public API,
composed from probes, readers, setters, and a single buffer write.
`:help gutenberg-api` documents the full surface.

The exact keymap set used here lives in
`:help gutenberg-recommended-config`, scoped to markdown and MDX
buffers and ready to copy into your config. gutenberg ships no default
keymaps, so nothing will conflict.
