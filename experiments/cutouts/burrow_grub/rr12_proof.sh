#!/bin/sh
# Director-only windowed proof. Run from the rr-12 worktree root.
set -eu
creature="${1:?Use burrow_grub or ember_tick}"
case "$creature" in burrow_grub|ember_tick) ;; *) exit 2 ;; esac
stage="${2:-full}"
case "$stage" in full|--from-review) ;; *) exit 2 ;; esac
project="$(pwd)"
rig_case="$project/experiments/cutouts/$creature/mq5"
native="$rig_case/proof/native"
production="$rig_case/proof/production_native"
mkdir -p "$native" "$production"

# Native exact rest followed by every sequential 60 Hz frame and isolated layers.
if [ "$stage" = full ]; then
python3 tools/visual_probe_runner.py --task-id rr-12 --no-headless --display-driver macos --audio-driver Dummy --timeout 120 --expect-size 1920x1080 --proof-contract tests/rr12/rest_contract.json tests/maquette_cutout/native_capture.gd -- --case "$rig_case" --output "$rig_case/proof/native_rest" --rest-only
python3 tools/godot_task_runner.py --task-id rr-12 --stream -- godot --headless --path . --script tests/rr12/motion_samples.gd -- --case "$rig_case" --output "$rig_case/proof/motion_samples.json"
python3 -B experiments/cutouts/burrow_grub/rr12_gates.py motion --creature "$creature"
python3 tools/godot_task_runner.py --task-id rr-12 --stream -- godot --headless --path . --script tests/maquette_cutout/pixel_samples.gd -- --case "$rig_case" --output "$native/pixel_samples.json"
python3 tools/visual_probe_runner.py --task-id rr-12 --no-headless --display-driver macos --audio-driver Dummy --timeout 900 --expect-size 1920x1080 --proof-contract "tests/rr12/${creature}_render_contract.json" tests/maquette_cutout/native_capture.gd -- --case "$rig_case" --output "$native"
python3 -B experiments/cutouts/burrow_grub/rr12_gates.py native --creature "$creature" --input "$native" --output "$native/verification.json"
else
python3 -B experiments/cutouts/burrow_grub/rr12_gates.py native --creature "$creature" --input "$native" --output "$native/verification.json"
fi
# Existing rr-04 composer enforces front/rear, 2x nearest, #1E1E24, title,
# idle/move x3, other clips x2, death once plus exactly one second of hold.
python3 -B experiments/cutouts/burrow_grub/rr12_gates.py review --creature "$creature" --input "$native" --output "$rig_case/proof/${creature}_review.mp4"

python3 -B experiments/cutouts/burrow_grub/rr12_contacts.py --capture "$native" --output "$rig_case/proof/contact_sheets"

# Density sources and treatment are already staged by the worker. Rest evidence
# is recorded only after this real production renderer rebake.
python3 tools/visual_probe_runner.py --task-id rr-12 --no-headless --display-driver macos --audio-driver Dummy --timeout 120 --expect-size 255x255 --proof-contract "tests/rr12/${creature}_density_contract.json" tools/rebake_cutout_rests.gd -- --only "${creature}_cutout"
python3 tools/process_board_density.py --only "${creature}_cutout" --record-rests
python3 -B experiments/cutouts/burrow_grub/rr12_release.py seal-density --creature "$creature"
python3 tools/godot_task_runner.py --task-id rr-12 --stream -- godot --headless --path . --script tools/generate_unit_shadow_cache.gd

python3 tools/visual_probe_runner.py --task-id rr-12 --no-headless --display-driver macos --audio-driver Dummy --timeout 900 --expect-size 1920x1080 --proof-contract "tests/rr12/${creature}_production_contract.json" tests/rr12/production_capture.gd -- --type "$creature" --output "$production"
python3 -B experiments/cutouts/burrow_grub/rr12_gates.py production --creature "$creature" --input "$production/frames.json" --output "$production/verification.json"
