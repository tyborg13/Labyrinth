#!/usr/bin/env bash
set -euo pipefail
tool_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$tool_dir/../.."
branch="$PWD"
release="$(cd "${1:?missing codex/release worktree}" && pwd)"
output="${2:?missing output directory}"
mkdir -p "$output"
output="$(cd "$output" && pwd)"
export LABYRINTH_CEL_LOOK=all
export FEL30_REPLAY="${FEL34_INPUTS:-/private/tmp/labyrinth_codex/fel-30-topbar/inputs.jsonl}"
export FEL30_SELECTION="$output/legacy.json"
python3 tools/fel34/report.py legacy "$output"
runner=(python3 tools/godot_task_runner.py --task-id fel-34 --stream)
pids=()
for side in release branch; do
    tree="$release"
    if [[ "$side" == branch ]]; then tree="$branch"; fi
    overlay="$output/$side/overlay"
    python3 tools/fel34/prepare.py "$tree" "$overlay"
    "${runner[@]}" -- godot --headless --path "$branch" --script tools/fel34/pack.gd -- "$overlay"
    for first in 0 2 4; do
      (
        for index in "$first" "$((first + 1))"; do
            seed=$((30001 + index))
            seed_out="$output/$side/$seed"
            mkdir -p "$seed_out"
            FEL30_SEED_START="$index" FEL30_SEED_LIMIT=1 FEL30_OUTPUT="$seed_out" \
                "${runner[@]}" --timeout 1800 -- godot --headless --fixed-fps 60 --path "$tree" \
                --main-pack "$overlay/census.pck" --script "$tool_dir/census.gd" 2>&1 | tee "$seed_out/runner.log"
        done
      ) &
      pids+=("$!")
    done
done
failed=0
for pid in "${pids[@]}"; do wait "$pid" || failed=1; done
if (( failed )); then exit 1; fi
python3 tools/fel34/report.py summarize "$output"
