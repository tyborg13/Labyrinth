#!/bin/sh
# Director-only windowed commands. Worker validates headless and never retries GUI.
set -eu
stage="${1:?Use density, rest, native, sheets, idle, production or review}"
project="$(pwd)"
rig_case="$project/experiments/cutouts/briar_weaver/mq9"
proof="$rig_case/proof"
case "$stage" in
density)
python3 tools/visual_probe_runner.py --task-id rr-21 --no-headless --display-driver macos --audio-driver Dummy --timeout 180 tests/rr21/density_rebake.gd -- --only briar_weaver_cutout
python3 tools/process_board_density.py --record-rests --only briar_weaver_cutout
python3 tools/godot_task_runner.py --task-id rr-21 --stream -- godot --headless --path . --script tests/rr21/shadow_refresh.gd
python3 tools/process_board_density.py --check --only briar_weaver_cutout
python3 -B experiments/cutouts/briar_weaver/rr21_density.py seal
;;
rest)
python3 tools/visual_probe_runner.py --task-id rr-21 --no-headless --display-driver macos --audio-driver Dummy --timeout 120 --expect-size 1920x1080 --proof-contract tests/rr21/rest_contract.json tests/rr21/native_capture.gd -- --case "$rig_case" --output "$proof/native_rest" --rest-only
;;
native)
python3 tools/godot_task_runner.py --task-id rr-21 --stream -- godot --headless --path . --script tests/rr21/samples.gd -- --case "$rig_case" --output "$proof/logs/samples.json"
PYTHONPATH=tools python3 -B experiments/cutouts/briar_weaver/rr21_evidence.py
python3 tools/visual_probe_runner.py --task-id rr-21 --no-headless --display-driver macos --audio-driver Dummy --timeout 3600 --expect-size 1920x1080 --proof-contract tests/rr21/render_contract.json tests/rr21/native_capture.gd -- --case "$rig_case" --output "$proof/native"
python3 -B experiments/cutouts/briar_weaver/rr21_gates.py --native "$proof/native"
;;
sheets)
python3 -B experiments/cutouts/briar_weaver/rr21_gates.py --native "$proof/native"
PYTHONPATH=tools python3 -m humanoid_cutout.proof sheets --case "$rig_case" --capture "$proof/native" --output "$proof/contact_sheets"
;;
idle)
python3 tools/visual_probe_runner.py --task-id rr-21 --no-headless --display-driver macos --audio-driver Dummy --timeout 300 --expect-size 1920x1080 --proof-contract tests/rr21/idle_contract.json tests/rr21/native_capture.gd -- --case "$rig_case" --output "$proof/idle_native" --idle-comparison
PYTHONPATH=tools python3 -m humanoid_cutout.proof idle --case "$rig_case" --capture "$proof/idle_native" --output "$proof/briar_weaver_protagonist_idle.mp4"
;;
production)
python3 tools/visual_probe_runner.py --task-id rr-21 --no-headless --display-driver macos --audio-driver Dummy --timeout 900 --expect-size 1920x1080 --proof-contract tests/rr21/production_contract.json tests/rr21/production_capture.gd -- --type briar_weaver --output "$proof/production_native/front"
python3 tools/visual_probe_runner.py --task-id rr-21 --no-headless --display-driver macos --audio-driver Dummy --timeout 900 --expect-size 1920x1080 --proof-contract tests/rr21/production_contract.json tests/rr21/production_capture.gd -- --type briar_weaver --rear --output "$proof/production_native/rear"
python3 -B experiments/cutouts/briar_weaver/rr21_production.py --input "$proof/production_native/front/frames.json"
python3 -B experiments/cutouts/briar_weaver/rr21_production.py --input "$proof/production_native/rear/frames.json"
;;
review)
python3 -B experiments/cutouts/briar_weaver/rr21_gates.py --native "$proof/native"
PYTHONPATH=tools python3 -m humanoid_cutout.proof review --case "$rig_case" --capture "$proof/native" --output "$proof/briar_weaver_review.mp4"
;;
*) exit 2 ;;
esac
