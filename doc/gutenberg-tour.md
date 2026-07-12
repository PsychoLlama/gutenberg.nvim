# The Gutenberg Tour

This is a scratch buffer: nothing is saved, and the keybindings shown
below are bound to this buffer alone. Edit freely — undo bottoms out
at this pristine copy — and reopen a fresh one any time:

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

Neovim's builtin markdown support already navigates headings, so
gutenberg leaves that alone: `]]` and `[[` jump to the next and
previous section, and `gO` opens an outline of the whole document.

Visually select from here up to the first heading and press
`<leader>m>` — every heading in the selection demotes in one undo
step.

---

## Lists

`<leader>mx` toggles the checkbox on a list item; items without one
gain a checkbox first. Toggle "oranges", then `.` on "pears" — and
select the whole list with `V` and press `<leader>mx`: a mixed
selection checks everything, a fully-checked one unchecks. `<leader>mX`
strips the checkbox off entirely, back to a plain bullet — over a
visual selection too:

- [x] oranges
- [ ] apples
- pears

`<leader>ma` switches every sibling at the cursor's level between
bullets and numbers, renumbering from 1 as it goes. Select a range in
visual mode to convert just those items:

- preheat the oven
- whisk the batter
- bake for 25 minutes

`<leader>mo` appends a fresh sibling below the cursor item and drops
you into insert mode; `<leader>mO` prepends one above. Ordered lists
renumber around the new item, and a checkbox item hands the new one a
blank box. Add a step to the recipe above.

`<leader>m>` and `<leader>m<` — the same depth bindings that demote
and promote headings — indent and dedent list items here, renumbering
ordered lists on both sides of the move. Indent "third" and watch
"fourth" close the gap; dedent it back:

1. first
2. second
3. third
4. fourth

Nested children move with their parent, and the pair stays reversible:
each raises an error before touching the buffer when the move is
undefined — indenting an item with no sibling above it to nest under,
or dedenting one already flush left — so a run of indents undoes with
the same run of dedents.

---

## Tables

| Keybinding                  | What it does                                          |
| --------------------------- | ----------------------------------------------------- |
| `]E` / `[E`                 | Jump to the next / previous table                     |
| `]e` / `[e`                 | Jump to the next / previous cell                      |
| `i\|`                       | Inner-cell textobject: try `ci\|` or `vi\|`           |
| `<leader>m<` / `<leader>m>` | Drag the cursor's column left / right                 |
| `<leader>mo` / `<leader>mO` | Add a row below / above, then insert                  |
| `<leader>mf`                | Format the table: pad cells, align pipes              |
| `<leader>ma`                | Cycle the cursor column: none → left → center → right |
| `<leader>mt`                | Column picker: insert left / right, delete            |

A ragged table to work with — walk its cells with `]e`, rewrite a cell
with `ci|`, then `<leader>mf` to clean it up. The depth bindings work
here too: `<leader>m>` drags the cursor's column right and `<leader>m<`
drags it back, cursor riding along so repeated presses keep dragging.
Add a row with `<leader>mo`, delete one with `dd`; to insert or delete
a column, `<leader>mt` opens a picker:

<!-- prettier-ignore -->
| Item | Price | Notes |
| - | - | - |
|apples|1.50|on sale|
| oranges |   2.00 |organic|
|pears  | 1.75|local|

And a second table so `]E` / `[E` have somewhere to go:

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

---

## Code Blocks

`<leader>mc` inserts an empty fenced code block below the cursor — or
in place of a blank line. In visual mode it fences the selected lines
instead. Select these two lines with `V` and try it:

echo "hello, $USER"
uname -a

The fence grows past any backtick runs in the selection, so fencing
text that already contains a fence stays valid.

---

## Beyond the Bindings

Every binding in this buffer is a few lines over the public API,
adapted through `:help gutenberg.keymap` for counts, `.`-repeat, and
visual mode. `:help gutenberg-api` documents the full surface — the
root modules carry these keymap-ready verbs, and
`require('gutenberg.api')` carries the primitives they compose.

gutenberg builds on what Neovim's markdown support already gives you,
rather than duplicating it. Worth knowing before you map anything:
`]]` / `[[` jump between sections, `gO` opens a document outline, and
`ci(` / `ci[` edit a link's URL and text as plain delimited fields.

The exact keymap set used here lives in
`:help gutenberg-recommended-config`, scoped to markdown and MDX
buffers and ready to copy into your config. gutenberg ships no default
keymaps, so nothing will conflict.
