#!/bin/sh
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
out=${FX21_OUTPUT_ROOT:-/private/tmp/labyrinth_codex/fx-21}
export LABYRINTH_CEL_LOOK=all PYTHONDONTWRITEBYTECODE=1

mode=native
if [ "${1:-}" = --dry-run ]; then
    shift
    mode=headless
fi
if [ "$#" -eq 0 ]; then
    set -- hero-hit crawler-hit empty-floor dark-hero-hit dark-crawler-hit dark-empty-floor family before
fi
for take in "$@"; do
    case "$take" in
        hero-hit|crawler-hit|empty-floor|dark-hero-hit|dark-crawler-hit|dark-empty-floor|family|before) ;;
        *) printf 'Unknown FX-21 take: %s\n' "$take" >&2; exit 2 ;;
    esac
    dir="$out/$mode/$take"
    mkdir -p "$dir"
    if [ "$mode" = headless ]; then
        python3 tools/godot_task_runner.py --task-id fx-21 --stream -- godot --headless --fixed-fps 60 --path . \
            --script tools/fx21/stills.gd -- --case "$take" --out "$dir" --plan
        continue
    fi
    export FX12_CLOCK_FILE="$dir/clock.avi"
    if [ "$take" = hero-hit ] || [ "$take" = family ]; then
        set -- --expect-size 1280x960 --min-images 3
    else
        set --
    fi
    python3 tools/visual_probe_runner.py tools/fx21/stills.gd --task-id fx-21 \
        --no-headless --display-driver macos --audio-driver Dummy --godot tools/fx12/movie_clock.sh \
        --timeout 120 --proof-contract tools/fx21/proof_contract.json --overwrite-result-manifest \
        --result-manifest "$dir/manifest.json" "$@" -- --case "$take" --out "$dir"
    rm -f "$FX12_CLOCK_FILE"
done
