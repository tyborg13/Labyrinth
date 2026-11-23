#!/bin/sh
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
worktree=$PWD
base=$worktree/../txt-25
probe=$worktree/tools/txt28/capture.gd
export LABYRINTH_CEL_LOOK=all

mkdir -p /private/tmp/labyrinth_codex/txt-28
output=$(mktemp -d /private/tmp/labyrinth_codex/txt-28/native.XXXXXX)
printf '%s\n' "$output"

dry_run() {
    version=$1
    size=$2
    project=$3
    python3 tools/godot_task_runner.py --task-id txt-28 --stream -- \
        godot --headless --path "$project" --script "$probe" -- "$version" "$size" "$output/$version-$size"
}

capture() {
    version=$1
    size=$2
    project=$3
    folder=$output/$version-$size
    mkdir -p "$folder"
    python3 tools/visual_probe_runner.py --project "$project" --task-id txt-28 \
        --no-headless --display-driver macos --audio-driver Dummy --timeout 120 \
        --expect-size "$size" --proof-contract "tools/txt28/$version.contract.json" \
        --result-manifest "$folder/manifest.json" "$probe" -- "$version" "$size" "$folder"
}

case ${1:-} in
    --dry-run)
        git -C "$base" diff --quiet codex/mrg-14 -- data scripts scenes assets project.godot
        dry_run before 1920x1080 "$base"
        dry_run after 1920x1080 "$worktree"
        dry_run after 1280x800 "$worktree"
        ;;
    "")
        git -C "$base" diff --quiet codex/mrg-14 -- data scripts scenes assets project.godot
        capture before 1920x1080 "$base"
        capture after 1920x1080 "$worktree"
        capture after 1280x800 "$worktree"
        ;;
    *)
        printf 'Usage: %s [--dry-run]\n' "$0" >&2
        exit 2
        ;;
esac
