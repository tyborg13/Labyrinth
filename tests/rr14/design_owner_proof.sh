#!/bin/sh
# Window-server proof belongs to the design owner. No worker capture occurred.
set -eu
cd "$(dirname "$0")/../.."
export LABYRINTH_TASK_ID=rr-14
export PYTHONDONTWRITEBYTECODE=1
proof_root=/private/tmp/labyrinth_codex/rr-14/director
mkdir -p "$proof_root"
python3 tools/godot_task_runner.py --task-id rr-14 --stream -- godot --headless --path . --script tests/rr10/samples.gd -- --output "$proof_root/seer-samples.json"
python3 tests/rr14/verify_samples.py --samples "$proof_root/seer-samples.json"
# This existing probe emits all frames and six 1920x1080 representatives for
# every action. Its existing semantic contract also requires the rest pair.
python3 tools/visual_probe_runner.py --task-id rr-14 --no-headless --display-driver macos --audio-driver Dummy --timeout 180 --expect-size 1920x1080 --proof-contract tests/rr10/render_contract.json --result-manifest "$proof_root/seer-native-result.json" tests/rr10/native_capture.gd -- --output "$proof_root/seer-native"
python3 experiments/cutouts/hoarfrost_seer/rr10_gates.py --native "$proof_root/seer-native"
PYTHONPATH=tools python3 -m humanoid_cutout.proof sheets --case experiments/cutouts/hoarfrost_seer/rr10 --capture "$proof_root/seer-native" --output "$proof_root/seer-sheets"
