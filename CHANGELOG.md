# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- `gutenberg.list.is_list_item` / `read` / `dedent` now recognize the
  cursor as being on a list item when it sits anywhere in the item's
  leading indent, not just on the marker or its content.
- The same leading-indent rule now applies to every block construct:
  `heading.is_heading` / `read`, `table.is_table` / `read`,
  `code_block.is_code_block` / `read`, and `link.is_definition` /
  `read_definition` resolve their construct with the cursor anywhere on
  its first row, including indentation before it.
- `replace` (every module) and `list.indent` / `list.dedent` skip the
  buffer write when the rendered output equals the existing range, so
  no-op edits (e.g. promoting an h1 to h1) no longer add an undo entry.

### Changed

- Construct modules moved under `lua/gutenberg/constructs/`:
  `require('gutenberg.list')` is now
  `require('gutenberg.constructs.list')` (same for `heading`, `table`,
  `code_block`, and `link`). The recommended access path is unchanged
  and now canonical: `require('gutenberg').list`.
- Error messages are prefixed with `gutenberg:` and thrown without
  file/line position info (`error(msg, 0)`), so keymaps can `pcall` an
  operation and pass the message straight to `vim.notify`. See
  `:h gutenberg-errors` for the error contract and `:h gutenberg-recipes`
  for the intended keymap patterns.
- Construct recognition is now driven by runtime treesitter query files
  (`queries/markdown/gutenberg.scm` and
  `queries/markdown_inline/gutenberg.scm`) instead of hardcoded node-type
  lists. Extend them from your own runtimepath with an `;; extends` query
  to make the `is_*` probes recognize additional node types; inline link
  patterns must `#set! kind` to one of the built-in
  `gutenberg.link.Kind`s. See `:h gutenberg-queries`.
- `gutenberg.list.Config.indent` is now optional. When unset (the
  default), `list.indent` / `list.dedent` derive the indent unit from
  the target buffer's `&expandtab` and `&tabstop` so a single keymap
  honors per-buffer indentation. Explicitly setting `list.indent`
  still overrides.

### Added

- A sugar tier built on the public primitives. Every construct module
  gains `update(fn, ctx?)`, composing the gate → read → mutate →
  replace loop into one call: it reads the construct at the cursor,
  applies `fn` (mutate in place, or return a replacement list — `{}`
  deletes), and writes back in a single buffer update.
- Targeted sugar verbs: `list.update_list`, `list.toggle_checkbox`,
  `list.toggle_ordered`, `list.toggle_ordered_list` (renumbers
  siblings), `heading.promote` / `heading.demote` (clamped at levels
  1/6), `table.format`, and `table.cycle_alignment`.
- `table.column_at` resolves the cursor to a 1-based column index —
  the interpretation primitive behind `cycle_alignment`.
- `require('gutenberg').<submodule>` lazily resolves to
  `require('gutenberg.<submodule>')` on first access, so plugins can
  treat the root as a namespace without paying any startup-time
  require cost for submodules they don't touch.
- `gutenberg.list.is_ordered` / `gutenberg.list.set_ordered` switch a
  list item between ordered (`1.`) and unordered (config marker)
  without cycling through every bullet variant.
- `gutenberg.list.Config.default_checked` (default `true`) carries the
  preferred state for a newly-inserted checkbox. Toggle-style keymaps
  can read it when promoting a bare item to a checkbox.
- `gutenberg.list.read_list` / `gutenberg.list.replace_list` expose the
  parent `list` and its direct sibling items, with single-buffer-update
  marker rewrites that preserve nested children. Compose with
  `set_marker` to switch ordered ↔ unordered (or renumber) at a level.
- `gutenberg.list.indent` / `gutenberg.list.dedent` shift a list item's
  subtree by `gutenberg.list.Config.indent` (default `'  '`). Nested
  children move with the parent; `dedent` errors when a non-blank line
  lacks the required leading whitespace.
- `gutenberg.list.Config.indent` controls the whitespace unit used by
  `indent` / `dedent`.
- `gutenberg.heading` module for reading and editing ATX markdown headings,
  with landmark navigation primitives (`list`, `find_next`, `find_prev`,
  `find_parent`) and a `gutenberg.heading.Config` carrying the default level
  for `create`.
- `gutenberg.table` module for reading, editing, rendering, and replacing
  GFM pipe tables. Includes per-column alignment (`none`, `left`, `center`,
  `right`), cell accessors, and round-trippable rendering.
- `gutenberg.table.Config` with a `default_alignment` setting for new tables
  created via `gutenberg.table.create`.
- `gutenberg.code_block` module for parsing, building, and rewriting fenced
  markdown code blocks (backtick and tilde fences). Mirrors the
  `gutenberg.list` API: `is_code_block`, `read`, `create`, `render`,
  `replace`, plus `get_info_string` / `set_info_string`, `get_content` /
  `set_content`, and `get_language` / `set_language` accessors. Configurable
  defaults via `gutenberg.code_block.Config` (`fence`, `fence_length`).
- `gutenberg.link` module for parsing and editing markdown links — inline,
  reference (full / collapsed / shortcut), and URI autolinks — plus
  link reference definitions exposed via `definitions` and `resolve`.
- `gutenberg.link.Config.default_kind` to control the kind `link.create`
  produces when one is not supplied.

[Unreleased]: https://github.com/PsychoLlama/gutenberg.nvim/commits/main
