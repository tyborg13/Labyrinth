#!/bin/sh
# Re-runnable Lancer-only headless rebuild; native proof belongs to the owner.
set -eu
export LABYRINTH_TASK_ID=rr-41
export PYTHONPATH="tools:experiments/cutouts/frostglass_lancer${PYTHONPATH:+:$PYTHONPATH}"
case_root="experiments/cutouts/frostglass_lancer/rr37"
stage="${1:-rebuild}"
case "$stage" in
rebuild)
python3 -B experiments/cutouts/frostglass_lancer/rr37_build.py
python3 -B experiments/cutouts/frostglass_lancer/rr37_native_checks.py --seal
python3 -B experiments/cutouts/frostglass_lancer/rr37_density.py --rebuild-derived-sources
python3 -B experiments/cutouts/frostglass_lancer/rr41_density.py --seal-rests
python3 tools/godot_task_runner.py --task-id rr-41 --stream -- godot --headless --path . --script tests/rr37/shadow_refresh.gd
python3 tools/process_board_density.py --check
python3 -B experiments/cutouts/frostglass_lancer/rr41_scope.py
;;
check)
python3 -B experiments/cutouts/frostglass_lancer/rr41_density.py
python3 -B experiments/cutouts/frostglass_lancer/rr37_evidence.py --refresh --case "$case_root"
python3 -B experiments/cutouts/frostglass_lancer/rr37_gates.py
python3 -B experiments/cutouts/frostglass_lancer/rr37_proof_case.py
python3 -B experiments/cutouts/frostglass_lancer/rr37_evidence.py --refresh --case "$case_root/proof/production_case"
python3 -B experiments/cutouts/frostglass_lancer/rr37_gates.py --case "$case_root/proof/production_case"
python3 tools/godot_task_runner.py --task-id rr-41 --stream -- godot --headless --path . --script tests/rr37/samples.gd -- --production --output "$case_root/proof/logs/rr41-production-poses.json"
python3 -B experiments/cutouts/frostglass_lancer/rr37_frames.py --production --samples "$case_root/proof/logs/rr41-production-poses.json"
;;
*) echo "Use rebuild or check" >&2; exit 2 ;;
esac
