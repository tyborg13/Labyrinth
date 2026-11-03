#!/bin/sh
# Director-only windowed commands. Worker validates headless and never retries GUI.
set -eu
stage="${1:?Use density, rest, native, sheets, idle, production or review}"
project="$(pwd)"
task_id="${LABYRINTH_TASK_ID:-rr-45}"
manifest_prefix="${RR37_RESULT_PREFIX:-$task_id}"
rig_case="${RR37_CASE:-$project/experiments/cutouts/frostglass_lancer/rr37}"
source_case="$rig_case"
rig_case="$source_case/proof/production_case"
proof="$source_case/proof"
refresh_samples() {
PYTHONPATH=tools python3 -B experiments/cutouts/frostglass_lancer/rr37_evidence.py --refresh --case "$source_case"
PYTHONPATH=tools python3 -B experiments/cutouts/frostglass_lancer/rr37_proof_case.py
PYTHONPATH=tools python3 -B experiments/cutouts/frostglass_lancer/rr37_evidence.py --refresh --case "$rig_case"
}
capture_native() {
python3 tools/visual_probe_runner.py --task-id "$task_id" --no-headless --display-driver macos --audio-driver Dummy --timeout 3600 --expect-size 1920x1080 --proof-contract tests/rr37/render_contract.json --result-manifest "$proof/logs/$manifest_prefix-native-result.json" --overwrite-result-manifest tests/rr37/native_capture.gd -- --case "$rig_case" --output "$proof/native"
}
check_native() {
rm -f "$proof/native_gates.json" "$rig_case/proof/native_gates.json" "$rig_case/proof/logs/native_gates.json"
status=0
python3 -B experiments/cutouts/frostglass_lancer/rr37_gates.py --case "$rig_case" --native "$proof/native" || status=$?
# Keep the director's established diagnostic paths, including failed runs.
if [ -f "$rig_case/proof/native_gates.json" ] && [ -f "$rig_case/proof/logs/native_gates.json" ]; then
    cp "$rig_case/proof/native_gates.json" "$proof/native_gates.json"
    cp "$rig_case/proof/logs/native_gates.json" "$proof/logs/native_gates.json"
fi
if [ -f "$rig_case/proof/logs/shaft_occlusion.json" ]; then
    cp "$rig_case/proof/logs/shaft_occlusion.json" "$proof/logs/shaft_occlusion.json"
fi
if [ -d "$rig_case/proof/logs/shaft_occlusion_crops" ]; then
    mkdir -p "$proof/logs/shaft_occlusion_crops"
    cp -R "$rig_case/proof/logs/shaft_occlusion_crops/." "$proof/logs/shaft_occlusion_crops/"
fi
return "$status"
}

case "$stage" in
density)
PYTHONPATH=tools python3 -B experiments/cutouts/frostglass_lancer/rr37_density.py --rebuild-derived-sources
python3 tools/visual_probe_runner.py --task-id "$task_id" --no-headless --display-driver macos --audio-driver Dummy --timeout 180 tests/rr37/density_rebake.gd -- --only frostglass_lancer_cutout
python3 tools/visual_probe_runner.py --task-id "$task_id" --no-headless --display-driver macos --audio-driver Dummy --timeout 120 --expect-size 1920x1080 --proof-contract tests/rr37/density_contract.json --result-manifest "$proof/logs/density-result.json" --overwrite-result-manifest tests/rr37/density_capture.gd -- --output "$proof/native_rest/production"
python3 tools/process_board_density.py --record-rests --only frostglass_lancer_cutout
python3 tools/godot_task_runner.py --task-id "$task_id" --stream -- godot --headless --path . --script tests/rr37/shadow_refresh.gd
python3 tools/process_board_density.py --check --only frostglass_lancer_cutout
python3 -B experiments/cutouts/frostglass_lancer/rr37_density.py seal
PYTHONPATH=tools python3 -B experiments/cutouts/frostglass_lancer/rr37_proof_case.py
;;
rest)
PYTHONPATH=tools python3 -B experiments/cutouts/frostglass_lancer/rr37_proof_case.py
python3 tools/visual_probe_runner.py --task-id "$task_id" --no-headless --display-driver macos --audio-driver Dummy --timeout 120 --expect-size 1920x1080 --proof-contract tests/rr37/rest_contract.json tests/rr37/native_capture.gd -- --case "$rig_case" --output "$proof/native_rest" --rest-only
;;
native)
refresh_samples
capture_native
check_native
PYTHONPATH=tools python3 -B experiments/cutouts/frostglass_lancer/rr37_native_checks.py --case "$rig_case" --native "$proof/native"
;;
sheets)
check_native
PYTHONPATH=tools python3 -B experiments/cutouts/frostglass_lancer/rr37_native_checks.py --case "$rig_case" --native "$proof/native"
PYTHONPATH=tools python3 -m humanoid_cutout.proof sheets --case "$rig_case" --capture "$proof/native" --output "$proof/contact_sheets"
;;
idle)
PYTHONPATH=tools python3 -B experiments/cutouts/frostglass_lancer/rr37_proof_case.py
python3 tools/visual_probe_runner.py --task-id "$task_id" --no-headless --display-driver macos --audio-driver Dummy --timeout 300 --expect-size 1920x1080 --proof-contract tests/rr37/idle_contract.json tests/rr37/native_capture.gd -- --case "$rig_case" --output "$proof/idle_native" --idle-comparison
PYTHONPATH=tools python3 -m humanoid_cutout.proof idle --case "$rig_case" --capture "$proof/idle_native" --output "$proof/frostglass_lancer_protagonist_idle.mp4"
;;
production)
python3 tools/visual_probe_runner.py --task-id "$task_id" --no-headless --display-driver macos --audio-driver Dummy --timeout 900 --expect-size 1920x1080 --proof-contract tests/rr37/production_contract.json tests/rr37/production_capture.gd -- --type frostglass_lancer --output "$proof/production_native/front"
python3 tools/visual_probe_runner.py --task-id "$task_id" --no-headless --display-driver macos --audio-driver Dummy --timeout 900 --expect-size 1920x1080 --proof-contract tests/rr37/production_contract.json tests/rr37/production_capture.gd -- --type frostglass_lancer --rear --output "$proof/production_native/rear"
python3 -B experiments/cutouts/frostglass_lancer/rr37_production.py --input "$proof/production_native/front/frames.json"
python3 -B experiments/cutouts/frostglass_lancer/rr37_production.py --input "$proof/production_native/rear/frames.json"
;;
review)
refresh_samples
if ! PYTHONPATH=tools python3 -B experiments/cutouts/frostglass_lancer/rr37_evidence.py --case "$rig_case" --native-current "$proof/native"; then
    # Changed proof contracts also invalidate provenance. Regenerate actual
    # captures; never relabel the old manifest or weaken the binding gate.
    if [ "${2:-}" = "--validate-only" ]; then exit 1; fi
    capture_native
fi
if [ "${2:-}" = "--validate-only" ]; then
    python3 -B experiments/cutouts/frostglass_lancer/rr37_gates.py --case "$rig_case"
    echo "RR37 REVIEW PREFLIGHT: PASS (headless evidence; native pixels and encoding not run)"
    exit 0
fi
check_native
PYTHONPATH=tools python3 -B experiments/cutouts/frostglass_lancer/rr37_native_checks.py --case "$rig_case" --native "$proof/native"
PYTHONPATH=tools python3 -m humanoid_cutout.proof review --case "$rig_case" --capture "$proof/native" --output "$proof/frostglass_lancer_review.mp4"
;;
*) exit 2 ;;
esac
