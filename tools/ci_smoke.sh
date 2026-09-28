#!/usr/bin/env bash
# Boots the game headless through the menu and an automated race, failing on any error output.
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
LOG="$(mktemp)"
timeout 900 "$GODOT" --headless --path . res://tests/smoke/smoke.tscn 2>&1 | tee "$LOG"
if grep -E "^(ERROR|SCRIPT ERROR|USER ERROR|WARNING)" "$LOG" | grep -v "audio" ; then
  echo "::error::Errors or warnings during smoke run"
  exit 1
fi
if ! grep -q "SMOKE OK" "$LOG"; then
  echo "::error::Smoke run did not finish"
  exit 1
fi
echo "Smoke OK"
