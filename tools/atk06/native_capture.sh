#!/bin/sh
# atk-06 native cel capture of a real audit save, at rest or with one
# hero-movement destination hovered; 1920x1080, 100% UI scale.
# usage: native_capture.sh <repro dir> <rest|x,y> <name> [mark tiles "x,y;x,y"] [project dir]
# atk-09: ATK06_CAPTURE_OUT picks the output folder; the project defaults to this checkout.
set -u
HERE=$(cd "$(dirname "$0")/../.." && pwd)
W=${5:-$HERE}
OUT=${ATK06_CAPTURE_OUT:-/private/tmp/labyrinth_codex/atk-06/captures}
mkdir -p "$OUT"
sh /Users/borgerding/workspace/Labyrinth.worktrees/peer-benchmark/spec/peer_benchmark/director_tools/wait_owner_idle.sh
cd "$W"
LABYRINTH_CEL_LOOK=all python3 tools/visual_probe_runner.py --project "$W" --godot "$W/tools/rd07/native_capture.sh" --no-headless --display-driver macos --audio-driver Dummy --rendering-driver metal --rendering-method mobile --timeout 300 --min-images 0 --result-manifest "$OUT/$3.manifest.json" --overwrite-result-manifest res://tools/atk06/capture.gd --task-id "${ATK06_TASK:-atk-06}-capture" -- --save-dir "$1" --tile "$2" --out "$OUT/$3.png" --mark "${4:-}" > "$OUT/$3.log" 2>&1
echo "rc=$? $3"
grep -E "ATK06 CAPTURE: |Cel look variant unavailable|SCRIPT ERROR|Validated" "$OUT/$3.log" | head -8
