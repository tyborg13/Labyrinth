#!/usr/bin/env bash
set -euo pipefail

proof_dir=/private/tmp/labyrinth_codex/gfix-32
base_ref=f92582e85f72107cc80abf8c72e3bc4677a93dd9
base_project=${BASE_PROJECT:-"$proof_dir/base-project"}
project=$(pwd -P)
probe="$project/tools/gfix32/verify.gd"
contract="$project/tools/gfix32/proof_contract.json"

if [[ ! -f "$probe" || ! -f "$contract" ]]; then
    echo "Run from the gfix-32 worktree root." >&2
    exit 2
fi

export LABYRINTH_CEL_LOOK=all

if [[ ${1:-} == --dry-run ]]; then
    for frame in 01_settings_closed 02_settings_confirm 03_room_closed 04_map_open 05_event_open; do
        printf 'Capture planned: %s/before/%s.png\n' "$proof_dir" "$frame"
    done
    exec python3 tools/godot_task_runner.py --task-id gfix-32 --stream -- godot \
        --headless --path "$project" --script "$probe" -- --output-dir "$proof_dir/after"
fi

if [[ $# -ne 0 ]]; then
    echo "Usage: BASE_PROJECT=/path/to/pristine-base bash $0 [--dry-run]" >&2
    exit 2
fi
if [[ ! -f "$base_project/project.godot" ]] || [[ $(git -C "$base_project" rev-parse HEAD) != "$base_ref" ]]; then
    printf 'BASE_PROJECT must be a pristine checkout at %s.\n' "$base_ref" >&2
    exit 2
fi

capture() {
    local project_dir=$1
    local phase=$2
    shift 2
    python3 tools/visual_probe_runner.py --project "$project_dir" --task-id gfix-32 \
        --no-headless --display-driver macos --audio-driver Dummy \
        --expect-size 1920x1080 --proof-contract "$contract" \
        --result-manifest "$proof_dir/$phase/manifest.json" --overwrite-result-manifest \
        "$probe" -- --output-dir "$proof_dir/$phase" "$@"
}

capture "$base_project" before --baseline
capture "$project" after
