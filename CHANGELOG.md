# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- New checkboxes now default to unchecked. Set `list.default_checked = true` in `setup` to restore the old behavior.

### Fixed

- `gutenberg.list.insert_item` and `dedent` no longer overshoot into the next
  sibling when the cursor is on a nested list item. Inserting below `second` in
  `- first / - second / - third` landed the new item after `third`, and
  dedenting `second` dragged `third` along with it.

## [0.2.0] - 2026-07-14

### Changed

- The recommended link keymap (`<leader>ml`) now offers file-path completion
  since Markdown links are often relative paths.

### Added

- Checkbox motions. `gutenberg.list.next_checkbox` / `prev_checkbox` move the
  cursor to the next/previous list item, filtered by checkbox state via
  `{ checked = true | false }`, backed by new `gutenberg.api.list.find_next` /
  `find_prev` primitives. The recommended keymaps bind `]c` / `[c` to the
  next/previous unchecked item and `]C` / `[C` to the next/previous checked one.

## [0.1.0] - 2026-07-12

Initial release.

[Unreleased]: https://github.com/PsychoLlama/gutenberg.nvim/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/PsychoLlama/gutenberg.nvim/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/PsychoLlama/gutenberg.nvim/releases/tag/v0.1.0
