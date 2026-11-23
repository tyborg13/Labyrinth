#!/usr/bin/env bash
set -euo pipefail

project=$(pwd -P)
proof_dir=/private/tmp/labyrinth_codex/pol-61
base_ref=92ed73479e58c97aa091300579eeef6f0039e59c
base_project=${BASE_PROJECT:-"$project/../release"}
probe="$project/tools/pol61/trace.gd"
contract="$project/tools/pol61/proof_contract.json"
native_timeout=180

if [[ ! -f "$probe" || ! -f "$contract" ]]; then
    echo "Run from the pol-61 worktree root." >&2
    exit 2
fi
if [[ ! -f "$base_project/project.godot" || $(git -C "$base_project" rev-parse HEAD) != "$base_ref" ]] ||
   ! git -C "$base_project" diff --quiet "$base_ref" --; then
    printf 'BASE_PROJECT must be a pristine checkout at %s.\n' "$base_ref" >&2
    exit 2
fi

export LABYRINTH_CEL_LOOK=all

if [[ ${1:-} == --dry-run && $# -eq 1 ]]; then
    for phase in before after; do
        printf 'Native output: %s/%s/{frames.jsonl,manifest.json,*.png}\n' "$proof_dir" "$phase"
    done
    python3 tools/godot_task_runner.py --task-id pol-61 --stream -- godot \
        --headless --path "$base_project" --script "$probe" -- \
        --baseline --output-dir "$proof_dir/headless-before"
    exec python3 tools/godot_task_runner.py --task-id pol-61 --stream -- godot \
        --headless --path "$project" --script "$probe" -- \
        --output-dir "$proof_dir/headless-after"
fi
if [[ $# -ne 0 ]]; then
    echo "Usage: bash $0 [--dry-run]" >&2
    exit 2
fi

capture() {
    local run_project=$1 phase=$2
    shift 2
    python3 tools/visual_probe_runner.py --project "$run_project" --task-id pol-61 \
        --no-headless --display-driver macos --audio-driver Dummy --timeout "$native_timeout" \
        --expect-size 1920x1080 --proof-contract "$contract" \
        --result-manifest "$proof_dir/$phase/manifest.json" --overwrite-result-manifest \
        "$probe" -- --output-dir "$proof_dir/$phase" "$@"
}

capture "$base_project" before --baseline
capture "$project" after
