#!/bin/sh
# atk-03 native cel capture of a real save: rest, PASS hovered, after Pass.
# usage: native_capture.sh <repro dir> <foe key> <name>
set -u
W=/Users/borgerding/workspace/Labyrinth.worktrees/atk-03
OUT=/private/tmp/labyrinth_codex/atk-03/captures/$3
mkdir -p "$OUT"
sh /Users/borgerding/workspace/Labyrinth.worktrees/peer-benchmark/spec/peer_benchmark/director_tools/wait_owner_idle.sh
cd "$W"
LABYRINTH_CEL_LOOK=all python3 tools/visual_probe_runner.py --project "$W" --godot "$W/tools/rd07/native_capture.sh" --no-headless --display-driver macos --audio-driver Dummy --rendering-driver metal --rendering-method mobile --timeout 300 --expect-size 1920x1080 --result-manifest "$OUT/manifest.json" --overwrite-result-manifest res://tools/atk03/capture.gd --task-id atk-03-capture -- --save-dir "$1" --foe "$2" --out-dir "$OUT" > "$OUT/capture.log" 2>&1
echo "rc=$? $3"
grep -E "ATK03 CAPTURE|Cel look variant unavailable|SCRIPT ERROR|Validated" "$OUT/capture.log" | head -8
