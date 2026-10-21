#!/bin/sh
# Director-only native commands. rr31 retains the accepted rr30 case paths.
set -eu
project="$(pwd)"
task_id="${LABYRINTH_TASK_ID:-rr-31}"
rig_case="$project/experiments/cutouts/slag_mortar/rr30"
proof="$rig_case/proof"
stage="${1:-help}"
mkdir -p "$proof/logs"
case "$stage" in
  density)
    python3 tools/process_board_density.py --only slag_mortar_cutout
    python3 tools/visual_probe_runner.py --task-id "$task_id" --no-headless --display-driver macos --audio-driver Dummy --timeout 180 --expect-size 1920x1080 --proof-contract tests/rr22/density_contract.json --overwrite-result-manifest --result-manifest "$proof/logs/density-result.json" tests/rr30/density_rebake.gd -- --only slag_mortar_cutout
    python3 tools/process_board_density.py --only slag_mortar_cutout --record-rests
    python3 experiments/cutouts/slag_mortar/rr30_density.py seal
    python3 tools/godot_task_runner.py --task-id "$task_id" --stream -- godot --headless --path . --script tests/rr22/shadow_refresh.gd
    python3 tools/process_board_density.py --only slag_mortar_cutout --check
    ;;
  rest)
    python3 tools/visual_probe_runner.py --task-id "$task_id" --no-headless --display-driver macos --audio-driver Dummy --timeout 120 --expect-size 1920x1080 --proof-contract tests/rr22/rest_contract.json --overwrite-result-manifest --result-manifest "$proof/logs/rest-result.json" tests/rr22/native_capture.gd -- --case "$rig_case" --output "$proof/native_rest" --rest-only
    ;;
  native)
    python3 tools/godot_task_runner.py --task-id "$task_id" --stream -- godot --headless --path . --script tests/rr22/samples.gd -- --case "$rig_case" --output "$proof/logs/samples_full.json"
    python3 experiments/cutouts/slag_mortar/rr30_records.py samples
    python3 tools/visual_probe_runner.py --task-id "$task_id" --no-headless --display-driver macos --audio-driver Dummy --timeout 900 --expect-size 1920x1080 --proof-contract tests/rr22/render_contract.json --overwrite-result-manifest --result-manifest "$proof/logs/native-result.json" tests/rr22/native_capture.gd -- --case "$rig_case" --output "$proof/native"
    gate_status=0
    python3 experiments/cutouts/slag_mortar/rr30_gates.py --native "$proof/native" || gate_status=1
    # Director feedback 2: image morphology is diagnostic only. Canonical
    # rr30 gates above remain blocking, including native source-space seams.
    python3 experiments/cutouts/slag_mortar/rr31_images.py native --capture "$proof/native" || echo 'RR31 IMAGE DIAGNOSTIC: unavailable (non-blocking)'
    exit "$gate_status"
    ;;
  sheets)
    PYTHONPATH=tools python3 -m humanoid_cutout.proof sheets --case "$rig_case" --capture "$proof/native" --output "$proof/contact_sheets"
    ;;
  walk)
    python3 tools/visual_probe_runner.py --task-id "$task_id" --no-headless --display-driver macos --audio-driver Dummy --timeout 180 --expect-size 1920x1080 --proof-contract tests/gait01/move_contract.json --overwrite-result-manifest --result-manifest "$proof/logs/walk-result.json" tests/gait01/move_capture.gd -- --case "$rig_case" --output "$proof/gait_move_native"
    PYTHONPATH=tools python3 -m humanoid_cutout.move_sheet --case "$rig_case" --capture "$proof/gait_move_native" --output "$proof/gait_move_sheet.png"
    ;;
  idle)
    python3 tools/visual_probe_runner.py --task-id "$task_id" --no-headless --display-driver macos --audio-driver Dummy --timeout 180 --expect-size 1920x1080 --proof-contract tests/rr22/idle_contract.json --overwrite-result-manifest --result-manifest "$proof/logs/idle-result.json" tests/rr22/native_capture.gd -- --case "$rig_case" --output "$proof/idle_native" --idle-comparison
    PYTHONPATH=tools python3 -m humanoid_cutout.proof idle --case "$rig_case" --capture "$proof/idle_native" --output "$proof/slag_mortar_idle_comparison.mp4"
    ;;
  production)
    for facing in front rear; do
      opposite=""
      if [ "$facing" = rear ]; then opposite="--opposite"; fi
      python3 tools/visual_probe_runner.py --task-id "$task_id" --no-headless --display-driver macos --audio-driver Dummy --timeout 900 --expect-size 1920x1080 --proof-contract tests/rr22/production_contract.json --overwrite-result-manifest --result-manifest "$proof/logs/production-$facing-result.json" tests/rr30/production_capture.gd -- --type slag_mortar --output "$proof/production_native/$facing" $opposite
    done
    python3 tools/capture_gate_runner.py --production --case "$rig_case" --native "$proof/production_native" --output "$proof/production_native"
    ;;
  review)
    PYTHONPATH=tools python3 -m humanoid_cutout.proof review --case "$rig_case" --capture "$proof/native" --output "$proof/slag_mortar_review.mp4"
    ;;
  *) echo 'Usage: sh experiments/cutouts/slag_mortar/rr30_proof.sh density|rest|native|sheets|walk|idle|production|review'; exit 2 ;;
esac
