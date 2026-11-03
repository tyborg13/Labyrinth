#!/bin/sh
# Director-only windowed commands. Worker validates headless and never retries GUI.
set -eu
stage="${1:?Use density, rest, native, sheets, idle, production or review}"
project="$(pwd)"
task_id="${LABYRINTH_TASK_ID:-rr-42}"
rig_case="${RR42_CASE:-$project/experiments/cutouts/chainbound_gaoler/rr42}"
source_case="$rig_case"
rig_case="$source_case/proof/production_case"
proof="$source_case/proof"
# Preserve the director's round-2 calibration captures and full error log.
native_capture="${RR42_NATIVE_DIR:-$proof/native}"
current_gate_log="$proof/logs/rr42/native_current_gates.json"
# Captures/reports are output-only; keep tens of thousands of PNGs out of
# subsequent Godot imports. Python/ffmpeg still read every file directly.
mkdir -p "$proof/logs" "$native_capture"
printf '%s\n' '# Generated reports; no Godot ResourceLoader inputs.' > "$proof/logs/.gdignore"
printf '%s\n' '# Generated captures; Python/ffmpeg inputs only.' > "$native_capture/.gdignore"
refresh_samples() {
PYTHONPATH=tools python3 -B experiments/cutouts/chainbound_gaoler/rr38_evidence.py --refresh --case "$source_case"
PYTHONPATH=tools python3 -B experiments/cutouts/chainbound_gaoler/rr42_proof_case.py
PYTHONPATH=tools python3 -B experiments/cutouts/chainbound_gaoler/rr42_sampling.py --case "$rig_case"
}
capture_native() {
python3 tools/visual_probe_runner.py --task-id "$task_id" --no-headless --display-driver macos --audio-driver Dummy --timeout 3600 --expect-size 1920x1080 --proof-contract tests/rr38/render_contract.json tests/rr38/native_capture.gd -- --case "$rig_case" --output "$native_capture"
}
check_native() {
rm -f "$rig_case/proof/native_gates.json" "$rig_case/proof/logs/native_gates.json"
status=0
python3 -B experiments/cutouts/chainbound_gaoler/rr42_runtime_gates.py --case "$rig_case" --native "$native_capture" || status=$?
# Keep round-3 diagnostics on failure; preserve the original round-2 log.
if [ -f "$rig_case/proof/native_gates.json" ] && [ -f "$rig_case/proof/logs/native_gates.json" ]; then
    cp "$rig_case/proof/native_gates.json" "$proof/rr42_native_gates.json"
    mkdir -p "$(dirname "$current_gate_log")"
    cp "$rig_case/proof/logs/native_gates.json" "$current_gate_log"
fi
return "$status"
}

case "$stage" in
density)
PYTHONPATH=tools python3 -B experiments/cutouts/chainbound_gaoler/rr42_density.py
python3 tools/visual_probe_runner.py --task-id "$task_id" --no-headless --display-driver macos --audio-driver Dummy --timeout 180 tests/rr38/density_rebake.gd -- --only chainbound_gaoler_cutout
python3 tools/visual_probe_runner.py --task-id "$task_id" --no-headless --display-driver macos --audio-driver Dummy --timeout 120 --expect-size 1920x1080 --proof-contract tests/rr38/density_contract.json --result-manifest "$proof/logs/density-result.json" --overwrite-result-manifest tests/rr38/density_capture.gd -- --output "$proof/native_rest/production"
python3 tools/process_board_density.py --record-rests --only chainbound_gaoler_cutout
python3 tools/godot_task_runner.py --task-id "$task_id" --stream -- godot --headless --path . --script tests/rr38/shadow_refresh.gd
python3 tools/process_board_density.py --check --only chainbound_gaoler_cutout
python3 -B experiments/cutouts/chainbound_gaoler/rr42_density.py --seal-native
PYTHONPATH=tools python3 -B experiments/cutouts/chainbound_gaoler/rr42_proof_case.py
;;
rest)
PYTHONPATH=tools python3 -B experiments/cutouts/chainbound_gaoler/rr42_proof_case.py
python3 tools/visual_probe_runner.py --task-id "$task_id" --no-headless --display-driver macos --audio-driver Dummy --timeout 120 --expect-size 1920x1080 --proof-contract tests/rr38/rest_contract.json tests/rr38/native_capture.gd -- --case "$rig_case" --output "$proof/native_rest" --rest-only
;;
native)
refresh_samples
capture_native
status=0
python3 -B experiments/cutouts/chainbound_gaoler/rr42_sweep.py --case "$rig_case" --exposure || status=$?
check_native || status=$?
exit "$status"
;;
sheets)
# Failed gates still need viewable evidence for the director. Preserve the failure exit.
status=0
check_native || status=$?
PYTHONPATH=tools python3 -B experiments/cutouts/chainbound_gaoler/rr42_compose.py sheets --case "$rig_case" --capture "$native_capture" --output "$proof/contact_sheets" --diagnostic || status=$?
exit "$status"
;;
idle)
PYTHONPATH=tools python3 -B experiments/cutouts/chainbound_gaoler/rr42_proof_case.py
python3 tools/visual_probe_runner.py --task-id "$task_id" --no-headless --display-driver macos --audio-driver Dummy --timeout 300 --expect-size 1920x1080 --proof-contract tests/rr38/idle_contract.json tests/rr38/native_capture.gd -- --case "$rig_case" --output "$proof/idle_native" --idle-comparison
PYTHONPATH=tools python3 -m humanoid_cutout.proof idle --case "$rig_case" --capture "$proof/idle_native" --output "$proof/chainbound_gaoler_protagonist_idle.mp4"
;;
production)
python3 tools/visual_probe_runner.py --task-id "$task_id" --no-headless --display-driver macos --audio-driver Dummy --timeout 900 --expect-size 1920x1080 --proof-contract tests/rr38/production_contract.json tests/rr38/production_capture.gd -- --type chainbound_gaoler --output "$proof/production_native/front"
python3 tools/visual_probe_runner.py --task-id "$task_id" --no-headless --display-driver macos --audio-driver Dummy --timeout 900 --expect-size 1920x1080 --proof-contract tests/rr38/production_contract.json tests/rr38/production_capture.gd -- --type chainbound_gaoler --rear --output "$proof/production_native/rear"
python3 tools/visual_probe_runner.py --task-id "$task_id" --no-headless --display-driver macos --audio-driver Dummy --timeout 180 --expect-size 1920x1080 --proof-contract experiments/cutouts/chainbound_gaoler/rr38_geometry_contract.json --result-manifest "$proof/logs/sprite-geometry-result.json" --overwrite-result-manifest tests/prepared_unit_canvas_equivalence_test.gd
python3 -B experiments/cutouts/chainbound_gaoler/rr38_production.py --input "$proof/production_native/front/frames.json"
python3 -B experiments/cutouts/chainbound_gaoler/rr38_production.py --input "$proof/production_native/rear/frames.json"
;;
review)
refresh_samples
if ! PYTHONPATH=tools python3 -B experiments/cutouts/chainbound_gaoler/rr42_compose.py current --case "$rig_case" --capture "$native_capture"; then
    # Changed proof contracts also invalidate provenance. Regenerate actual
    # captures; never relabel the old manifest or weaken the binding gate.
    if [ "${2:-}" = "--validate-only" ]; then exit 1; fi
    capture_native
fi
if [ "${2:-}" = "--validate-only" ]; then
    python3 -B experiments/cutouts/chainbound_gaoler/rr42_runtime_gates.py --case "$rig_case"
    echo "RR42 REVIEW PREFLIGHT: PASS (headless evidence; native pixels and encoding not run)"
    exit 0
fi
status=0
check_native || status=$?
PYTHONPATH=tools python3 -B experiments/cutouts/chainbound_gaoler/rr42_compose.py review --case "$rig_case" --capture "$native_capture" --output "$proof/chainbound_gaoler_review.mp4" --diagnostic || status=$?
exit "$status"
;;
*) exit 2 ;;
esac
