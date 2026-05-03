# Developing

- `just check` must pass before committing.
- Annotate all functions, fields, and module APIs with LuaCATS types.
- Code comments explain _why_, not _what_. Skip them when the code is self-evident.

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
