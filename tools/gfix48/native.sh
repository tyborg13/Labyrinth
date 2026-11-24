#!/bin/sh
set -eu
root=$PWD
output=${GFIX48_OUTPUT_ROOT:-/private/tmp/labyrinth_codex/gfix-48}
case "${1:-}" in
    --dry-run) mode=headless ;;
    "") mode=native ;;
    *) printf 'Usage: %s [--dry-run]\n' "$0" >&2; exit 2 ;;
esac
case "$output" in
    /*) ;;
    *) printf 'GFIX48_OUTPUT_ROOT must be an absolute path.\n' >&2; exit 2 ;;
esac
export LABYRINTH_CEL_LOOK=all GIT_OPTIONAL_LOCKS=0 PYTHONDONTWRITEBYTECODE=1
mkdir -p "$output"
captures=$(mktemp -d "$output/$mode.XXXXXX")
script="$root/tools/gfix48/scene_probe.gd"
printf 'GFIX-48 output: %s\n' "$captures"
if [ "$mode" = headless ]; then
    python3 tools/godot_task_runner.py --task-id gfix-48 --stream -- godot \
        --headless --fixed-fps 100 --path "$root" --script "$script" -- --dry-run --out "$captures"
    printf 'GFIX-48 NATIVE DRY RUN PASS — %s\n' "$captures"
else
    native_timeout=300
    python3 tools/visual_probe_runner.py "$script" --project "$root" --task-id gfix-48 \
        --godot "$root/tools/gfix48/fixed_clock.sh" \
        --no-headless --display-driver macos --audio-driver CoreAudio --timeout "$native_timeout" \
        --expect-size 1920x1080 --proof-contract "$root/tools/gfix48/proof.json" \
        --result-manifest "$captures/manifest.json" -- --out "$captures"
fi
