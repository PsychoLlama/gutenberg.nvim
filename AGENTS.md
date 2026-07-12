# Developing

- `just check` must pass before committing.
- Annotate all functions, fields, and module APIs with LuaCATS types.
- Code comments explain _why_, not _what_. Skip them when the code is self-evident.

## Architecture

- One module per markdown construct, all with the same surface: `is_*` probes the cursor, `read` decodes the node into a plain value type, `create`/`render` build text from a value, `replace` writes it back in one update, and getter/setter pairs mutate the value in memory.
- Shared treesitter plumbing lives in `gutenberg.ts`: cursor→node resolution, range clamps, container prefixes, traversal. Feature modules must not call `vim.treesitter.get_parser` or `descendant_for_range` directly — extend `gutenberg.ts` when it falls short.
- All buffer writes go through `gutenberg.buffer`, which skips no-op writes so they don't pollute undo history.
- Specs live in a `tests/` directory colocated with the module they cover (e.g. `foo.lua` is tested by `tests/foo_spec.lua` in the same directory) and share `gutenberg.tests.utils` for scratch buffers. The flake drops every `tests/` directory (at any depth) from the packaged fileset, so support code never ships.

## API Design

- Lean powerful, not simple for its own sake. Favor composable primitives over convenience methods.
- No `toggle`-style helpers. Setters take an explicit value, paired with getters for reading state.
- Don't assume the cursor or current buffer. Accept buffer + position (or other targets) as context.
- Multi-step operations should produce a single buffer update. Keep transforms in-memory and write once at the end.
- Parse with Treesitter, never by hand. It doesn't serialize—apply edits via `nvim_buf_set_text` over node ranges.

## Docs

- Update `CHANGELOG.md` under `[Unreleased]` for user-facing changes.
- Keep `doc/gutenberg.txt` in sync with API/config changes. Regenerate tags with `just gen-helptags`.
- Vim help syntax reference: `$VIMRUNTIME/doc/` (get path with `nvim --headless -c 'echo $VIMRUNTIME' -c quit 2>&1`)
