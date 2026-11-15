#!/bin/sh
# atk-07 native cel capture of a real save before a turn Freeze skips:
# PASS hovered, the frozen turn, and the span after PASS on it.
# usage: native_capture.sh <repro dir> <name>
set -u
W=/Users/borgerding/workspace/Labyrinth.worktrees/atk-07
OUT=/private/tmp/labyrinth_codex/atk-07/captures/$2
mkdir -p "$OUT"
sh /Users/borgerding/workspace/Labyrinth.worktrees/peer-benchmark/spec/peer_benchmark/director_tools/wait_owner_idle.sh
cd "$W"
LABYRINTH_CEL_LOOK=all python3 tools/visual_probe_runner.py --project "$W" --godot "$W/tools/rd07/native_capture.sh" --no-headless --display-driver macos --audio-driver Dummy --rendering-driver metal --rendering-method mobile --timeout 400 --expect-size 1920x1080 --result-manifest "$OUT/manifest.json" --overwrite-result-manifest res://tools/atk07/capture.gd --task-id atk-07-capture -- --save-dir "$1" --out-dir "$OUT" --name "$2" > "$OUT/capture.log" 2>&1
echo "rc=$? $2"
grep -E "ATK07 CAPTURE|Cel look variant unavailable|SCRIPT ERROR|Validated" "$OUT/capture.log" | head -8
