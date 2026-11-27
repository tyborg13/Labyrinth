#!/usr/bin/env bash
set -euo pipefail

tool_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project="$(cd "$tool_dir/../.." && pwd)"
cd "$project"
capture_timeout=240
before_ref=codex/fel-08

case "$#:${1:-}" in
    0:) mode=native ;;
    1:--dry-run) mode=dry ;;
    *) echo "Usage: $0 [--dry-run]" >&2; exit 2 ;;
esac

before_commit="$(git rev-parse --verify "$before_ref^{commit}")"
if [[ ! -s cel_look_variants/manifest.json || ! -s .godot/global_script_class_cache.cfg ]]; then
    echo "FEL17 requires the prepared game import cache and existing cel look variants" >&2
    exit 1
fi

mkdir -p "$tool_dir/captures"
touch "$tool_dir/captures/.gdignore"
output="$(mktemp -d "$tool_dir/captures/$mode.XXXXXX")"
mkdir "$output/release" "$output/branch"
printf 'FEL17 capture directory %s\n' "$output"
printf '%s\n' "$before_commit" > "$output/before-ref.txt"
git rev-parse HEAD > "$output/after-base.txt"
export PYTHONDONTWRITEBYTECODE=1 LABYRINTH_CEL_LOOK=all
# The fel-08 driver reads these from both projects.
export FEL08_BA_MODE="$mode" FEL08_BA_OUTPUT="$output" FEL08_BA_TOOL="$project/tools/fel08/before_after"

run_headless() {
    python3 tools/godot_task_runner.py --task-id fel-17 --timeout "$capture_timeout" \
        --stream -- godot --headless --path "$1" --script "$2"
}
python3 "$tool_dir/proof.py" prepare "$output"
run_headless "$project" "$tool_dir/prepare.gd" 2>&1 | tee "$output/prepare.log"

# Archive the baseline independently of any sibling worktree. Both sides use
# the cel variants and imported assets prepared for this same game revision.
before_copy="$output/before-project"
trap 'rm -rf "$before_copy"' EXIT
mkdir "$before_copy"
git archive "$before_commit" | tar -xf - -C "$before_copy"
cp -cRp .godot cel_look_variants "$before_copy/"

for side in release branch; do
    capture_project="$project"
    if [[ "$side" == release ]]; then capture_project="$before_copy"; fi
    export FEL08_BA_SIDE="$side"
    if [[ "$mode" == dry ]]; then
        run_headless "$capture_project" "$tool_dir/session.gd" 2>&1 | tee "$output/$side/runner.log"
    else
        python3 tools/visual_probe_runner.py --task-id fel-17 --project "$capture_project" \
            --no-headless --display-driver macos --audio-driver Dummy --timeout "$capture_timeout" \
            --expect-size 1920x1080 --proof-contract "$tool_dir/proof_contract.json" \
            --result-manifest "$output/$side/visual-proof.json" "$tool_dir/session.gd" \
            2>&1 | tee "$output/$side/runner.log"
    fi
done

python3 "$tool_dir/proof.py" "$mode" "$output"
