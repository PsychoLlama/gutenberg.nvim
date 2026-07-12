# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

Initial release.

### Added

- Two-tier API: keymap-ready sugar on `require('gutenberg')`,
  low-level primitives on `require('gutenberg.api')`.
- Count and visual-range support across the editing verbs (visual
  bulk checkbox toggles, multi-heading shifts) — every bulk edit is a
  single buffer update and one undo entry.
- `gutenberg.keymap` adapters for dot-repeat, counts, operators, and
  live visual selections.
- `gutenberg.tour()`: an interactive walkthrough in a scratch buffer
  with the recommended keymaps bound to it alone; undo bottoms out at
  the pristine document.
- Motions: next/previous heading, table, and table cell, plus an
  inner-cell textobject (`table.select_cell`).
- Table structure: insert/delete/move rows and columns, a
  `table.actions()` picker over them, and cursor-following
  `table.move_column_left` / `table.move_column_right` verbs so the
  depth keymaps can drag a column across the table.
- Smart list indent/dedent that nests by document structure — the
  shift always reaches the previous sibling's content column, so `3.`
  nests under `2.` even with a narrow 'tabstop' — and renumbers
  ordered lists on both sides of the move; list splice primitives
  (`items`, `insert`, `append`, `prepend`, `renumber`).
- `list.insert_item` and `table.insert_row`: append or prepend a blank
  sibling next to the cursor — a list item (cloning the marker and any
  checkbox, renumbering ordered runs) or a table row — landing the
  cursor on it for immediate text entry.
- `code_block.insert` / `code_block.wrap` and `link.wrap` /
  `link.remove`.
- Recommended keymaps: `<leader>mo` / `<leader>mO` append/prepend a
  list item or table row and drop into insert mode; `<leader>ma` now
  dispatches between toggling a list ordered and cycling a table
  column's alignment. Table and cell motions moved to `]E` / `[E` and
  `]e` / `[e` (off `]t` / `[t` and `]|` / `[|`), and heading navigation
  is left to Neovim's builtin `]]` / `[[` and `gO`.

[Unreleased]: https://github.com/PsychoLlama/gutenberg.nvim/commits/main
