#!/bin/sh
# Director-only windowed proof. Every stage is explicit; no worker GUI retries.
set -eu
stage="${1:?Use density, rest, native, production, idle, review or sheets}"
project="$(pwd)"
task_id="${LABYRINTH_TASK_ID:-rr-11}"
rig_case="$project/experiments/cutouts/arc_thrall/rr11"
proof="$rig_case/proof"
case "$stage" in
density)
python3 tools/visual_probe_runner.py --task-id "$task_id" --no-headless --display-driver macos --audio-driver Dummy --timeout 180 tests/rr11/density_rebake.gd -- --only arc_thrall_cutout
python3 tools/process_board_density.py --record-rests --only arc_thrall_cutout
python3 tools/godot_task_runner.py --task-id "$task_id" --stream -- godot --headless --path . --script tests/rr11/shadow_refresh.gd
python3 tools/process_board_density.py --check --only arc_thrall_cutout
python3 experiments/cutouts/arc_thrall/rr11_density.py seal
;;
rest)
python3 tools/visual_probe_runner.py --task-id "$task_id" --no-headless --display-driver macos --audio-driver Dummy --timeout 120 --expect-size 1920x1080 --proof-contract tests/rr11/rest_contract.json tests/rr11/native_capture.gd -- --case "$rig_case" --output "$proof/native_rest" --rest-only
;;
native)
python3 tools/godot_task_runner.py --task-id "$task_id" --stream -- godot --headless --path . --script tests/rr11/action_direction.gd -- --case "$rig_case" --output "$proof/samples.json"
# Parallel isolated GPU piece/mask renders: intentionally longer than a UI shot.
python3 tools/visual_probe_runner.py --task-id "$task_id" --no-headless --display-driver macos --audio-driver Dummy --timeout 3600 --expect-size 1920x1080 --proof-contract tests/rr11/render_contract.json tests/rr11/native_capture.gd -- --case "$rig_case" --output "$proof/native"
python3 -B experiments/cutouts/arc_thrall/rr11_gates.py --native "$proof/native"
;;
production)
python3 tools/visual_probe_runner.py --task-id "$task_id" --no-headless --display-driver macos --audio-driver Dummy --timeout 900 --expect-size 1920x1080 --proof-contract tests/rr11/production_contract.json tests/rr11/production_capture.gd -- --type arc_thrall --output "$proof/production_native"
;;
idle)
python3 tools/visual_probe_runner.py --task-id "$task_id" --no-headless --display-driver macos --audio-driver Dummy --timeout 300 --expect-size 1920x1080 --proof-contract tests/rr11/idle_contract.json tests/rr11/native_capture.gd -- --case "$rig_case" --output "$proof/idle_native" --idle-comparison
PYTHONPATH=tools python3 -m humanoid_cutout.proof idle --case "$rig_case" --capture "$proof/idle_native" --output "$proof/thrall_protagonist_idle.mp4"
;;
review)
# Requires both approved views; intentionally refuses the obsolete mirrored rear.
PYTHONPATH=tools python3 -m humanoid_cutout.proof review --case "$rig_case" --capture "$proof/native" --output "$proof/arc_thrall_review.mp4"
;;
sheets)
PYTHONPATH=tools python3 -m humanoid_cutout.proof sheets --case "$rig_case" --capture "$proof/native" --output "$proof/contact_sheets"
;;
*) exit 2 ;;
esac
