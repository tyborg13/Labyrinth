#!/bin/bash
set -euo pipefail

project="/Users/borgerding/workspace/Labyrinth.worktrees/fx-14"
cd "$project"
output="/private/tmp/labyrinth_codex/fx-14/native"
mkdir -p "$output"
manifest=$(mktemp "$output/proof.XXXXXX")
rm "$manifest"

LABYRINTH_CEL_LOOK=all python3 tools/visual_probe_runner.py \
  --no-headless --display-driver macos --audio-driver Dummy --task-id fx-14 \
  --timeout 300 --expect-size 1920x1080 --expect-size 3840x480 \
  --proof-contract tools/fx14/native_proof.json --result-manifest "$manifest" \
  tools/fx14/native.gd

captures=$(python3 - "$manifest" <<'PYTHON'
import json
from pathlib import Path
import sys

report = json.loads(Path(sys.argv[1]).read_text())
strips = [Path(image["path"]) for image in report["images"] if image["path"].endswith("_strip.png")]
print(strips[0].parent)
PYTHON
)
ffmpeg -hide_banner -loglevel error -nostdin -framerate 60 -i "$captures/reel/%04d.png" \
  -frames:v 240 -c:v libx264 -pix_fmt yuv420p "$manifest.mp4"
printf 'Source frames and strips: %s\nProof manifest: %s\nFour-second recording: %s\n' "$captures" "$manifest" "$manifest.mp4"
