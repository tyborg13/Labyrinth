#!/bin/sh
# Director-only native commands. Run from the rr-25 worktree root.
set -eu
project="$(pwd)"
rig_case="$project/experiments/cutouts/slag_mortar/rr22"
proof="$rig_case/proof"
stage="${1:-help}"
mkdir -p "$proof/logs"
case "$stage" in
  density)
    python3 tools/process_board_density.py --only slag_mortar_cutout
    python3 tools/visual_probe_runner.py --task-id rr-25 --no-headless --display-driver macos --audio-driver Dummy --timeout 180 --expect-size 1920x1080 --proof-contract tests/rr22/density_contract.json --result-manifest "$proof/logs/density-result.json" tests/rr22/density_rebake.gd -- --only slag_mortar_cutout
    python3 tools/process_board_density.py --only slag_mortar_cutout --record-rests
    python3 experiments/cutouts/slag_mortar/rr22_density.py seal
    python3 tools/godot_task_runner.py --task-id rr-25 --stream -- godot --headless --path . --script tests/rr22/shadow_refresh.gd
    python3 tools/process_board_density.py --only slag_mortar_cutout --check
    ;;
  rest)
    python3 tools/visual_probe_runner.py --task-id rr-25 --no-headless --display-driver macos --audio-driver Dummy --timeout 120 --expect-size 1920x1080 --proof-contract tests/rr22/rest_contract.json --result-manifest "$proof/logs/rest-result.json" tests/rr22/native_capture.gd -- --output "$proof/native_rest" --rest-only
    ;;
  native)
    python3 tools/godot_task_runner.py --task-id rr-25 --stream -- godot --headless --path . --script tests/rr22/samples.gd -- --case "$rig_case" --output "$proof/logs/samples_full.json"
    python3 experiments/cutouts/slag_mortar/rr22_records.py samples
    python3 tools/visual_probe_runner.py --task-id rr-25 --no-headless --display-driver macos --audio-driver Dummy --timeout 900 --expect-size 1920x1080 --proof-contract tests/rr22/render_contract.json --result-manifest "$proof/logs/native-result.json" tests/rr22/native_capture.gd -- --output "$proof/native"
    python3 experiments/cutouts/slag_mortar/rr22_gates.py --native "$proof/native"
    ;;
  sheets)
    PYTHONPATH=tools python3 -m humanoid_cutout.proof sheets --case "$rig_case" --capture "$proof/native" --output "$proof/contact_sheets"
    ;;
  walk)
    python3 tools/visual_probe_runner.py --task-id rr-25 --no-headless --display-driver macos --audio-driver Dummy --timeout 180 --expect-size 1920x1080 --proof-contract tests/gait01/move_contract.json --result-manifest "$proof/logs/walk-result.json" tests/gait01/move_capture.gd -- --case "$rig_case" --output "$proof/gait_move_native"
    PYTHONPATH=tools python3 -m humanoid_cutout.move_sheet --case "$rig_case" --capture "$proof/gait_move_native" --output "$proof/gait_move_sheet.png"
    ;;
  idle)
    python3 tools/visual_probe_runner.py --task-id rr-25 --no-headless --display-driver macos --audio-driver Dummy --timeout 180 --expect-size 1920x1080 --proof-contract tests/rr22/idle_contract.json --result-manifest "$proof/logs/idle-result.json" tests/rr22/native_capture.gd -- --output "$proof/idle_native" --idle-comparison
    PYTHONPATH=tools python3 -m humanoid_cutout.proof idle --case "$rig_case" --capture "$proof/idle_native" --output "$proof/slag_mortar_idle_comparison.mp4"
    ;;
  production)
    for facing in front rear; do
      opposite=""
      if [ "$facing" = rear ]; then opposite="--opposite"; fi
      python3 tools/visual_probe_runner.py --task-id rr-25 --no-headless --display-driver macos --audio-driver Dummy --timeout 900 --expect-size 1920x1080 --proof-contract tests/rr22/production_contract.json --result-manifest "$proof/logs/production-$facing-result.json" tests/rr22/production_capture.gd -- --type slag_mortar --output "$proof/production_native/$facing" $opposite
    done
    ;;
  review)
    PYTHONPATH=tools python3 -m humanoid_cutout.proof review --case "$rig_case" --capture "$proof/native" --output "$proof/slag_mortar_review.mp4"
    ;;
  *) echo 'Usage: sh experiments/cutouts/slag_mortar/rr22_proof.sh density|rest|native|sheets|walk|idle|production|review'; exit 2 ;;
esac
