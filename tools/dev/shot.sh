#!/usr/bin/env bash
# Renders dev screenshots with software Vulkan under Xvfb.
cd "$(dirname "$0")/../.."
timeout 400 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --resolution ${RES:-960x540} "${SCENE:-tools/dev/shot.tscn}" -- "$@" 2>&1 | grep -vE "ALSA|libpulse|audio_driver|All audio|^\s*at: (init_output|initialize)|^$|Condition \"status < 0\""
