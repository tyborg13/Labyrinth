#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
export FEL32_TRACE=1
source tools/fel32/launch.sh "$@"

replay_timeout=1200
for side in release branch; do
    project="$PWD"
    if [[ "$side" == release ]]; then project="$release"; fi
    "${runner[@]}" --timeout "$replay_timeout" -- godot --headless --fixed-fps 60 --path "$project" \
        --main-pack "$output/$side.pck" --script res://tools/fel32/replay.gd -- "$transcript" "$output/$side" \
        2>&1 | tee "$output/$side.log"
done
"${runner[@]}" -- godot --headless --path . --main-pack "$output/branch.pck" --script res://tools/fel32/adjacent.gd -- "$output/adjacent.json"
python3 tools/fel32/contrast.py "$output"
