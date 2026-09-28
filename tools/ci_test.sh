#!/usr/bin/env bash
# Runs the GUT unit test suite headless. Fails on test failures or engine errors.
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
LOG="$(mktemp)"
timeout 900 "$GODOT" --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | tee "$LOG"
STATUS=${PIPESTATUS[0]}
if ! grep -q "All tests passed" "$LOG"; then
  echo "::error::Unit tests failed"
  exit 1
fi
if grep -E "^(SCRIPT ERROR|USER ERROR)" "$LOG"; then
  echo "::error::Script errors while running tests"
  exit 1
fi
exit $STATUS
