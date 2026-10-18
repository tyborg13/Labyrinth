#!/bin/sh
# Director-only windowed proof. Every stage is explicit; no worker GUI retries.
set -eu
stage="${1:?Use density, rest, native, production, idle, review or sheets}"
project="$(pwd)"
rig_case="$project/experiments/cutouts/hoarfrost_seer/rr10"
proof="$rig_case/proof"
case "$stage" in
density)
python3 tools/visual_probe_runner.py --task-id rr-10 --no-headless --display-driver macos --audio-driver Dummy --timeout 180 tests/rr10/density_rebake.gd -- --only hoarfrost_seer_cutout
python3 tools/process_board_density.py --record-rests --only hoarfrost_seer_cutout
python3 tools/godot_task_runner.py --task-id rr-10 --stream -- godot --headless --path . --script tools/generate_unit_shadow_cache.gd
python3 tools/process_board_density.py --check --only hoarfrost_seer_cutout
python3 experiments/cutouts/hoarfrost_seer/rr10_density.py seal
;;
rest)
python3 tools/visual_probe_runner.py --task-id rr-10 --no-headless --display-driver macos --audio-driver Dummy --timeout 120 --expect-size 1920x1080 --proof-contract tests/rr10/rest_contract.json tests/rr10/native_capture.gd -- --case "$rig_case" --output "$proof/native_rest" --rest-only
;;
native)
python3 tools/godot_task_runner.py --task-id rr-10 --stream -- godot --headless --path . --script tests/rr10/samples.gd -- --case "$rig_case" --output "$proof/samples.json"
python3 -B experiments/cutouts/hoarfrost_seer/rr10_gates.py
# Parallel isolated GPU piece/mask renders: intentionally longer than a UI shot.
python3 tools/visual_probe_runner.py --task-id rr-10 --no-headless --display-driver macos --audio-driver Dummy --timeout 3600 --expect-size 1920x1080 --proof-contract tests/rr10/render_contract.json tests/rr10/native_capture.gd -- --case "$rig_case" --output "$proof/native"
python3 -B experiments/cutouts/hoarfrost_seer/rr10_gates.py --native "$proof/native"
;;
production)
python3 tools/visual_probe_runner.py --task-id rr-10 --no-headless --display-driver macos --audio-driver Dummy --timeout 900 --expect-size 1920x1080 --proof-contract tests/rr10/production_contract.json tests/rr10/production_capture.gd -- --type hoarfrost_seer --output "$proof/production_native"
;;
idle)
python3 tools/visual_probe_runner.py --task-id rr-10 --no-headless --display-driver macos --audio-driver Dummy --timeout 300 --expect-size 1920x1080 --proof-contract tests/rr10/idle_contract.json tests/rr10/native_capture.gd -- --case "$rig_case" --output "$proof/idle_native" --idle-comparison
PYTHONPATH=tools python3 -m humanoid_cutout.proof idle --case "$rig_case" --capture "$proof/idle_native" --output "$proof/seer_protagonist_idle.mp4"
;;
review)
# Requires both approved views; intentionally refuses the obsolete mirrored rear.
PYTHONPATH=tools python3 -m humanoid_cutout.proof review --case "$rig_case" --capture "$proof/native" --output "$proof/hoarfrost_seer_review.mp4"
;;
sheets)
PYTHONPATH=tools python3 -m humanoid_cutout.proof sheets --case "$rig_case" --capture "$proof/native" --output "$proof/contact_sheets"
;;
*) exit 2 ;;
esac
