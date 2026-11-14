#!/bin/sh
# atk-04 native cel capture of a real audit save: hover one hero-movement
# destination (or PASS) with a real pointer and save the 1920x1080 frame.
# usage: native_capture.sh <repro dir> <x,y|pass> <name>
set -u
W=/Users/borgerding/workspace/Labyrinth.worktrees/atk-04
OUT=/private/tmp/labyrinth_codex/atk-04/captures
mkdir -p "$OUT"
sh /Users/borgerding/workspace/Labyrinth.worktrees/peer-benchmark/spec/peer_benchmark/director_tools/wait_owner_idle.sh
cd "$W"
LABYRINTH_CEL_LOOK=all python3 tools/visual_probe_runner.py --project "$W" --godot "$W/tools/rd07/native_capture.sh" --no-headless --display-driver macos --audio-driver Dummy --rendering-driver metal --rendering-method mobile --timeout 300 --expect-size 1920x1080 --result-manifest "$OUT/$3.json" --overwrite-result-manifest res://tools/atk01/capture.gd --task-id atk-04-capture -- --save-dir "$1" --tile "$2" --out "$OUT/$3.png" > "$OUT/$3.log" 2>&1
echo "rc=$? $3"
grep -E "ATK01 CAPTURE|Cel look variant unavailable|SCRIPT ERROR|Validated" "$OUT/$3.log" | head -8
