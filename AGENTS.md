# Developing

- `just check` must pass before committing.
- Everything must be fully typed.

## Architecture

- Two module tiers, one module per markdown construct in each. Low-level primitives live under `lua/gutenberg/api/` with a shared surface: `is_*` probes the cursor, `read` decodes the node into a plain value type, `create`/`render` build text from a value, `replace` writes it back in one update, getter/setter pairs mutate the value in memory, and `find_*`/`list` navigate.
- Verbs live under `lua/gutenberg/constructs/`: user-facing, cursor-level functions built to be bound — keymap, command, operator-pending, picker — composing api primitives (read → mutate → replace), with UI-ready error messages. Verbs require `gutenberg.api.*` directly; api modules never require verbs. Value types (`gutenberg.list.Item`, `gutenberg.table.Table`, …) are declared in the api modules and shared by both tiers.
- Semantic verbs are a third surface, above the module tiers: one gesture covering an operation that has analogies across constructs — append a sibling (list item / table row), shift along the hierarchy axis (heading level / list nesting / table column), toggle the ordering axis (ordered list / column alignment). A semantic verb is a bare dispatch: probe with `is_*`, route to the matching construct verb, and error with UI-ready copy when nothing matches — no behavior of its own. They live at the keymap edge: `gutenberg.default_keymaps`, the one canonical copy of the recommended config — `setup({default_keymaps = {enable = true}})` binds it on FileType, `gutenberg.tour` applies it to the tour buffer, and the RECOMMENDED CONFIG section in `doc/gutenberg.txt` documents (but no longer duplicates) it.
- The public namespace: `require('gutenberg').list` resolves the verb module; `require('gutenberg.api').list` the primitives. Infrastructure (`buffer`, `config`, `context`, `treesitter`, …) stays directly under `lua/gutenberg/` and resolves through the root's require fallback.
- Node recognition is declared in `queries/{markdown,markdown_inline}/gutenberg.scm` — runtime treesitter query files with one capture per construct (`@heading`, `@table`, `@link`, …). The query-file namespace is shared across the whole `runtimepath`, so the file name carries the plugin prefix; users extend recognition with their own `;; extends` query.
- Shared treesitter plumbing lives in `gutenberg.treesitter`: it loads those queries and resolves cursor→capture, plus range clamps, container prefixes, traversal. Feature modules must not call `vim.treesitter.get_parser` or run queries directly — extend `gutenberg.treesitter` when it falls short.
- All buffer writes go through `gutenberg.buffer`, which skips no-op writes so they don't pollute undo history.
- Specs live in a `tests/` directory colocated with the module they cover (e.g. `foo.lua` is tested by `tests/foo_spec.lua` in the same directory) and share `gutenberg.tests.utils` for scratch buffers. The flake drops every `tests/` directory (at any depth) from the packaged fileset, so support code never ships.

## API Design

- Every public function is one of three kinds. Keep a new API cleanly in one bucket — a probe that edits, or a codemod that answers questions, is a design smell:
  - **Interpretation** answers questions about the document without changing it: the `is_*` probes, `read`, `get_*` accessors, `resolve`.
  - **Navigation** locates constructs: `heading.list`, `find_next` / `find_prev` / `find_parent`. `api.*` navigation returns values and nodes and never moves the cursor; root-level motion verbs (`heading.next`, `table.next_cell`, …) may move it — that is its whole job.
  - **Codemods** produce text or change the buffer: `create` / `render`, `set_*` mutations on in-memory values, `replace`, and the construct verbs that compose read → mutate → replace.
- When adding a verb, look for its analogy on the other constructs. Analogous verbs get parallel names and signatures (`list.insert_item({where})` / `table.insert_row({where})`, promote/dedent/move-left all take a bare `ctx`) so a semantic verb stays a probe chain — no per-construct adapters.
- API first, not API only: behaviors are designed to be bound to keymaps, but every one must be drivable through the public API (see RECIPES in `doc/gutenberg.txt` for the intended edge).
- Modules never call `vim.notify` — they `error('gutenberg: ...', 0)`. Level 0 drops the file:line prefix so the message doubles as UI copy; the keymap edge decides whether to `pcall` + notify. Errors fire before any buffer write so failed transforms stay atomic.
- The sanctioned UI edges — the only modules allowed to notify or prompt: `gutenberg.keymap` (adapters user mappings consume; pcall + `vim.notify`), `gutenberg.default_keymaps` (the recommended bindings, built on those adapters; also prompts for link URLs; `gutenberg.tour` binds it to the tour buffer), and `gutenberg.table.actions` (`vim.ui.select` picker). Everything else stays headless.
- Lean powerful, not simple for its own sake. Favor composable primitives over convenience methods.
- APIs should be explicit. For example: instead of `toggle_checkbox`, have `set_checked` and `is_checked`.
  - Only add verbs that build on lower-level public primitives, and only if they carry their weight.
- Don't assume the cursor or current buffer. Accept buffer + position (or other targets) as context.
- Multi-step operations should produce a single buffer update. Keep transforms in-memory and write once at the end.
- Parse with Treesitter, never by hand. It doesn't serialize—apply edits via `nvim_buf_set_text` over node ranges.
- Only pay for what you use. Defer work until a module is imported or a function is called. Cache where appropriate.

## Docs

- Update `CHANGELOG.md` under `[Unreleased]` for user-facing changes.
- Keep `doc/gutenberg.txt` in sync with API/config changes. Regenerate tags with `just gen-helptags`.
- Vim help syntax reference: `$VIMRUNTIME/doc/` (get path with `nvim --headless -c 'echo $VIMRUNTIME' -c quit 2>&1`)
