#!/bin/sh
# Owner only: native_capture.sh <audited-save-dir> <enemy> <intent>
set -eu
TASK_ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
CAPTURE_OUT=${AREA01_CAPTURE_OUT:-/private/tmp/labyrinth_codex/area-01/feedback2/captures}
SAVE_DIR=$1
ENEMY=$2
INTENT=$3
SINGLE=${4:-false}
PROOF_ATTEMPTS=1
CONTRACT=tools/atk13/area01/capture_contract.json
if [ "$SINGLE" = true ]; then CONTRACT=tools/atk13/area01/single_capture_contract.json; fi
mkdir -p "$CAPTURE_OUT"
cd "$TASK_ROOT"
LABYRINTH_CEL_LOOK=all python3 tools/visual_probe_runner.py \
  --project "$TASK_ROOT" --godot "$TASK_ROOT/tools/rd07/native_capture.sh" \
  --no-headless --display-driver macos --audio-driver Dummy \
  --rendering-driver metal --rendering-method mobile --timeout 300 --attempts "$PROOF_ATTEMPTS" \
  --expect-size 1920x1080 --proof-contract "$CONTRACT" \
  --result-manifest "$CAPTURE_OUT/$ENEMY-$INTENT.manifest.json" \
  res://tools/atk13/area01/capture.gd --task-id area-01 -- \
  --save-dir "$SAVE_DIR" --enemy "$ENEMY" --intent "$INTENT" --single "$SINGLE" \
  --out "$CAPTURE_OUT/$ENEMY-$INTENT.png" > "$CAPTURE_OUT/$ENEMY-$INTENT.log" 2>&1
cat "$CAPTURE_OUT/$ENEMY-$INTENT.log"
