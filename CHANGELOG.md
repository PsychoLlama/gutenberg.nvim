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
- Motions: next/previous heading, table, and table cell, plus an
  inner-cell textobject (`table.select_cell`).
- Table structure: insert/delete/move rows and columns, and a
  `table.actions()` picker over them.
- Smart list indent/dedent that renumbers ordered lists on both sides
  of the move; list splice primitives (`items`, `insert`, `append`,
  `prepend`, `renumber`).
- `code_block.insert` / `code_block.wrap` and `link.wrap` /
  `link.remove`.

[Unreleased]: https://github.com/PsychoLlama/gutenberg.nvim/commits/main
