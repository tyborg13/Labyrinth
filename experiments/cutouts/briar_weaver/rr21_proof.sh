#!/bin/sh
# Director-only windowed commands. Worker validates headless and never retries GUI.
set -eu
stage="${1:?Use density, rest, native, sheets, idle, production or review}"
project="$(pwd)"
task_id="${LABYRINTH_TASK_ID:-rr-21}"
rig_case="${RR21_CASE:-$project/experiments/cutouts/briar_weaver/mq9}"
proof="$rig_case/proof"
refresh_samples() {
PYTHONPATH=tools python3 -B experiments/cutouts/briar_weaver/rr21_evidence.py --refresh --case "$rig_case"
}
capture_native() {
python3 tools/visual_probe_runner.py --task-id "$task_id" --no-headless --display-driver macos --audio-driver Dummy --timeout 3600 --expect-size 1920x1080 --proof-contract tests/rr21/render_contract.json tests/rr21/native_capture.gd -- --case "$rig_case" --output "$proof/native"
}
case "$stage" in
density)
python3 tools/visual_probe_runner.py --task-id "$task_id" --no-headless --display-driver macos --audio-driver Dummy --timeout 180 tests/rr21/density_rebake.gd -- --only briar_weaver_cutout
python3 tools/process_board_density.py --record-rests --only briar_weaver_cutout
python3 tools/godot_task_runner.py --task-id "$task_id" --stream -- godot --headless --path . --script tests/rr21/shadow_refresh.gd
python3 tools/process_board_density.py --check --only briar_weaver_cutout
python3 -B experiments/cutouts/briar_weaver/rr21_density.py seal
;;
rest)
python3 tools/visual_probe_runner.py --task-id "$task_id" --no-headless --display-driver macos --audio-driver Dummy --timeout 120 --expect-size 1920x1080 --proof-contract tests/rr21/rest_contract.json tests/rr21/native_capture.gd -- --case "$rig_case" --output "$proof/native_rest" --rest-only
;;
native)
refresh_samples
capture_native
python3 -B experiments/cutouts/briar_weaver/rr21_gates.py --case "$rig_case" --native "$proof/native"
;;
sheets)
python3 -B experiments/cutouts/briar_weaver/rr21_gates.py --native "$proof/native"
PYTHONPATH=tools python3 -m humanoid_cutout.proof sheets --case "$rig_case" --capture "$proof/native" --output "$proof/contact_sheets"
;;
idle)
python3 tools/visual_probe_runner.py --task-id "$task_id" --no-headless --display-driver macos --audio-driver Dummy --timeout 300 --expect-size 1920x1080 --proof-contract tests/rr21/idle_contract.json tests/rr21/native_capture.gd -- --case "$rig_case" --output "$proof/idle_native" --idle-comparison
PYTHONPATH=tools python3 -m humanoid_cutout.proof idle --case "$rig_case" --capture "$proof/idle_native" --output "$proof/briar_weaver_protagonist_idle.mp4"
;;
production)
python3 tools/visual_probe_runner.py --task-id "$task_id" --no-headless --display-driver macos --audio-driver Dummy --timeout 900 --expect-size 1920x1080 --proof-contract tests/rr21/production_contract.json tests/rr21/production_capture.gd -- --type briar_weaver --output "$proof/production_native/front"
python3 tools/visual_probe_runner.py --task-id "$task_id" --no-headless --display-driver macos --audio-driver Dummy --timeout 900 --expect-size 1920x1080 --proof-contract tests/rr21/production_contract.json tests/rr21/production_capture.gd -- --type briar_weaver --rear --output "$proof/production_native/rear"
python3 -B experiments/cutouts/briar_weaver/rr21_production.py --input "$proof/production_native/front/frames.json"
python3 -B experiments/cutouts/briar_weaver/rr21_production.py --input "$proof/production_native/rear/frames.json"
;;
review)
refresh_samples
if ! PYTHONPATH=tools python3 -B experiments/cutouts/briar_weaver/rr21_evidence.py --case "$rig_case" --native-current "$proof/native"; then
    # Changed proof contracts also invalidate provenance. Regenerate actual
    # captures; never relabel the old manifest or weaken the binding gate.
    if [ "${2:-}" = "--validate-only" ]; then exit 1; fi
    capture_native
fi
if [ "${2:-}" = "--validate-only" ]; then
    python3 -B experiments/cutouts/briar_weaver/rr21_gates.py --case "$rig_case"
    echo "RR21 REVIEW PREFLIGHT: PASS (headless evidence; native pixels and encoding not run)"
    exit 0
fi
python3 -B experiments/cutouts/briar_weaver/rr21_gates.py --case "$rig_case" --native "$proof/native"
PYTHONPATH=tools python3 -m humanoid_cutout.proof review --case "$rig_case" --capture "$proof/native" --output "$proof/briar_weaver_review.mp4"
;;
*) exit 2 ;;
esac
