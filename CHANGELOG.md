# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `gutenberg.code_block` module for parsing, building, and rewriting fenced
  markdown code blocks (backtick and tilde fences). Mirrors the
  `gutenberg.list` API: `is_code_block`, `read`, `create`, `render`,
  `replace`, plus `get_info_string` / `set_info_string`, `get_content` /
  `set_content`, and `get_language` / `set_language` accessors. Configurable
  defaults via `gutenberg.code_block.Config` (`fence`, `fence_length`).

[Unreleased]: https://github.com/PsychoLlama/gutenberg.nvim/commits/main
