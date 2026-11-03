#!/bin/sh
# Director-only windowed commands. Worker validates headless and never retries GUI.
set -eu
stage="${1:?Use density, rest, native, sheets, idle, production or review}"
project="$(pwd)"
task_id="${LABYRINTH_TASK_ID:-rr-32}"
rig_case="${RR32_CASE:-$project/experiments/cutouts/gale_herald/mq12}"
proof="$rig_case/proof"
refresh_samples() {
PYTHONPATH=tools python3 -B experiments/cutouts/gale_herald/rr32_evidence.py --refresh --case "$rig_case"
}
capture_native() {
python3 tools/visual_probe_runner.py --task-id "$task_id" --no-headless --display-driver macos --audio-driver Dummy --timeout 3600 --expect-size 1920x1080 --proof-contract tests/rr32/render_contract.json tests/rr32/native_capture.gd -- --case "$rig_case" --output "$proof/native"
}
case "$stage" in
density)
python3 tools/visual_probe_runner.py --task-id "$task_id" --no-headless --display-driver macos --audio-driver Dummy --timeout 180 tests/rr32/density_rebake.gd -- --only gale_herald_cutout
python3 tools/process_board_density.py --record-rests --only gale_herald_cutout
python3 tools/godot_task_runner.py --task-id "$task_id" --stream -- godot --headless --path . --script tests/rr32/shadow_refresh.gd
python3 tools/process_board_density.py --check --only gale_herald_cutout
python3 -B experiments/cutouts/gale_herald/rr32_density.py seal
;;
rest)
python3 tools/visual_probe_runner.py --task-id "$task_id" --no-headless --display-driver macos --audio-driver Dummy --timeout 120 --expect-size 1920x1080 --proof-contract tests/rr32/rest_contract.json tests/rr32/native_capture.gd -- --case "$rig_case" --output "$proof/native_rest" --rest-only
;;
native)
refresh_samples
capture_native
python3 -B experiments/cutouts/gale_herald/rr32_gates.py --case "$rig_case" --native "$proof/native"
;;
sheets)
gate_status=0
python3 -B experiments/cutouts/gale_herald/rr32_gates.py --native "$proof/native" || gate_status=$?
PYTHONPATH=tools python3 -m humanoid_cutout.proof sheets --case "$rig_case" --capture "$proof/native" --output "$proof/contact_sheets"
exit "$gate_status"
;;
idle)
for view in front rear; do
    rear=""
    if [ "$view" = rear ]; then rear="--rear"; fi
    python3 tools/visual_probe_runner.py --task-id "$task_id" --no-headless --display-driver macos --audio-driver Dummy --timeout 300 --expect-size 1920x1080 --proof-contract tests/rr32/idle_contract.json tests/rr32/native_capture.gd -- --case "$rig_case" --output "$proof/idle_native/$view" --idle-comparison $rear
    PYTHONPATH=tools python3 -m humanoid_cutout.proof idle --case "$rig_case" --capture "$proof/idle_native/$view" --output "$proof/gale_herald_protagonist_idle_$view.mp4"
done
;;
production)
python3 tools/visual_probe_runner.py --task-id "$task_id" --no-headless --display-driver macos --audio-driver Dummy --timeout 900 --expect-size 1920x1080 --proof-contract tests/rr32/production_contract.json tests/rr32/production_capture.gd -- --type gale_herald --output "$proof/production_native/front"
python3 tools/visual_probe_runner.py --task-id "$task_id" --no-headless --display-driver macos --audio-driver Dummy --timeout 900 --expect-size 1920x1080 --proof-contract tests/rr32/production_contract.json tests/rr32/production_capture.gd -- --type gale_herald --rear --output "$proof/production_native/rear"
python3 -B experiments/cutouts/gale_herald/rr32_production.py --input "$proof/production_native/front/frames.json"
python3 -B experiments/cutouts/gale_herald/rr32_production.py --input "$proof/production_native/rear/frames.json"
;;
review)
refresh_samples
if ! PYTHONPATH=tools python3 -B experiments/cutouts/gale_herald/rr32_evidence.py --case "$rig_case" --native-current "$proof/native"; then
    # Changed proof contracts also invalidate provenance. Regenerate actual
    # captures; never relabel the old manifest or weaken the binding gate.
    if [ "${2:-}" = "--validate-only" ]; then exit 1; fi
    capture_native
fi
if [ "${2:-}" = "--validate-only" ]; then
    python3 -B experiments/cutouts/gale_herald/rr32_gates.py --case "$rig_case"
    echo "RR32 REVIEW PREFLIGHT: PASS (headless evidence; native pixels and encoding not run)"
    exit 0
fi
gate_status=0
python3 -B experiments/cutouts/gale_herald/rr32_gates.py --case "$rig_case" --native "$proof/native" || gate_status=$?
PYTHONPATH=tools python3 -m humanoid_cutout.proof review --case "$rig_case" --capture "$proof/native" --output "$proof/gale_herald_review.mp4"
exit "$gate_status"
;;
*) exit 2 ;;
esac
