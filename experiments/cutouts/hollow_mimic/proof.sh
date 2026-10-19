#!/bin/sh
# Director-only windowed sequence, 1920x1080 / 100% UI scale.
set -eu
stage="${1:?Use density, rest, native, sheets, idle, production or review}"
project="$(pwd)"
rig_case="$project/experiments/cutouts/hollow_mimic/rr20"
proof="$rig_case/proof"
case "$stage" in
density)
python3 tools/process_board_density.py --only hollow_mimic_cutout
python3 tools/visual_probe_runner.py --task-id rr-20 --no-headless --display-driver macos --audio-driver Dummy --timeout 180 tests/rr20/density_rebake.gd -- --only hollow_mimic_cutout
python3 tools/process_board_density.py --record-rests --only hollow_mimic_cutout
python3 tools/godot_task_runner.py --task-id rr-20 --stream -- godot --headless --path . --script tests/rr20/shadow_refresh.gd
python3 tools/process_board_density.py --check --only hollow_mimic_cutout
python3 -B experiments/cutouts/hollow_mimic/density.py seal
;;
rest)
python3 tools/visual_probe_runner.py --task-id rr-20 --no-headless --display-driver macos --audio-driver Dummy --timeout 120 --expect-size 1920x1080 --proof-contract tests/rr20/rest_contract.json tests/rr20/native_capture.gd -- --case "$rig_case" --output "$proof/native_rest" --rest-only
;;
native)
python3 tools/godot_task_runner.py --task-id rr-20 --stream -- godot --headless --path . --script tests/rr20/samples.gd -- --case "$rig_case" --output "$proof/samples.json"
python3 tools/visual_probe_runner.py --task-id rr-20 --no-headless --display-driver macos --audio-driver Dummy --timeout 3600 --expect-size 1920x1080 --proof-contract tests/rr20/render_contract.json tests/rr20/native_capture.gd -- --case "$rig_case" --output "$proof/native"
python3 -B experiments/cutouts/hollow_mimic/gates.py --native "$proof/native"
;;
idle)
python3 tools/visual_probe_runner.py --task-id rr-20 --no-headless --display-driver macos --audio-driver Dummy --timeout 300 --expect-size 1920x1080 --proof-contract tests/rr20/idle_contract.json tests/rr20/native_capture.gd -- --case "$rig_case" --output "$proof/idle_native" --idle-comparison
PYTHONPATH=tools python3 -m humanoid_cutout.proof idle --case "$rig_case" --capture "$proof/idle_native" --output "$proof/hollow_mimic_protagonist_idle.mp4"
;;
production)
for view in front rear; do
    for card in whirlwind_slash quick_stab hurl_spear; do
        capture="$proof/production_native/$view/$card"
        python3 tools/visual_probe_runner.py --task-id rr-20 --no-headless --display-driver macos --audio-driver Dummy --timeout 900 --expect-size 1920x1080 --proof-contract tests/rr20/production_contract.json tests/rr20/production_capture.gd -- --type hollow_mimic --view "$view" --mirror-card "$card" --output "$capture"
        python3 -B experiments/cutouts/hollow_mimic/production.py --input "$capture/frames.json"
    done
done
;;
sheets|review)
python3 -B experiments/cutouts/hollow_mimic/gates.py --native "$proof/native"
if [ "$stage" = sheets ]; then
    PYTHONPATH=tools python3 -m humanoid_cutout.proof sheets --case "$rig_case" --capture "$proof/native" --output "$proof/contact_sheets"
else
    PYTHONPATH=tools python3 -m humanoid_cutout.proof review --case "$rig_case" --capture "$proof/native" --output "$proof/hollow_mimic_review.mp4"
fi
;;
*) exit 2 ;;
esac
