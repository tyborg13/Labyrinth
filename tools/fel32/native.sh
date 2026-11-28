#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
source tools/fel32/launch.sh "$@"

for side in release branch; do
    project="$PWD"
    if [[ "$side" == release ]]; then project="$release"; fi
    FEL32_PACK="$output/$side.pck" python3 tools/visual_probe_runner.py --project "$project" \
        --task-id fel-32 --no-headless --display-driver macos --audio-driver Dummy \
        --godot "$PWD/tools/fel32/godot-native.sh" --timeout "$replay_timeout" --expect-size 1920x1080 \
        --proof-contract "$PWD/tools/fel32/proof_contract.json" --result-manifest "$output/$side-visual-proof.json" \
        res://tools/fel32/replay.gd -- "$transcript" "$output/$side"
done
"${runner[@]}" -- godot --headless --path . --script tools/fel32/media.gd -- "$output"
