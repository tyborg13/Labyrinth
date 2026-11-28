#!/usr/bin/env bash
set -euo pipefail
tool_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$tool_dir/../.."
branch="$PWD"
release="$(cd "${1:?missing codex/release worktree}" && pwd)"
output="${2:?missing output directory}"
output="$(cd "$output" && pwd)"
dry_run="${3:-}"
export FEL30_REPLAY="${FEL34_INPUTS:-/private/tmp/labyrinth_codex/fel-30-topbar/inputs.jsonl}"
export LABYRINTH_CEL_LOOK=all LABYRINTH_PROBE_WINDOW=1
unset FEL30_SEED_START FEL30_SEED_LIMIT
python3 tools/fel34/report.py verify-selection "$output"
if [[ "$dry_run" == --dry-run ]]; then
    printf 'FEL34 NATIVE READY pairs=13 trees=2 output=%s\n' "$output"
    exit 0
fi
run="$(mktemp -d "$output/native.XXXXXX")"
runner=(python3 tools/godot_task_runner.py --task-id fel-34 --stream)
export FEL30_SELECTION="$run/replay-selection.json"
python3 tools/fel34/report.py replay-selection "$output" > "$FEL30_SELECTION"
"${runner[@]}" -- godot --headless --path "$branch" --script tools/fel34/geometry.gd -- --write-noctyrax "$run/night-coil.json"
for side in release branch; do
    tree="$release"
    if [[ "$side" == branch ]]; then tree="$branch"; fi
    overlay="$run/$side-overlay"
    export FEL34_OVERLAY="$overlay/census.pck" FEL30_OUTPUT="$run/$side"
    python3 tools/fel34/prepare.py "$tree" "$overlay"
    "${runner[@]}" -- godot --headless --path "$branch" --script tools/fel34/pack.gd -- "$overlay"
    python3 tools/visual_probe_runner.py --project "$tree" --task-id fel-34 --no-headless \
        --display-driver macos --audio-driver Dummy --godot "$tool_dir/godot-native.sh" --timeout 3600 \
        --expect-size 1920x1080 --min-images 12 --proof-contract "$tool_dir/proof_contract.json" \
        --result-manifest "$run/$side-visual-proof.json" "$tool_dir/census.gd" | tee "$run/$side-runner.log"
    python3 tools/visual_probe_runner.py --project "$tree" --task-id fel-34 --no-headless \
        --display-driver macos --audio-driver Dummy --godot "$tool_dir/godot-native.sh" --timeout 300 \
        --expect-size 1920x1080 --min-images 1 --result-manifest "$run/$side-night-coil-proof.json" \
        res://tools/fel34/geometry.gd -- --native-noctyrax "$FEL30_OUTPUT" 13 "$run/night-coil.json"
done
"${runner[@]}" -- godot --headless --path "$branch" --script tools/fel34/media.gd -- "$output/selection.json" "$run"
printf 'FEL34 NATIVE OUTPUT %s\n' "$run"
