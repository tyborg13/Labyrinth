#!/bin/sh
# Use the archived captured fixture; no replay or fixture mutation is needed.
set -eu
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-57 && python3 tools/visual_probe_runner.py --task-id qa-57 --no-headless --display-driver macos --audio-driver Dummy --timeout 600 --startup-timeout 60 --expect-size 1920x1080 --proof-contract spec/peer_benchmark/qa/controller_hunt_2026-11-05b/treasure_reveal-proof-contract.json --result-manifest /private/tmp/labyrinth_codex/qa-57/native/treasure_reveal-manifest.json /private/tmp/labyrinth_codex/qa-57/tools/treasure_reveal_probe.gd -- --fixture res://spec/peer_benchmark/qa/controller_hunt_2026-11-05b/treasure-reveal.variant --output-dir /private/tmp/labyrinth_codex/qa-57/native/treasure_reveal
