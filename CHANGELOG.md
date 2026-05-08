# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `gutenberg.link` module for parsing and editing markdown links — inline,
  reference (full / collapsed / shortcut), and URI autolinks — plus
  link reference definitions exposed via `definitions` and `resolve`.
- `gutenberg.link.Config.default_kind` to control the kind `link.create`
  produces when one is not supplied.

[Unreleased]: https://github.com/PsychoLlama/gutenberg.nvim/commits/main
