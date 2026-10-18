#!/bin/sh
# Director-only windowed proof. Run from the rr-07 worktree root.
set -eu
creature="${1:?Use hoarfrost_seer or arc_thrall}"
case "$creature" in hoarfrost_seer|arc_thrall) ;; *) exit 2 ;; esac
stage="${2:-full}"
case "$stage" in full|--from-review) ;; *) exit 2 ;; esac
project="$(pwd)"
rig_case="$project/experiments/cutouts/$creature/mq5"
native="$rig_case/proof/native"
production="$rig_case/proof/production_native"
mkdir -p "$native" "$production"

# Native exact rest followed by every sequential 60 Hz frame and isolated layers.
if [ "$stage" = full ]; then
python3 tools/visual_probe_runner.py --task-id rr-07 --no-headless --display-driver macos --audio-driver Dummy --timeout 120 --expect-size 1920x1080 --proof-contract tests/rr07/rest_contract.json tests/maquette_cutout/native_capture.gd -- --case "$rig_case" --output "$rig_case/proof/native_rest" --rest-only
python3 tools/godot_task_runner.py --task-id rr-07 --stream -- godot --headless --path . --script tests/rr07/motion_samples.gd -- --case "$rig_case" --output "$rig_case/proof/motion_samples.json"
python3 -B experiments/cutouts/hoarfrost_seer/rr07_gates.py motion --creature "$creature"
python3 tools/godot_task_runner.py --task-id rr-07 --stream -- godot --headless --path . --script tests/maquette_cutout/pixel_samples.gd -- --case "$rig_case" --output "$native/pixel_samples.json"
python3 tools/visual_probe_runner.py --task-id rr-07 --no-headless --display-driver macos --audio-driver Dummy --timeout 900 --expect-size 1920x1080 --proof-contract "tests/rr07/${creature}_render_contract.json" tests/maquette_cutout/native_capture.gd -- --case "$rig_case" --output "$native"
python3 -B experiments/cutouts/hoarfrost_seer/rr07_gates.py native --creature "$creature" --input "$native" --output "$native/verification.json"
fi
# Existing rr-04 composer enforces front/rear, 2x nearest, #1E1E24, title,
# idle/move x3, other clips x2, death once plus exactly one second of hold.
python3 -B experiments/cutouts/hoarfrost_seer/rr07_gates.py review --creature "$creature" --input "$native" --output "$rig_case/proof/${creature}_review.mp4"

# Density sources and treatment are already staged by the worker. Rest evidence
# is recorded only after this real production renderer rebake.
python3 tools/visual_probe_runner.py --task-id rr-07 --no-headless --display-driver macos --audio-driver Dummy --timeout 120 --expect-size 255x255 --proof-contract "tests/rr07/${creature}_density_contract.json" tools/rebake_cutout_rests.gd -- --only "${creature}_cutout"
python3 tools/process_board_density.py --only "${creature}_cutout" --record-rests
python3 -B experiments/cutouts/hoarfrost_seer/rr07_release.py seal-density --creature "$creature"
python3 tools/godot_task_runner.py --task-id rr-07 --stream -- godot --headless --path . --script tools/generate_unit_shadow_cache.gd

python3 tools/visual_probe_runner.py --task-id rr-07 --no-headless --display-driver macos --audio-driver Dummy --timeout 900 --expect-size 1920x1080 --proof-contract "tests/rr07/${creature}_production_contract.json" tests/rr07/production_capture.gd -- --type "$creature" --output "$production"
python3 -B experiments/cutouts/hoarfrost_seer/rr07_gates.py production --creature "$creature" --input "$production/frames.json" --output "$production/verification.json"
