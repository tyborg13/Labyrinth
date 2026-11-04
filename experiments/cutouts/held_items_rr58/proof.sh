#!/bin/sh
# Explicit director stages; no GUI invocation by the implementation worker.
set -eu
rig="${1:?chainbound_gaoler or hoarfrost_seer}"
stage="${2:?prepare, native, compare or density}"
case "$rig" in chainbound_gaoler|hoarfrost_seer) ;; *) exit 2 ;; esac
base="${RR58_PROOF_ROOT:-/private/tmp/labyrinth_codex/rr-58}/$rig"
tools="experiments/cutouts/held_items_rr58"
native_timeout_seconds=900
density_timeout_seconds=180
case "$stage" in
prepare)
python3 -B "$tools/build.py" --prepare "$rig" --before --output "$base/native_before_case"
python3 -B "$tools/build.py" --prepare "$rig" --output "$base/native_after_case"
;;
native)
for state in before after; do
python3 tools/visual_probe_runner.py --task-id rr-58 --no-headless --display-driver macos --audio-driver Dummy --timeout "$native_timeout_seconds" --expect-size 1920x1080 --proof-contract "$tools/render_contract.json" --result-manifest "$base/native_${state}_result.json" "$tools/native.gd" -- --case "$base/native_${state}_case" --output "$base/native_$state"
done
;;
compare)
python3 -B "$tools/proof.py" --rig "$rig" --native-before "$base/native_before" --native-after "$base/native_after" --output "$base/native_in_hand_pixels.json"
python3 -B "$tools/drops.py" --before "$base/native_before" --after "$base/native_after" --output "$base/native_drops"
;;
density)
python3 tools/visual_probe_runner.py --task-id rr-58 --no-headless --display-driver macos --audio-driver Dummy --timeout "$density_timeout_seconds" tools/rebake_cutout_rests.gd -- --only "${rig}_cutout"
python3 tools/process_board_density.py --record-rests --only "${rig}_cutout"
python3 tools/process_board_density.py --check --only "${rig}_cutout"
;;
*) exit 2 ;;
esac
