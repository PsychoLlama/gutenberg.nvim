# Developing

- `just check` must pass before committing.
- Everything must be fully typed.
- Code comments explain _why_, not _what_. Skip them when the code is self-evident.

## Architecture

- One module per markdown construct, all with the same surface: `is_*` probes the cursor, `read` decodes the node into a plain value type, `create`/`render` build text from a value, `replace` writes it back in one update, and getter/setter pairs mutate the value in memory.
- Node recognition is declared in `queries/{markdown,markdown_inline}/gutenberg.scm` — runtime treesitter query files with one capture per construct (`@heading`, `@table`, `@link`, …). The query-file namespace is shared across the whole `runtimepath`, so the file name carries the plugin prefix; users extend recognition with their own `;; extends` query.
- Shared treesitter plumbing lives in `gutenberg.ts`: it loads those queries and resolves cursor→capture, plus range clamps, container prefixes, traversal. Feature modules must not call `vim.treesitter.get_parser` or run queries directly — extend `gutenberg.ts` when it falls short.
- All buffer writes go through `gutenberg.buffer`, which skips no-op writes so they don't pollute undo history.
- Specs live in a `tests/` directory colocated with the module they cover (e.g. `foo.lua` is tested by `tests/foo_spec.lua` in the same directory) and share `gutenberg.tests.utils` for scratch buffers. The flake drops every `tests/` directory (at any depth) from the packaged fileset, so support code never ships.

## API Design

- API first, not API only: behaviors are designed to be bound to keymaps, but every one must be drivable through the public API (see RECIPES in `doc/gutenberg.txt` for the intended edge).
- Modules never call `vim.notify` — they `error('gutenberg: ...', 0)`. Level 0 drops the file:line prefix so the message doubles as UI copy; the keymap edge decides whether to `pcall` + notify. Errors fire before any buffer write so failed transforms stay atomic.
- Lean powerful, not simple for its own sake. Favor composable primitives over convenience methods.
- APIs should be explicit. For example: instead of `toggle_checkbox`, have `set_checked` and `is_checked`.
  - Only add sugar APIs if they can build on lower-level public primitives, and only if they carry their weight.
- Don't assume the cursor or current buffer. Accept buffer + position (or other targets) as context.
- Multi-step operations should produce a single buffer update. Keep transforms in-memory and write once at the end.
- Parse with Treesitter, never by hand. It doesn't serialize—apply edits via `nvim_buf_set_text` over node ranges.
- Only pay for what you use. Defer work until a module is imported or a function is called. Cache where appropriate.

## Docs

- Update `CHANGELOG.md` under `[Unreleased]` for user-facing changes.
- Keep `doc/gutenberg.txt` in sync with API/config changes. Regenerate tags with `just gen-helptags`.
- Vim help syntax reference: `$VIMRUNTIME/doc/` (get path with `nvim --headless -c 'echo $VIMRUNTIME' -c quit 2>&1`)
