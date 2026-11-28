#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
    printf 'Usage: %s <release worktree> <new output dir>\n' "$0" >&2
    exit 2
fi
release="$(cd "$1" && pwd)"
mkdir "$2"
output="$(cd "$2" && pwd)"
tool_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$tool_dir/../.."
branch="$PWD"
checkpoint_root="${FEL29_CHECKPOINTS:-$branch/../fel-20/tools/fel20/captures/headless-descent/checkpoints}"
checkpoint_root="$(cd "$checkpoint_root" && pwd)"
command -v ffmpeg >/dev/null
export LABYRINTH_CEL_LOOK=all LABYRINTH_PROBE_WINDOW=1

probe=(
    python3 tools/visual_probe_runner.py --task-id fel-29 --no-headless
    --display-driver macos --timeout 90 --expect-size 1920x1080
    --proof-contract "$tool_dir/proof_contract.json"
)
for take in map combat new_game; do
    mkdir "$output/$take"
    for build in release branch; do
        destination="$output/$take/$build"
        mkdir "$destination"
        "${probe[@]}" --project "${!build}" --result-manifest "$destination/visual-proof.json" \
            "$tool_dir/probe.gd" -- --case "$take" --output-dir "$destination" --checkpoints "$checkpoint_root" \
            2>&1 | tee "$destination/runner.log"
        python3 "$tool_dir/native_report.py" measure "$destination" "$build" | tee "$destination/measurement.log"
    done
    python3 "$tool_dir/native_report.py" compare "$output/$take"
done
python3 "$tool_dir/native_report.py" verify "$output"
