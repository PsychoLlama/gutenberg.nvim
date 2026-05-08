# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `gutenberg.table` module for reading, editing, rendering, and replacing
  GFM pipe tables. Includes per-column alignment (`none`, `left`, `center`,
  `right`), cell accessors, and round-trippable rendering.
- `gutenberg.table.Config` with a `default_alignment` setting for new tables
  created via `gutenberg.table.create`.

[Unreleased]: https://github.com/PsychoLlama/gutenberg.nvim/commits/main
