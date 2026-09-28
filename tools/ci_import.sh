#!/usr/bin/env bash
# Imports all project resources headless and fails on any error line.
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
LOG="$(mktemp)"
timeout 600 "$GODOT" --headless --import 2>&1 | tee "$LOG"
if grep -E "^(ERROR|SCRIPT ERROR|USER ERROR)" "$LOG"; then
  echo "::error::Errors during import"
  exit 1
fi
echo "Import OK"
