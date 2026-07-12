# The Gutenberg Tour

This is a scratch buffer: nothing is saved, and the keybindings shown
below are bound to this buffer alone. Edit freely, undo with `u`, and
reopen a fresh copy any time:

    :lua require('gutenberg').tour()

`<leader>` is your leader key — backslash by default. Every binding
here is a thin wrapper over the public API; the last section points at
the reference. If a binding does nothing, run `:checkhealth gutenberg`.

Counts, visual mode, and `.` work everywhere you'd expect — the tour
calls them out as you go.

---

## Headings

`<leader>m<` promotes the heading under the cursor (`##` becomes `#`)
and `<leader>m>` demotes it. Give it a count — `2<leader>m>` sinks two
levels — and repeat it with `.`. Both clamp at levels 1 and 6, and a
boundary call adds no undo entry.

#### A heading to move around

`]h` and `[h` jump to the next and previous heading, counts included:
`3]h` jumps three ahead, and `d]h` deletes to the next one. Neither
changes the document. (For an outline, Neovim's built-in `gO` already
covers markdown.)

Visually select from here up to the first heading and press
`<leader>m>` — every heading in the selection demotes in one undo
step.

---

## Lists

`<leader>mx` toggles the checkbox on a list item; items without one
gain a checkbox first. Try `3<leader>mx` on the first line, then `.`
on the last — and select the whole list with `V` and press
`<leader>mx`: a mixed selection checks everything, a fully-checked one
unchecks:

- [x] oranges
- [ ] apples
- pears

`<leader>mo` switches every sibling at the cursor's level between
bullets and numbers, renumbering from 1 as it goes. In visual mode it
converts just the selection:

- preheat the oven
- whisk the batter
- bake for 25 minutes

`<leader>m>` and `<leader>m<` — the same depth bindings that demote
and promote headings — indent and dedent list items here, and they
earn their keys over plain `>>`/`<<` by renumbering ordered lists on
both sides of the move. Indent "third" and watch "fourth" close the
gap; dedent it back:

1. first
2. second
3. third
4. fourth

Nested children move with their parent, and a dedent that would mangle
the list (an item already flush left) raises an error before touching
the buffer.

---

## Tables

| Keybinding    | What it does                                          |
| ------------- | ----------------------------------------------------- |
| `]t` / `[t`   | Jump to the next / previous table                     |
| `]\|` / `[\|` | Jump to the next / previous cell                      |
| `i\|`         | Inner-cell textobject: try `ci\|` or `vi\|`           |
| `<leader>mf`  | Format the table: pad cells, align pipes              |
| `<leader>ma`  | Cycle the cursor column: none → left → center → right |
| `<leader>mt`  | Structural actions: rows, columns, alignment          |

A ragged table to work with — walk its cells with `]|`, rewrite a cell
with `ci|`, then `<leader>mf` to clean it up. `<leader>mt` opens a
picker for the structural edits: insert a row, move a column, delete
either:

<!-- prettier-ignore -->
| Item | Price | Notes |
| - | - | - |
|apples|1.50|on sale|
| oranges |   2.00 |organic|
|pears  | 1.75|local|

And a second table so `]t` / `[t` have somewhere to go:

| Step | Status |
| ---- | ------ |
| plan | done   |
| ship | soon   |

---

## Links

`<leader>ml` wraps text in a link and prompts for the URL — leave it
empty and fill it in later, `[text]()` is legal markdown. In normal
mode it hangs as an operator (`<leader>mliw` wraps the inner word); in
visual mode it wraps the selection. `<leader>mL` removes the link
under the cursor, leaving its text — and it repeats with `.`:

Wrap this sentence's first word, then unlink
[an editor](https://example.com).

(Editing an existing link needs no binding: the URL and text are plain
delimited text, so `ci(` and `ci[` already handle them.)

---

## Code Blocks

`<leader>mc` inserts an empty fenced code block below the cursor — or
in place of a blank line. In visual mode it fences the selected lines
instead. Select these two lines with `V` and try it:

def greet(name):
return f"hello, {name}"

The fence grows past any backtick runs in the selection, so fencing
text that already contains a fence stays valid.

---

## Beyond the Bindings

Every binding in this buffer is a few lines over the public API,
adapted through `:help gutenberg.keymap` for counts, `.`-repeat, and
visual mode. `:help gutenberg-api` documents the full surface — the
root modules carry these keymap-ready verbs, and
`require('gutenberg.api')` carries the primitives they compose.

The exact keymap set used here lives in
`:help gutenberg-recommended-config`, scoped to markdown and MDX
buffers and ready to copy into your config. gutenberg ships no default
keymaps, so nothing will conflict.
