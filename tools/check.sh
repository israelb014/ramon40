#!/usr/bin/env bash
# Refreshes the class cache, then compiles every project script (with autoloads) and reports failures.
cd "$(dirname "$0")/.."
timeout 300 godot --headless --import >/dev/null 2>&1
timeout 300 godot --headless --path . tools/dev/check.tscn 2>&1 | grep -E "SCRIPT ERROR|ERROR|FAILED|check done|Parse Error"
