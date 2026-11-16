#!/bin/sh
# Native cel, real save, 1920x1080 at 100%. Run by the design owner.
# usage: native_capture.sh <save-dir> <rest|x,y> <name> <mark x,y> [probe args...]
set -eu
TASK_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
CAPTURE_OUT=${ATK11_CAPTURE_OUT:-/private/tmp/labyrinth_codex/atk-11/captures}
SAVE_DIR=$1
TARGET=$2
CAPTURE_NAME=$3
MARK=$4
shift 4
mkdir -p "$CAPTURE_OUT"
cd "$TASK_ROOT"
LABYRINTH_CEL_LOOK=all python3 tools/visual_probe_runner.py \
  --project "$TASK_ROOT" --godot "$TASK_ROOT/tools/rd07/native_capture.sh" \
  --no-headless --display-driver macos --audio-driver Dummy \
  --rendering-driver metal --rendering-method mobile --timeout 300 \
  --expect-size 1920x1080 --proof-contract tools/atk11/capture_contract.json \
  --result-manifest "$CAPTURE_OUT/$CAPTURE_NAME.manifest.json" \
  res://tools/atk11/capture.gd --task-id atk-11 -- \
  --save-dir "$SAVE_DIR" --tile "$TARGET" --mark "$MARK" \
  --out "$CAPTURE_OUT/$CAPTURE_NAME.png" "$@" > "$CAPTURE_OUT/$CAPTURE_NAME.log" 2>&1
cat "$CAPTURE_OUT/$CAPTURE_NAME.log"
