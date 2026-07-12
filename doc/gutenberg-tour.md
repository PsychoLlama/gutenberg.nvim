# The Gutenberg Tour

Welcome! This is a hands-on tour of `gutenberg.nvim`. You are reading
a scratch copy of the tour — edit anything, break everything; nothing
is saved. Undo mistakes with `u`, leave with `:q`, and reopen a fresh
copy any time with:

    :lua require('gutenberg').tour()

The keybindings below are defined for this buffer only. `<leader>`
means your leader key — backslash unless you've configured one. The
final lesson shows how to take these bindings home.

If a lesson does nothing at all, run `:checkhealth gutenberg`.

---

## Lesson 1: Promote and Demote Headings

`<leader>m<` promotes the heading under the cursor (`##` becomes `#`)
and `<leader>m>` demotes it (`#` becomes `##`). Both stop at the
boundaries, levels 1 and 6.

**Practice:** put your cursor on the heading below, demote it to
level 6, then bring it back up to level 2.

#### Move me around

---

## Lesson 2: Heading Navigation

Two motions, neither of which changes the document:

| Keybinding | What it does             |
| ---------- | ------------------------ |
| `]h`       | Jump to next heading     |
| `[h`       | Jump to previous heading |

**Practice:** press `]h` and `[h` a few times to hop between lessons.

---

## Lesson 3: Checkboxes

`<leader>mx` toggles the checkbox on a list item. Items without a
checkbox gain one first.

**Practice:** check off the chores below, then uncheck "water plants"
— you overdid it. Give "walk dog" a checkbox while you're at it.

- [ ] water plants
- [ ] buy milk
- walk dog

---

## Lesson 4: Indent and Dedent

`<leader>m>` indents a list item one level and `<leader>m<` dedents
it. Nested children ride along with their parent. Dedenting an item
that is already flush left raises an error instead of mangling the
list.

**Practice:** nest "espresso" and "pour over" under "coffee". Then try
`<leader>m<` on "tea" and watch the error appear — the list is left
untouched.

- coffee
- espresso
- pour over
- tea

---

## Lesson 5: Ordered Lists

`<leader>mo` switches every sibling at the cursor's level between
bullets and numbers, renumbering from 1 as it goes.

**Practice:** number the steps below (they're instructions, after
all), then flip them back to bullets.

- preheat the oven
- whisk the batter
- bake for 25 minutes

---

## Lesson 6: Tables

| Keybinding   | What it does                                          |
| ------------ | ----------------------------------------------------- |
| `<leader>mf` | Format the table: pad cells, align pipes              |
| `<leader>ma` | Cycle the cursor column: none → left → center → right |

**Practice:** format the ragged table below with `<leader>mf`. Then
move into the `Price` column and press `<leader>ma` three times to
right-align it — watch the delimiter row change.

<!-- prettier-ignore -->
| Item | Price | Notes |
| - | - | - |
|apples|1.50|on sale|
| oranges |   2.00 |organic|
|pears  | 1.75|local|

---

## Lesson 7: Code Blocks

`<leader>me` prompts for the fenced code block's language and rewrites
the opening fence in place.

**Practice:** put your cursor inside the block below, press
`<leader>me`, and tag it as `python`.

```
def greet(name):
    return f"hello, {name}"
```

---

## Lesson 8: Links

`<leader>me` edits the URL of the link under the cursor; `<leader>mE`
edits its text.

**Practice:** point [this editor](https://example.com) at
`https://neovim.io`, then rename the link text to `Neovim`.

---

## Lesson 9: Graduation

Every binding you just used is a thin wrapper over the public API — a
few lines each, composed from probes, readers, setters, and a single
buffer write. See `:help gutenberg-api` for the full surface.

To take these keybindings home, copy the recommended config into your
`init.lua`:

    :help gutenberg-recommended-config

It scopes the maps to markdown and MDX buffers and surfaces errors
through `vim.notify`. Adjust freely — gutenberg ships no default
keymaps, so nothing will fight you.

Happy writing.
