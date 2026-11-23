#!/bin/sh
set -eu

project=$(CDPATH='' cd "$(dirname "$0")/../.." && pwd)
cd "$project"
base="${POL68_BASE_PROJECT:-$project/../pol-67}"
base_head=$(git -C "$base" rev-parse HEAD)
expected_head=$(git rev-parse codex/pol-67)
if [ "$base_head" != "$expected_head" ]; then
    echo "Expected codex/pol-67 at $base, found $base_head" >&2
    exit 1
fi

mode=
out="/private/tmp/labyrinth_codex/pol-68/$(date -u +%Y%m%dT%H%M%SZ)-$$"
while [ "$#" -gt 0 ]; do
    case "$1" in
        --dry-run) mode=--dry-run; shift ;;
        --out) out=$2; shift 2 ;;
        *) echo "Usage: $0 [--dry-run] [--out FRESH_DIRECTORY]" >&2; exit 2 ;;
    esac
done
mkdir -p "$out"
out=$(CDPATH='' cd "$out" && pwd)
export LABYRINTH_CEL_LOOK=all
export SCN01_TASK_ID=pol-68
shots=title,new_run_replacement,new_run_depth,new_run_loading,new_run_opening_dialogue,start,pre_battle,character,campfire,combat
compare=title,combat
printf 'pol-68 output folder: %s\n' "$out"

census() {
    python3 tools/scn01/census.py --root-window --rects --no-contact-sheet "$@"
}

# Use the same probe and fixtures against both game projects.
census ${mode:+$mode} --project "$base" --size 1280x800 --ui-scale 1.15 --only "$shots" --out "$out/before-1280x800-115"
census ${mode:+$mode} --size 1280x800 --ui-scale 1.15 --only "$shots" --out "$out/after-1280x800-115"
census ${mode:+$mode} --size 1920x1080 --only "$shots" --out "$out/after-1920x1080-100"
if [ "$mode" = --dry-run ]; then
    census --dry-run --project "$base" --size 1280x800 --only "$shots" --out "$out/before-1280x800-100"
    census --dry-run --size 1280x800 --only "$shots" --out "$out/after-1280x800-100"
    census --dry-run --project "$base" --size 1920x1080 --only "$shots" --out "$out/before-1920x1080-100"
    python3 tools/pol68/compare_rects.py --shots "$shots" \
        "$out/before-1920x1080-100/manifest.json" "$out/after-1920x1080-100/manifest.json"
else
    census --dry-run --size 1280x800 --ui-scale 1.15 --only "$compare" --out "$out/reference-1280x800-115"
    python3 tools/pol68/compare_rects.py --native --shots "$compare" \
        "$out/reference-1280x800-115/manifest.json" "$out/after-1280x800-115/manifest.json"
fi
printf 'pol-68 output folder: %s\n' "$out"
