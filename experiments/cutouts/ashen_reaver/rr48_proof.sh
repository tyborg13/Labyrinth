#!/bin/sh
# Director-only real-renderer proof at 1920x1080, 100% UI scale.
set -eu
stage="${1:?Use density, rest, native, seams, sheets, idle, production, review or depth}"
case_root="$(pwd)/experiments/cutouts/ashen_reaver/rr48"
rig_case="$case_root/proof/production_case"
proof="$case_root/proof"
export PYTHONPATH=tools
# Rest identity, density and rig proofs read source art; only the in-game stages use the cel look.
export LABYRINTH_CEL_LOOK=off
mkdir -p "$proof/logs"
refresh() {
 python3 -B experiments/cutouts/ashen_reaver/rr48_density.py --proof-case
 python3 tools/godot_task_runner.py --task-id rr-53 --stream -- godot --headless --path . --script tests/rr48/samples.gd -- --case "$rig_case" --output "$rig_case/proof/samples.json"
 python3 tools/godot_task_runner.py --task-id rr-53 --stream -- godot --headless --path . --script tests/rr48/raster_samples.gd -- --case "$rig_case" --geometry "$rig_case/proof/samples.json" --output "$rig_case/proof/raster_samples.json"
}
case "$stage" in
density)
 python3 tools/visual_probe_runner.py --task-id rr-53 --no-headless --display-driver macos --audio-driver Dummy --timeout 180 tests/rr48/density_rebake.gd -- --only ashen_reaver_cutout
 python3 tools/visual_probe_runner.py --task-id rr-53 --no-headless --display-driver macos --audio-driver Dummy --timeout 120 --expect-size 1920x1080 --proof-contract tests/rr48/density_contract.json tests/rr48/density_capture.gd -- --output "$proof/native_rest/production"
 python3 tools/process_board_density.py --record-rests --only ashen_reaver_cutout
 python3 tools/godot_task_runner.py --task-id rr-53 --stream -- godot --headless --path . --script tests/rr48/shadow_refresh.gd
 python3 tools/process_board_density.py --check --only ashen_reaver_cutout
 python3 -B experiments/cutouts/ashen_reaver/rr48_density.py --seal-native
 ;;
rest)
 refresh
 python3 tools/visual_probe_runner.py --task-id rr-53 --no-headless --display-driver macos --audio-driver Dummy --timeout 120 --expect-size 1920x1080 --proof-contract tests/rr48/rest_contract.json tests/rr48/native_capture.gd -- --case "$rig_case" --output "$proof/native_rest" --rest-only
 ;;
native)
 refresh
 python3 tools/visual_probe_runner.py --task-id rr-53 --no-headless --display-driver macos --audio-driver Dummy --timeout 3600 --expect-size 1920x1080 --proof-contract tests/rr48/render_contract.json tests/rr48/native_capture.gd -- --case "$rig_case" --output "$proof/native"
 python3 experiments/cutouts/ashen_reaver/rr48_native.py --case "$rig_case" --native "$proof/native"
 ;;
seams)
 python3 experiments/cutouts/ashen_reaver/rr48_native.py --case "$rig_case" --native "$proof/native"
 ;;
sheets)
 python3 -m humanoid_cutout.proof sheets --case "$rig_case" --capture "$proof/native" --output "$proof/contact_sheets" --diagnostic
 ;;
idle)
 refresh
 python3 tools/visual_probe_runner.py --task-id rr-53 --no-headless --display-driver macos --audio-driver Dummy --timeout 300 --expect-size 1920x1080 --proof-contract tests/rr48/idle_contract.json tests/rr48/native_capture.gd -- --case "$rig_case" --output "$proof/idle_native" --idle-comparison
 python3 -m humanoid_cutout.proof idle --case "$rig_case" --capture "$proof/idle_native" --output "$proof/ashen_reaver_protagonist_idle.mp4"
 ;;
production)
 export LABYRINTH_CEL_LOOK=all
 for view in front rear; do
  if [ "$view" = rear ]; then rear=--rear; else rear=; fi
  python3 tools/visual_probe_runner.py --task-id rr-53 --no-headless --display-driver macos --audio-driver Dummy --timeout 900 --expect-size 1920x1080 --proof-contract tests/rr48/production_contract.json tests/rr48/production_capture.gd -- --type ashen_reaver $rear --output "$proof/production_native/$view"
  python3 -m humanoid_cutout.production_gates --case "$case_root" --capture "$proof/production_native/$view"
 done
 ;;
review)
 python3 -m humanoid_cutout.proof review --case "$rig_case" --capture "$proof/native" --output "$proof/ashen_reaver_review.mp4" --diagnostic
 ;;
depth)
 export LABYRINTH_CEL_LOOK=all
 python3 tools/godot_task_runner.py --task-id rr-53 --stream -- godot --headless --path . --script tests/rr48/depth_probe.gd -- --list-only --output res://tests/rr48/depth_inventory.json
 for board in fire_t1_r6 earth_t3_r7; do
  python3 tools/visual_probe_runner.py --task-id rr-53 --no-headless --display-driver macos --audio-driver Dummy --timeout 330 --min-images 0 --overwrite-result-manifest --result-manifest "$proof/logs/$board-depth-result.json" tests/rr48/depth_probe.gd -- --board "$board" --actor ashen_reaver --output "$proof/native/depth/$board/ashen_reaver"
 done
 python3 tests/rr48/verify_depth.py "$proof/native/depth" --inventory tests/rr48/depth_inventory.json
 ;;
*) exit 2 ;;
esac
