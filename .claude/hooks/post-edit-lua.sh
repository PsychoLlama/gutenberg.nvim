#!/usr/bin/env bash
# PostToolUse hook: lint a single Lua file after it's edited.
# Surfaces luacheck output back to Claude via additionalContext.
set -euo pipefail

input=$(cat)
file_path=$(jq -r '.tool_input.file_path // empty' <<<"$input")

# Bail unless this looks like a Lua file under the project tree.
[[ "$file_path" == *.lua ]] || exit 0
[[ -f "$file_path" ]] || exit 0

repo_root=$(git -C "$(dirname "$file_path")" rev-parse --show-toplevel 2>/dev/null || echo "")
[[ -n "$repo_root" ]] || exit 0

# Run luacheck from the repo root so .luacheckrc applies. Strip ANSI colors.
output=$(cd "$repo_root" && luacheck --no-color --codes "$file_path" 2>&1) && status=0 || status=$?

# luacheck exit codes: 0=clean, 1=warnings, 2=errors, >=3=critical/IO. 0 = silent.
[[ $status -eq 0 ]] && exit 0

jq -n --arg ctx "luacheck reported issues in $(realpath --relative-to="$repo_root" "$file_path"):
$output" '{
  hookSpecificOutput: {
    hookEventName: "PostToolUse",
    additionalContext: $ctx
  }
}'
