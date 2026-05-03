# Developing

- `just check` must pass before committing.

## Docs

- Update `CHANGELOG.md` under `[Unreleased]` for user-facing changes.
- Keep `doc/gutenberg.txt` in sync with API/config changes. Regenerate tags with `just gen-helptags`.
- Vim help syntax reference: `$VIMRUNTIME/doc/` (get path with `nvim --headless -c 'echo $VIMRUNTIME' -c quit 2>&1`)
