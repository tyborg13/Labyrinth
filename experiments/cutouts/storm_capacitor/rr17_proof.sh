#!/bin/sh
# Exact director-only windowed sequence; run from this worktree's root.
set -eu
project="$(pwd)"
rig_case="$project/experiments/cutouts/storm_capacitor/mq5"
native="$rig_case/proof/native"
production="$rig_case/proof/production_native"
mkdir -p "$native" "$production"
mkdir -p "$rig_case/proof/logs"
python3 tools/visual_probe_runner.py --task-id rr-17 --no-headless --display-driver macos --audio-driver Dummy --timeout 120 --expect-size 1920x1080 --proof-contract tests/rr17/rest_contract.json tests/rr17/native_capture.gd -- --output "$rig_case/proof/native_rest" --rest-only
python3 tools/godot_task_runner.py --task-id rr-17 --stream -- godot --headless --path . --script tests/rr17/samples.gd
python3 -B experiments/cutouts/storm_capacitor/rr17_gates.py headless
python3 tools/visual_probe_runner.py --task-id rr-17 --no-headless --display-driver macos --audio-driver Dummy --timeout 900 --expect-size 1920x1080 --proof-contract tests/rr17/render_contract.json tests/rr17/native_capture.gd -- --output "$native"
python3 -B experiments/cutouts/storm_capacitor/rr17_gates.py native --input "$native" --output "$native/verification.json"
python3 -B experiments/cutouts/storm_capacitor/rr17_review.py --native "$native" --output "$rig_case/proof/storm_capacitor_review.mp4"
# Native capture verifies and supplies the exact rest rebake; seal-rest checks
# the native gate before recording density, rather than inventing a rebake.
python3 -B experiments/cutouts/storm_capacitor/rr17_release.py seal-rest --native "$native"
python3 tools/process_board_density.py --only storm_capacitor_cutout --check
python3 tools/godot_task_runner.py --task-id rr-17 --stream -- godot --headless --path . --script experiments/cutouts/storm_capacitor/rr17_shadow.gd
git show eafe1715d:assets/generated/unit_shadow_cache.res > "$rig_case/proof/logs/shadow_baseline.res"
python3 tools/godot_task_runner.py --task-id rr-17 --stream -- godot --headless --path . --script experiments/cutouts/storm_capacitor/rr17_shadow_check.gd -- --baseline "$rig_case/proof/logs/shadow_baseline.res"
python3 tools/visual_probe_runner.py --task-id rr-17 --no-headless --display-driver macos --audio-driver Dummy --timeout 900 --expect-size 1920x1080 --proof-contract tests/rr17/production_contract.json tests/rr17/production_capture.gd -- --type storm_capacitor --output "$production"
python3 -B experiments/cutouts/storm_capacitor/rr17_gates.py production --input "$production/frames.json" --output "$production/verification.json"
