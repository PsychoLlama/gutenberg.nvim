_:
  just --list

# Format all files.
fmt:
  treefmt

# Check that all files are formatted.
fmt-check:
  treefmt --ci

# Regenerate Vim help tags for doc/.
gen-helptags:
  nvim --headless -c 'helptags doc' -c quit

# Run luacheck on all Lua files.
lint:
  luacheck lua

# Run Lua unit tests with vusted.
test:
  vusted lua

# Run lua-language-server type checks.
typecheck:
  #!/usr/bin/env bash
  set -euo pipefail
  export VIMRUNTIME=$(nvim --clean --headless --cmd 'echo $VIMRUNTIME | q' 2>&1)
  lua-language-server --check . --checklevel=Warning

# Run all checks (lint + typecheck + unit tests + fmt), reporting all failures.
check:
  #!/usr/bin/env bash
  failed=0
  just lint || failed=1
  just typecheck || failed=1
  just test || failed=1
  just fmt-check || failed=1
  exit $failed
