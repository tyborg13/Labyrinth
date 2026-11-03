#!/bin/sh
# Director-only real-renderer proof; no stage invokes windowed Godot directly.
set -eu
stage="${1:?Use density, rest, native, sheets, production, depth or fixture}"
case_root="$(pwd)/experiments/cutouts/storm_cantor/mq26"
rig_case="$case_root/proof/production_case"
proof="$case_root/proof"
probes=experiments/cutouts/storm_cantor/mq26/probes
export PYTHONPATH=tools
export LABYRINTH_CEL_LOOK=off
mkdir -p "$proof/logs"
refresh() {
 python3 "$case_root/density.py" --proof-case
 python3 tools/godot_task_runner.py --task-id rr-56 --stream -- godot --headless --path . --script "$probes/samples.gd" -- --case "$rig_case" --output "$rig_case/proof/samples.json"
 python3 tools/godot_task_runner.py --task-id rr-56 --stream -- godot --headless --path . --script "$probes/raster_samples.gd" -- --case "$rig_case" --geometry "$rig_case/proof/samples.json" --output "$rig_case/proof/raster_samples.json"
 if python3 "$case_root/cpu_sweep.py" --case "$rig_case" --samples "$rig_case/proof/raster_samples.json" --output "$rig_case/proof/cpu_sweep.json" --workers 4; then
  echo "RR56 CPU proof case passed"
 else
  echo "RR56 CPU proof case has findings; continuing to required native diagnosis"
 fi
}
case "$stage" in
density)
 python3 tools/visual_probe_runner.py --task-id rr-56 --no-headless --display-driver macos --audio-driver Dummy --timeout 180 "$probes/density_rebake.gd" -- --only storm_cantor_cutout
 python3 tools/visual_probe_runner.py --task-id rr-56 --no-headless --display-driver macos --audio-driver Dummy --timeout 120 --expect-size 1920x1080 --proof-contract "$probes/density_contract.json" "$probes/density_capture.gd" -- --output "$proof/native_rest/production"
 python3 tools/process_board_density.py --record-rests --only storm_cantor_cutout
 python3 tools/godot_task_runner.py --task-id rr-56 --stream -- godot --headless --path . --script "$probes/shadow_refresh.gd"
 python3 tools/process_board_density.py --check --only storm_cantor_cutout
 python3 "$case_root/density.py" --seal-native
 python3 "$case_root/seal.py"
 ;;
rest)
 refresh
 python3 tools/visual_probe_runner.py --task-id rr-56 --no-headless --display-driver macos --audio-driver Dummy --timeout 120 --expect-size 1920x1080 --proof-contract "$probes/rest_contract.json" "$probes/native_capture.gd" -- --case "$rig_case" --output "$proof/native_rest" --rest-only
 ;;
native)
 refresh
 python3 tools/visual_probe_runner.py --task-id rr-56 --no-headless --display-driver macos --audio-driver Dummy --timeout 3600 --expect-size 1920x1080 --proof-contract "$probes/render_contract.json" "$probes/native_capture.gd" -- --case "$rig_case" --output "$proof/native"
 python3 "$case_root/native.py" --case "$rig_case" --native "$proof/native"
 ;;
sheets)
 python3 "$case_root/sheets.py" --case "$rig_case" --capture "$proof/native" --output "$proof/contact_sheets"
 ;;
production)
 export LABYRINTH_CEL_LOOK=all
 python3 tools/cel_look.py build --if-stale
 for view in front rear; do
  if [ "$view" = rear ]; then rear=--rear; else rear=; fi
  python3 tools/visual_probe_runner.py --task-id rr-56 --no-headless --display-driver macos --audio-driver Dummy --timeout 900 --expect-size 1920x1080 --proof-contract "$probes/production_contract.json" "$probes/production_capture.gd" -- --type storm_cantor $rear --output "$proof/production_native/$view"
  python3 -m humanoid_cutout.production_gates --case "$case_root" --capture "$proof/production_native/$view"
 done
 ;;
depth)
 export LABYRINTH_CEL_LOOK=all
 python3 tools/cel_look.py build --if-stale
 python3 tools/godot_task_runner.py --task-id rr-56 --stream -- godot --headless --path . --script "$probes/depth_probe.gd" -- --list-only --output "res://$probes/depth_inventory.json"
 for board in fire_t1_r6 earth_t3_r7; do
  python3 tools/visual_probe_runner.py --task-id rr-56 --no-headless --display-driver macos --audio-driver Dummy --timeout 330 --min-images 0 --overwrite-result-manifest --result-manifest "$proof/logs/$board-depth-result.json" "$probes/depth_probe.gd" -- --board "$board" --actor storm_cantor --output "$proof/native/depth/$board/storm_cantor"
 done
 python3 "$probes/verify_depth.py" "$proof/native/depth" --inventory "$probes/depth_inventory.json"
 ;;
fixture)
 export LABYRINTH_CEL_LOOK=all
 python3 tools/cel_look.py build --if-stale
 python3 tools/inspection_fixture.py --task-id rr-56 --run-id rr-56-inspection --scenario guardian --guardian-id storm_cantor --guardian-case beat --seed 7262026 --manifest /private/tmp/labyrinth-inspection-manifests/rr-56.json --summary 'Storm Cantor mq26 v2: real Lightning Storm fight' --launch
 ;;
*) exit 2 ;;
esac
