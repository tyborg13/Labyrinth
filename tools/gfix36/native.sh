#!/bin/sh
set -eu

launcher=$0
if [ -L "$launcher" ]; then
    target=$(readlink "$launcher")
    case "$target" in
        /*) launcher=$target ;;
        *) launcher=$(dirname "$launcher")/$target ;;
    esac
fi
current=$(cd "$(dirname "$launcher")/../.." && pwd)
base="$(dirname "$current")/scn-02"
output_root=/private/tmp/labyrinth_codex/gfix-36

if [ "$#" -gt 1 ] || { [ "$#" -eq 1 ] && [ "$1" != --dry-run ]; }; then
    printf 'Usage: %s [--dry-run]\n' "$0" >&2
    exit 2
fi
if [ "$#" -eq 1 ]; then
    # Retain the scn-02 watchdog for concurrent headless starts.
    export SCN01_ENGINE_TIMEOUT=180
fi
export SCN01_TASK_ID=gfix-36
export PYTHONDONTWRITEBYTECODE=1
stamp=$(python3 -c 'from datetime import datetime, timezone; print(datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ"))')
shots=reward,campfire,treasure,scavenger,combat_idle,pre_battle

capture() (
    project=$1
    label=$2
    size=$3
    only=$4
    shift 4
    output="$output_root/$stamp/$label"
    printf 'Output folder (%s): %s\n' "$label" "$output"
    cd "$project"
    python3 tools/scn01/census.py --only "$only" --size "$size" --out "$output" "$@"
)

status=0
capture "$base" before 1920x1080 "$shots" "$@" || status=1
capture "$current" after 1920x1080 "$shots" "$@" || status=1
capture "$current" after-1280x800 1280x800 campfire,treasure "$@" || status=1
exit "$status"
