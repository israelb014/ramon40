#!/usr/bin/env bash
# Exports release builds for Windows x64 and Linux x64 into build/.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
rm -rf build/windows build/linux
mkdir -p build/windows build/linux
timeout 900 "$GODOT" --headless --export-release "Windows Desktop" build/windows/Ramon40.exe
timeout 900 "$GODOT" --headless --export-release "Linux" build/linux/Ramon40.x86_64
test -s build/windows/Ramon40.exe
test -s build/linux/Ramon40.x86_64
cp README.md CREDITS.md build/windows/ 2>/dev/null || true
cp README.md CREDITS.md build/linux/ 2>/dev/null || true
ls -la build/windows build/linux
