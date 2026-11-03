#!/bin/sh
# Director-only real-renderer proof at 1920x1080, 100% UI scale.
set -eu
stage="${1:?Use density, rest, native, seams, sheets, idle, production, review or depth}"
case_root="$(pwd)/experiments/cutouts/last_lamplighter/rr52"
rig_case="$case_root/proof/production_case"
proof="$case_root/proof"
export PYTHONPATH=tools
export LABYRINTH_CEL_LOOK=off
case "$stage" in production|depth) export LABYRINTH_CEL_LOOK=all ;; esac
mkdir -p "$proof/logs"
refresh() {
 python3 tools/godot_task_runner.py --task-id rr-52 --stream -- godot --headless --path . --script experiments/cutouts/last_lamplighter/rr52/probes/depth_probe.gd -- --list-only --output res://experiments/cutouts/last_lamplighter/rr52/probes/depth_inventory.json
 python3 -B experiments/cutouts/last_lamplighter/rr52_density.py --proof-case
 python3 tools/godot_task_runner.py --task-id rr-52 --stream -- godot --headless --path . --script experiments/cutouts/last_lamplighter/rr52/probes/samples.gd -- --case "$rig_case" --output "$rig_case/proof/samples.json"
 python3 tools/godot_task_runner.py --task-id rr-52 --stream -- godot --headless --path . --script experiments/cutouts/last_lamplighter/rr52/probes/raster_samples.gd -- --case "$rig_case" --geometry "$rig_case/proof/samples.json" --output "$rig_case/proof/raster_samples.json"
}
case "$stage" in
density)
 python3 tools/visual_probe_runner.py --task-id rr-52 --no-headless --display-driver macos --audio-driver Dummy --timeout 180 experiments/cutouts/last_lamplighter/rr52/probes/density_rebake.gd -- --only last_lamplighter_cutout
 python3 tools/visual_probe_runner.py --task-id rr-52 --no-headless --display-driver macos --audio-driver Dummy --timeout 120 --expect-size 1920x1080 --proof-contract experiments/cutouts/last_lamplighter/rr52/probes/density_contract.json experiments/cutouts/last_lamplighter/rr52/probes/density_capture.gd -- --output "$proof/native_rest/production"
 python3 tools/process_board_density.py --record-rests --only last_lamplighter_cutout
 python3 tools/godot_task_runner.py --task-id rr-52 --stream -- godot --headless --path . --script experiments/cutouts/last_lamplighter/rr52/probes/shadow_refresh.gd
 python3 tools/process_board_density.py --check --only last_lamplighter_cutout
 python3 -B experiments/cutouts/last_lamplighter/rr52_density.py --seal-native
 python3 tools/cel_look.py build --if-stale
 ;;
rest)
 refresh
 python3 tools/visual_probe_runner.py --task-id rr-52 --no-headless --display-driver macos --audio-driver Dummy --timeout 120 --expect-size 1920x1080 --proof-contract experiments/cutouts/last_lamplighter/rr52/probes/rest_contract.json experiments/cutouts/last_lamplighter/rr52/probes/native_capture.gd -- --case "$rig_case" --output "$proof/native_rest" --rest-only
 ;;
native)
 refresh
 python3 tools/visual_probe_runner.py --task-id rr-52 --no-headless --display-driver macos --audio-driver Dummy --timeout 3600 --expect-size 1920x1080 --proof-contract experiments/cutouts/last_lamplighter/rr52/probes/render_contract.json experiments/cutouts/last_lamplighter/rr52/probes/native_capture.gd -- --case "$rig_case" --output "$proof/native"
 status=0
 python3 -B experiments/cutouts/last_lamplighter/rr52_joint_budget.py --case "$rig_case" || status=$?
 python3 experiments/cutouts/last_lamplighter/rr52_native.py --case "$rig_case" --native "$proof/native" || status=$?
 exit "$status"
 ;;
seams)
 python3 experiments/cutouts/last_lamplighter/rr52_native.py --case "$rig_case" --native "$proof/native"
 ;;
sheets)
 python3 -m humanoid_cutout.proof sheets --case "$rig_case" --capture "$proof/native" --output "$proof/contact_sheets" --diagnostic
 ;;
idle)
 refresh
 python3 tools/visual_probe_runner.py --task-id rr-52 --no-headless --display-driver macos --audio-driver Dummy --timeout 300 --expect-size 1920x1080 --proof-contract experiments/cutouts/last_lamplighter/rr52/probes/idle_contract.json experiments/cutouts/last_lamplighter/rr52/probes/native_capture.gd -- --case "$rig_case" --output "$proof/idle_native" --idle-comparison
 python3 -m humanoid_cutout.proof idle --case "$rig_case" --capture "$proof/idle_native" --output "$proof/last_lamplighter_protagonist_idle.mp4"
 ;;
production)
 for view in front rear; do
  if [ "$view" = rear ]; then rear=--rear; else rear=; fi
  python3 tools/visual_probe_runner.py --task-id rr-52 --no-headless --display-driver macos --audio-driver Dummy --timeout 900 --expect-size 1920x1080 --proof-contract experiments/cutouts/last_lamplighter/rr52/probes/production_contract.json experiments/cutouts/last_lamplighter/rr52/probes/production_capture.gd -- --type last_lamplighter $rear --output "$proof/production_native/$view"
  python3 -m humanoid_cutout.production_gates --case "$case_root" --capture "$proof/production_native/$view"
  python3 -B experiments/cutouts/last_lamplighter/rr52_production.py "$proof/production_native/$view"
 done
 ;;
review)
 python3 -m humanoid_cutout.proof review --case "$rig_case" --capture "$proof/native" --output "$proof/last_lamplighter_review.mp4" --diagnostic
 ;;
depth)
 python3 tools/godot_task_runner.py --task-id rr-52 --stream -- godot --headless --path . --script experiments/cutouts/last_lamplighter/rr52/probes/depth_probe.gd -- --list-only --output res://experiments/cutouts/last_lamplighter/rr52/probes/depth_inventory.json
 for board in fire_t1_r6 earth_t3_r7; do
  python3 tools/visual_probe_runner.py --task-id rr-52 --no-headless --display-driver macos --audio-driver Dummy --timeout 330 --min-images 0 --overwrite-result-manifest --result-manifest "$proof/logs/$board-depth-result.json" experiments/cutouts/last_lamplighter/rr52/probes/depth_probe.gd -- --board "$board" --actor last_lamplighter --output "$proof/native/depth/$board/last_lamplighter"
 done
 python3 experiments/cutouts/last_lamplighter/rr52/probes/verify_depth.py "$proof/native/depth" --inventory experiments/cutouts/last_lamplighter/rr52/probes/depth_inventory.json
 ;;
*) exit 2 ;;
esac
