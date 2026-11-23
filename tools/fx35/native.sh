#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
cd "$root"
out=${FX35_OUTPUT_ROOT:-/private/tmp/labyrinth_codex/fx-35}
export LABYRINTH_CEL_LOOK=all PYTHONDONTWRITEBYTECODE=1 GIT_OPTIONAL_LOCKS=0
mode=native
if [ "${1:-}" = --dry-run ]; then
    mode=headless
    shift
fi
if [ "$#" -ne 0 ]; then
    printf 'Usage: %s [--dry-run]\n' "$0" >&2
    exit 2
fi
mkdir -p "$root/.godot"
stage=$(mktemp -d "$root/.godot/fx35-proof.XXXXXX")
trap 'rm -rf "$stage"' EXIT
python3 tools/fx35/stage.py "$stage"
printf 'FX-35 PROOF OUTPUT %s\n' "$out/$mode"

for revision in before after; do
    project="$stage/$revision"
    for case_id in area_ranged closing_shade; do
        dir="$out/$mode/$revision/$case_id"
        mkdir -p "$dir"
        if [ "$mode" = headless ]; then
            python3 tools/godot_task_runner.py --task-id fx-35 --stream -- godot --headless --fixed-fps 60 \
                --path "$project" --script tools/fx35/native_capture.gd -- --plan --case "$case_id" --out "$dir"
            continue
        fi
        export FX15_CLOCK_FILE="$dir/clock.avi"
        python3 tools/visual_probe_runner.py tools/fx35/native_capture.gd --project "$project" --task-id fx-35 \
            --no-headless --display-driver macos --audio-driver Dummy --godot "$root/tools/fx15/movie_clock.sh" \
            --timeout 300 --expect-size 1920x1080 --proof-contract "$root/tools/fx35/proof_contract.json" \
            --overwrite-result-manifest --result-manifest "$dir/manifest.json" -- --case "$case_id" --out "$dir"
        clip="$dir/clip.mp4"
        ffmpeg -nostdin -v error -y -f rawvideo -pixel_format rgb24 -video_size 1920x1080 -framerate 60 \
            -i "$dir/frames.rgb" -an -c:v libx264 -pix_fmt yuv420p "$clip"
        rm -f "$dir/frames.rgb" "$FX15_CLOCK_FILE"
        printf '%s\n' "$dir/take.json" "$dir/manifest.json" "$clip"
    done
done
if [ "$mode" = headless ]; then
    python3 tools/fx35/verify_takes.py "$out/$mode"
fi
