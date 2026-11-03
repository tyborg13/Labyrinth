#!/bin/sh
# Director-only windowed proof. Never run these stages without a window server.
set -eu
stage="${1:?Use frames, rig or fight}"
output=/private/tmp/labyrinth_codex/rr-54
export LABYRINTH_TASK_ID=rr-54
case "$stage" in
frames)
python3 tools/cel_look.py build --if-stale
export LABYRINTH_CEL_LOOK=all
for view in front rear; do
    set --
    if [ "$view" = rear ]; then set -- --rear; fi
    python3 tools/visual_probe_runner.py --task-id rr-54 --no-headless --display-driver macos --audio-driver Dummy --timeout 900 --expect-size 1920x1080 --proof-contract tests/rr37/production_contract.json --result-manifest "$output/native-$view-result.json" --overwrite-result-manifest tests/rr37/production_capture.gd -- --type frostglass_lancer "$@" --output "$output/native-$view"
done
;;
rig)
PYTHONPATH=tools:experiments/cutouts/frostglass_lancer python3 -B experiments/cutouts/frostglass_lancer/rr37_proof_case.py
export LABYRINTH_CEL_LOOK=off
python3 tools/visual_probe_runner.py --task-id rr-54 --no-headless --display-driver macos --audio-driver Dummy --timeout 3600 --expect-size 1920x1080 --proof-contract tests/rr37/render_contract.json --result-manifest "$output/native-rig-result.json" --overwrite-result-manifest tests/rr37/native_capture.gd -- --case res://experiments/cutouts/frostglass_lancer/rr37/proof/production_case --output "$output/native-rig"
;;
fight)
python3 tools/cel_look.py build --if-stale
export LABYRINTH_CEL_LOOK=all
python3 tools/visual_probe_runner.py --task-id rr-54 --no-headless --display-driver macos --audio-driver Dummy --timeout 300 --expect-size 1920x1080 --proof-contract experiments/cutouts/frostglass_lancer/rr41_gameplay_contract.json --result-manifest "$output/fight-result.json" --overwrite-result-manifest tests/frostglass_lancer_cutout_gameplay_probe.gd -- --output "$output/fight"
;;
*) echo 'Use frames, rig or fight' >&2; exit 2 ;;
esac
