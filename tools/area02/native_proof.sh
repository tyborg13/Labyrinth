#!/bin/sh
# Owner-only native proof, cel look, 1920x1080, 100% UI scale; one attempt.
set -eu
TASK_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
cd "$TASK_ROOT"
PROOF_ROOT=/private/tmp/labyrinth_codex/cap-06
TASK_ID=${AREA02_TASK_ID:-cap-06}
SAVE_DIR=${AREA02_CANTOR_SAVE_DIR:-"$PROOF_ROOT/fixtures/storm_cantor"}
CAPTURE_OUT=${AREA02_CAPTURE_OUT:-"$PROOF_ROOT/captures"}
# Area-02 ladder entry 43, seed 59, room (15, -7).
CANTOR_LADDER_SKIP=42
if [ ! -s "$SAVE_DIR/run_state.txt" ]; then
  python3 tools/godot_task_runner.py --task-id "$TASK_ID" --stream -- godot \
    --headless --path . --script tools/area02/find_cantor_witness.gd -- \
    --skip "$CANTOR_LADDER_SKIP" --samples 1 --out "$SAVE_DIR"
fi
mkdir -p "$CAPTURE_OUT"
status=0
LABYRINTH_CEL_LOOK=all python3 tools/visual_probe_runner.py \
  --project "$TASK_ROOT" --godot "$TASK_ROOT/tools/rd07/native_capture.sh" \
  --no-headless --display-driver macos --audio-driver Dummy \
  --rendering-driver metal --rendering-method mobile --timeout 300 --attempts 1 \
  --expect-size 1920x1080 --proof-contract tools/area02/cantor_contract.json \
  --result-manifest "$CAPTURE_OUT/cantor.manifest.json" \
  res://tools/area02/capture.gd --task-id "$TASK_ID" -- \
  --save-dir "$SAVE_DIR" --view area02 --out "$CAPTURE_OUT/cantor.png" --case cantor --fringe-witness true \
  > "$CAPTURE_OUT/cantor.log" 2>&1 || status=$?
cat "$CAPTURE_OUT/cantor.log"
exit "$status"
