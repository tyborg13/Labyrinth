#!/bin/sh
set -eu

worktree=/Users/borgerding/workspace/Labyrinth.worktrees/txt-30
cd "$worktree"
base="$worktree/../txt-29"
probe="$worktree/tools/txt30/capture.gd"
export LABYRINTH_CEL_LOOK=all

git -C "$base" diff --quiet codex/mrg-14 -- data scripts scenes assets project.godot || {
    printf '%s\n' 'The txt-29 production files differ from candidate 4 (codex/mrg-14).' >&2
    exit 1
}
output=$(mktemp -d /private/tmp/labyrinth_codex/txt-30/native.XXXXXX)
printf 'TXT30 proof output %s\n' "$output"

dry_run() {
    version=$1
    size=$2
    project=$3
    python3 tools/godot_task_runner.py --task-id txt-30 --stream -- \
        godot --headless --path "$project" --script "$probe" -- "$version" "$size" "$output/$version-$size"
}

capture() {
    version=$1
    size=$2
    project=$3
    contract=$4
    folder="$output/$version-$size"
    mkdir -p "$folder"
    python3 tools/visual_probe_runner.py --project "$project" --task-id txt-30 \
        --no-headless --display-driver macos --audio-driver Dummy \
        --expect-size "$size" --proof-contract "$contract" --result-manifest "$folder/manifest.json" \
        "$probe" -- "$version" "$size" "$folder"
}

case ${1:-} in
    --dry-run)
        dry_run before 1920x1080 "$base"
        dry_run before 1280x800 "$base"
        dry_run after 1920x1080 "$worktree"
        dry_run after 1280x800 "$worktree"
        ;;
    "")
        capture before 1920x1080 "$base" tools/txt30/full.contract.json
        capture before 1280x800 "$base" tools/txt30/compact.contract.json
        capture after 1920x1080 "$worktree" tools/txt30/full.contract.json
        capture after 1280x800 "$worktree" tools/txt30/compact.contract.json
        ;;
    *)
        printf 'Usage: %s [--dry-run]\n' "$0" >&2
        exit 2
        ;;
esac

printf 'TXT30 proof output %s\n' "$output"
