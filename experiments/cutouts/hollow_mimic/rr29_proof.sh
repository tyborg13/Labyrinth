#!/bin/sh
# Director windowed proof only. The implementation sandbox never runs these.
set -eu
stage="${1:?Use density, rest, native, sheets, idle, production or review}"
task_id=rr-29
rig_case="$(pwd)/experiments/cutouts/hollow_mimic/rr29"
proof="$rig_case/proof"
case "$stage" in
density)
python3 tools/process_board_density.py --only hollow_mimic_cutout
python3 tools/visual_probe_runner.py --task-id "$task_id" --no-headless --display-driver macos --audio-driver Dummy --timeout 180 tests/rr20/density_rebake.gd -- --only hollow_mimic_cutout
python3 tools/process_board_density.py --record-rests --only hollow_mimic_cutout
python3 tools/godot_task_runner.py --task-id "$task_id" --stream -- godot --headless --path . --script tests/rr20/shadow_refresh.gd
python3 tools/process_board_density.py --check --only hollow_mimic_cutout
PYTHONPATH=tools python3 - <<'PY'
from pathlib import Path
import sys
sys.path.insert(0,'experiments/cutouts/hollow_mimic')
from density import record
from rr29_build import CASE
pending=record(case=CASE)
if pending: raise ValueError(pending)
from rr29_identity import register
register()
PY
;;
rest|native|idle)
case "$stage" in
rest) contract=tests/rr20/rest_contract.json; flags=--rest-only; out=native_rest; budget=120 ;;
native) contract=tests/rr20/render_contract.json; flags=; out=native; budget=3600 ;;
idle) contract=tests/rr20/idle_contract.json; flags=--idle-comparison; out=idle_native; budget=300 ;;
esac
python3 tools/godot_task_runner.py --task-id "$task_id" --stream -- godot --headless --path . --script tests/rr29/samples.gd -- --case "$rig_case" --output "$proof/samples.json"
python3 tools/visual_probe_runner.py --task-id "$task_id" --no-headless --display-driver macos --audio-driver Dummy --timeout "$budget" --expect-size 1920x1080 --proof-contract "$contract" --result-manifest "$proof/${stage}_result.json" tests/rr29/native_probe.gd -- --case "$rig_case" --output "$proof/$out" $flags
if [ "$stage" = native ]; then PYTHONPATH=tools python3 -B experiments/cutouts/hollow_mimic/rr29_gates.py --native "$proof/native"; fi
if [ "$stage" = idle ]; then PYTHONPATH=tools python3 -m humanoid_cutout.proof idle --case "$rig_case" --capture "$proof/idle_native" --output "$proof/hollow_mimic_protagonist_idle.mp4"; fi
;;
production)
for view in front rear; do
    for card in whirlwind_slash quick_stab hurl_spear; do
        capture="$proof/production_native/$view/$card"
        python3 tools/visual_probe_runner.py --task-id "$task_id" --no-headless --display-driver macos --audio-driver Dummy --timeout 900 --expect-size 1920x1080 --proof-contract tests/rr20/production_contract.json --result-manifest "$capture/result.json" tests/rr29/production_probe.gd -- --type hollow_mimic --view "$view" --mirror-card "$card" --output "$capture"
        PYTHONPATH=tools python3 experiments/cutouts/hollow_mimic/rr29_production.py --input "$capture/frames.json"
    done
done
;;
sheets|review)
PYTHONPATH=tools python3 -B experiments/cutouts/hollow_mimic/rr29_gates.py --native "$proof/native"
if [ "$stage" = sheets ]; then
    PYTHONPATH=tools python3 -m humanoid_cutout.proof sheets --case "$rig_case" --capture "$proof/native" --output "$proof/contact_sheets"
else
    PYTHONPATH=tools python3 -m humanoid_cutout.proof review --case "$rig_case" --capture "$proof/native" --output "$proof/hollow_mimic_review.mp4"
fi
;;
*) exit 2 ;;
esac
