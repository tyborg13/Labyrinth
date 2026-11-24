#!/bin/sh
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
root=$PWD

usage() {
    printf 'Usage: %s [--dry-run] [--release WORKTREE | --baseline MOUSE_JSON]\n' "$0" >&2
    exit 2
}

mode=native
release=
baseline=
while [ "$#" -gt 0 ]; do
    case "$1" in
        --dry-run) mode=headless; shift ;;
        --release) [ "$#" -ge 2 ] || usage; release=$2; shift 2 ;;
        --baseline) [ "$#" -ge 2 ] || usage; baseline=$2; shift 2 ;;
        *) usage ;;
    esac
done
if [ -n "$release" ]; then
    [ -z "$baseline" ] || usage
    release=$(CDPATH= cd -- "$release" && pwd)
    [ "$release" != "$root" ] && [ -f "$release/project.godot" ] || usage
fi

export LABYRINTH_CEL_LOOK=all
output_root=${POL82_OUTPUT_ROOT:-/private/tmp/labyrinth_codex/pol-82}
case "$output_root" in
    /*) ;;
    *) printf 'POL82_OUTPUT_ROOT must be absolute.\n' >&2; exit 2 ;;
esac
mkdir -p "$output_root"
output=$(mktemp -d "$output_root/$mode.XXXXXX")

run_probe() {
    project=$1
    destination=$2
    shift 2
    mkdir -p "$destination"
    if [ "$mode" = headless ]; then
        python3 tools/godot_task_runner.py --task-id pol-82 --stream -- godot --headless \
            --path "$project" --script "$root/tools/pol82/combat.gd" -- --dry-run --out "$destination" "$@"
    else
        python3 tools/visual_probe_runner.py "$root/tools/pol82/combat.gd" --project "$project" --task-id pol-82 \
            --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 \
            --proof-contract "$root/tools/pol82/proof.json" --result-manifest "$destination/renderer_manifest.json" \
            -- --out "$destination" "$@"
    fi
}

if [ -n "$release" ]; then
    printf 'POL-82 release revision %s\n' "$(git -C "$release" rev-parse --short HEAD)"
    run_probe "$release" "$output/release" --release-comparison
    baseline=$output/release/mouse.json
    output=$output/candidate
fi
if [ -n "$baseline" ]; then
    run_probe "$root" "$output" --baseline "$baseline"
else
    run_probe "$root" "$output"
fi
