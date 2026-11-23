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
cd "$(dirname "$launcher")/../.."

tool_output=/private/tmp/labyrinth_codex/scn-02
if [ "$#" -gt 1 ] || { [ "$#" -eq 1 ] && [ "$1" != --dry-run ]; }; then
    printf 'Usage: %s [--dry-run]\n' "$0" >&2
    exit 2
fi
if [ "$#" -eq 1 ]; then
    # Concurrent headless startups can spend over a minute loading RunScene.
    export SCN01_ENGINE_TIMEOUT=180
fi
output="$tool_output/$(python3 -c 'from datetime import datetime, timezone; print(datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ"))')"
printf 'Output folder: %s\n' "$output"
SCN01_TASK_ID=scn-02 exec python3 tools/scn01/census.py --only reward,campfire,treasure,scavenger \
    --size 1920x1080 --out "$output" "$@"
