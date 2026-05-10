# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `gutenberg.list.read_list` / `gutenberg.list.replace_list` expose the
  parent `list` and its direct sibling items, with single-buffer-update
  marker rewrites that preserve nested children. Compose with
  `set_marker` to switch ordered ↔ unordered (or renumber) at a level.
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
