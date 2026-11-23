#!/bin/sh
set -eu

case "${1:-}" in
    ""|--dry-run) ;;
    *) printf 'Usage: %s [--dry-run]\n' "$0" >&2; exit 2 ;;
esac
if [ "$#" -gt 1 ] || [ ! -f tools/pol65/measure.gd ]; then
    printf 'Run from the pol-65 worktree. Usage: %s [--dry-run]\n' "$0" >&2
    exit 2
fi

WORKTREE=$(pwd -P)
OUTPUT_ROOT=/private/tmp/labyrinth_codex/pol-65
SHOTS=boss,dragon_tharokh,dragon_vyraketh,dragon_vaeloryx,dragon_iskaldra,dragon_zekarion,dragon_noctyrax
mkdir -p "$OUTPUT_ROOT"
OUTPUT=$(mktemp -d "$OUTPUT_ROOT/census.XXXXXX")

census() (
    cd "$1"
    size=$2
    folder=$3
    shift 3
    printf 'Census %s: %s\n' "$size" "$folder"
    SCN01_TASK_ID=pol-65 python3 tools/scn01/census.py --only "$SHOTS" --size "$size" --out "$folder" "$@"
)

status=0
census "$WORKTREE/../scn-02" 1280x800 "$OUTPUT/before-1280x800" "$@" || status=1
census "$WORKTREE" 1280x800 "$OUTPUT/after-1280x800" "$@" || status=1
census "$WORKTREE" 1920x1080 "$OUTPUT/after-1920x1080" "$@" || status=1
printf 'Census output folders:\n'
printf '  %s\n' "$OUTPUT/before-1280x800" "$OUTPUT/after-1280x800" "$OUTPUT/after-1920x1080"
exit "$status"
