#!/bin/sh
# Run against the matching source tree. The probe checks the expected HUD rows.
set -eu

case "${1:-}" in
    before) expected=no ;;
    after) expected=yes ;;
    *) echo "Usage: sh tools/qa102/native_capture.sh before|after [fixture-directory]" >&2; exit 2 ;;
esac

proof="$PWD/output/mrg-07"
fixtures="${2:-$PWD/../qa-102/output/qa-102}"
mkdir -p "$proof/native-$1"
for action in pass move; do
    LABYRINTH_GROUND_FX= LABYRINTH_DEMO= python3 tools/visual_probe_runner.py \
        --no-headless --display-driver macos --audio-driver Dummy --task-id mrg-07 \
        --expect-size 1920x1080 --proof-contract tools/qa102/hud_contract.json \
        --result-manifest "$proof/native-$1/$action-result.json" tools/qa102/forecast_probe.gd -- \
        --manifest "$fixtures/$action.json" --out-dir "$proof/native-$1/$action" --expect-arrival "$expected"
done
