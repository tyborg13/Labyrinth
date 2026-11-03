#!/bin/sh
# Director-only windowed commands. Worker validates headless and never retries GUI.
set -eu
stage="${1:?Use density, rest, native, sheets, idle, production or review}"
project="$(pwd)"
task_id="${LABYRINTH_TASK_ID:-rr-36}"
rig_case="${RR35_CASE:-$project/experiments/cutouts/gloam_stalker/rr35}"
proof="$rig_case/proof"
refresh_samples() {
PYTHONPATH=tools python3 -B experiments/cutouts/gloam_stalker/rr35_evidence.py --refresh --case "$rig_case"
}
capture_native() {
python3 tools/visual_probe_runner.py --task-id "$task_id" --no-headless --display-driver macos --audio-driver Dummy --timeout 3600 --expect-size 1920x1080 --proof-contract tests/rr35/render_contract.json tests/rr35/native_capture.gd -- --case "$rig_case" --output "$proof/native"
}
case "$stage" in
density)
PYTHONPATH=tools python3 -B experiments/cutouts/gloam_stalker/rr36_repair.py --stage-density
PYTHONPATH=tools python3 -B experiments/cutouts/gloam_stalker/rr35_density.py --rebuild-derived-sources
python3 tools/visual_probe_runner.py --task-id "$task_id" --no-headless --display-driver macos --audio-driver Dummy --timeout 180 tests/rr35/density_rebake.gd -- --only gloam_stalker_cutout
python3 tools/visual_probe_runner.py --task-id "$task_id" --no-headless --display-driver macos --audio-driver Dummy --timeout 120 --expect-size 1920x1080 --proof-contract tests/rr35/density_contract.json --result-manifest "$proof/logs/density-result.json" tests/rr35/density_capture.gd -- --output "$proof/native_rest/production"
python3 tools/process_board_density.py --record-rests --only gloam_stalker_cutout
python3 tools/godot_task_runner.py --task-id "$task_id" --stream -- godot --headless --path . --script tests/rr35/shadow_refresh.gd
python3 tools/process_board_density.py --check --only gloam_stalker_cutout
python3 -B experiments/cutouts/gloam_stalker/rr35_density.py seal
;;
rest)
python3 tools/visual_probe_runner.py --task-id "$task_id" --no-headless --display-driver macos --audio-driver Dummy --timeout 120 --expect-size 1920x1080 --proof-contract tests/rr35/rest_contract.json tests/rr35/native_capture.gd -- --case "$rig_case" --output "$proof/native_rest" --rest-only
;;
native)
refresh_samples
capture_native
python3 -B experiments/cutouts/gloam_stalker/rr35_gates.py --case "$rig_case" --native "$proof/native"
PYTHONPATH=tools python3 -B experiments/cutouts/gloam_stalker/rr36_native_checks.py --native "$proof/native"
;;
sheets)
python3 -B experiments/cutouts/gloam_stalker/rr35_gates.py --native "$proof/native"
PYTHONPATH=tools python3 -B experiments/cutouts/gloam_stalker/rr36_native_checks.py --native "$proof/native"
PYTHONPATH=tools python3 -m humanoid_cutout.proof sheets --case "$rig_case" --capture "$proof/native" --output "$proof/contact_sheets"
;;
idle)
python3 tools/visual_probe_runner.py --task-id "$task_id" --no-headless --display-driver macos --audio-driver Dummy --timeout 300 --expect-size 1920x1080 --proof-contract tests/rr35/idle_contract.json tests/rr35/native_capture.gd -- --case "$rig_case" --output "$proof/idle_native" --idle-comparison
PYTHONPATH=tools python3 -m humanoid_cutout.proof idle --case "$rig_case" --capture "$proof/idle_native" --output "$proof/gloam_stalker_protagonist_idle.mp4"
;;
production)
python3 tools/visual_probe_runner.py --task-id "$task_id" --no-headless --display-driver macos --audio-driver Dummy --timeout 900 --expect-size 1920x1080 --proof-contract tests/rr35/production_contract.json tests/rr35/production_capture.gd -- --type gloam_stalker --output "$proof/production_native/front"
python3 tools/visual_probe_runner.py --task-id "$task_id" --no-headless --display-driver macos --audio-driver Dummy --timeout 900 --expect-size 1920x1080 --proof-contract tests/rr35/production_contract.json tests/rr35/production_capture.gd -- --type gloam_stalker --rear --output "$proof/production_native/rear"
python3 -B experiments/cutouts/gloam_stalker/rr35_production.py --input "$proof/production_native/front/frames.json"
python3 -B experiments/cutouts/gloam_stalker/rr35_production.py --input "$proof/production_native/rear/frames.json"
;;
review)
refresh_samples
if ! PYTHONPATH=tools python3 -B experiments/cutouts/gloam_stalker/rr35_evidence.py --case "$rig_case" --native-current "$proof/native"; then
    # Changed proof contracts also invalidate provenance. Regenerate actual
    # captures; never relabel the old manifest or weaken the binding gate.
    if [ "${2:-}" = "--validate-only" ]; then exit 1; fi
    capture_native
fi
if [ "${2:-}" = "--validate-only" ]; then
    python3 -B experiments/cutouts/gloam_stalker/rr35_gates.py --case "$rig_case"
    echo "RR35 REVIEW PREFLIGHT: PASS (headless evidence; native pixels and encoding not run)"
    exit 0
fi
python3 -B experiments/cutouts/gloam_stalker/rr35_gates.py --case "$rig_case" --native "$proof/native"
PYTHONPATH=tools python3 -B experiments/cutouts/gloam_stalker/rr36_native_checks.py --native "$proof/native"
PYTHONPATH=tools python3 -m humanoid_cutout.proof review --case "$rig_case" --capture "$proof/native" --output "$proof/gloam_stalker_review.mp4"
;;
*) exit 2 ;;
esac
