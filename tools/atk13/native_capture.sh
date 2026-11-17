#!/bin/sh
# Usage: native_capture.sh <save-dir> <view> <name> [--enemy TYPE --intent ID]
set -u
TASK_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
CAPTURE_OUT=${ATK13_CAPTURE_OUT:-/private/tmp/labyrinth_codex/atk-13/captures}
SAVE_DIR=$1
VIEW=$2
CAPTURE_NAME=$3
shift 3
mkdir -p "$CAPTURE_OUT"
cd "$TASK_ROOT"
LABYRINTH_CEL_LOOK=all python3 tools/visual_probe_runner.py \
  --project "$TASK_ROOT" --godot "$TASK_ROOT/tools/rd07/native_capture.sh" \
  --no-headless --display-driver macos --audio-driver Dummy \
  --rendering-driver metal --rendering-method mobile --timeout 300 \
  --expect-size 1920x1080 --proof-contract "${ATK13_PROOF_CONTRACT:-tools/atk13/capture_contract.json}" \
  --result-manifest "$CAPTURE_OUT/$CAPTURE_NAME.manifest.json" \
  "${ATK13_CAPTURE_SCRIPT:-res://tools/atk13/capture.gd}" --task-id "${LABYRINTH_TASK_ID:-atk-13}" -- \
  --save-dir "$SAVE_DIR" --view "$VIEW" --out "$CAPTURE_OUT/$CAPTURE_NAME.png" "$@" \
  > "$CAPTURE_OUT/$CAPTURE_NAME.log" 2>&1
cat "$CAPTURE_OUT/$CAPTURE_NAME.log"
