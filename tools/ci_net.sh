#!/usr/bin/env bash
# LAN loopback test: a host and a client race each other headless over ENet on localhost.
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
PORT=${PORT:-24555}
HLOG="$(mktemp)"; CLOG="$(mktemp)"
timeout 600 "$GODOT" --headless --fixed-fps 60 --path . tools/dev/net_test.tscn -- host $PORT > "$HLOG" 2>&1 &
HPID=$!
sleep 3
timeout 600 "$GODOT" --headless --fixed-fps 60 --path . tools/dev/net_test.tscn -- client $PORT > "$CLOG" 2>&1
wait $HPID
echo "== host"; cat "$HLOG"; echo "== client"; cat "$CLOG"
if grep -E "^(ERROR|SCRIPT ERROR|USER ERROR)" "$HLOG" "$CLOG"; then
  echo "::error::Errors during LAN test"
  exit 1
fi
grep -q "NET DONE host" "$HLOG" && grep -q "NET DONE client" "$CLOG" || { echo "::error::LAN race did not complete"; exit 1; }
echo "LAN OK"
