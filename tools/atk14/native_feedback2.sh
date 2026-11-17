#!/bin/sh
# Before/after use the same scene, resolver, saves and sampling clock. Only the
# capture-only archived board painter is substituted for the before view.
set -eu
TASK_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
cd "$TASK_ROOT"
PROOF_PHASES=${1:-both}
export LABYRINTH_TASK_ID=atk-14
export ATK13_CAPTURE_SCRIPT=res://tools/atk14/capture.gd
export ATK13_PROOF_CONTRACT=tools/atk14/playback_contract.json
SAVE_ROOT=/private/tmp/labyrinth_codex/atk-13/audit/census/tier-1-seed-1305-hp9999/repro
CAPTURE_ROOT=${ATK14_CAPTURE_ROOT:-/private/tmp/labyrinth_codex/atk-14/feedback3/captures}
# Same cases/flags in headless mode; never pass a headless result as pixel proof.
capture_case() {
  if [ "${ATK14_HEADLESS:-0}" = 1 ]; then
    task_save=$1
    task_view=$2
    task_name=$3
    shift 3
    mkdir -p "$ATK13_CAPTURE_OUT"
    LABYRINTH_CEL_LOOK=all python3 tools/godot_task_runner.py --task-id atk-14 --stream -- godot --headless --path . --script tools/atk14/capture.gd -- --save-dir "$task_save" --view "$task_view" --out "$ATK13_CAPTURE_OUT/$task_name.png" "$@" > "$ATK13_CAPTURE_OUT/$task_name.log" 2>&1
    cat "$ATK13_CAPTURE_OUT/$task_name.log"
  else
    sh tools/atk13/native_capture.sh "$@"
  fi
}
for proof_phase in before after; do
  if [ "$PROOF_PHASES" != both ] && [ "$PROOF_PHASES" != "$proof_phase" ]; then continue; fi
  before_flag=false
  if [ "$proof_phase" = before ]; then before_flag=true; fi
  export ATK13_CAPTURE_OUT=$CAPTURE_ROOT/$proof_phase
  capture_case "$SAVE_ROOT/1305-2" playback peal --before "$before_flag" --peak-strip true
  capture_case "$SAVE_ROOT/1305-2" playback peal_reduced --before "$before_flag" --peak-strip true --reduced-motion true
  capture_case controlled zekarion zekarion_self_strike --case zekarion --before "$before_flag" --peak-strip true
  capture_case controlled skybreak skybreak --case skybreak --before "$before_flag" --peak-strip true
  if [ "${ATK14_HEADLESS:-0}" != 1 ]; then
    if [ "$proof_phase" = after ]; then
      python3 tools/atk14/brightness_probe.py --root "$ATK13_CAPTURE_OUT" --require-pass
    else
      python3 tools/atk14/brightness_probe.py --root "$ATK13_CAPTURE_OUT"
    fi
  fi
done
