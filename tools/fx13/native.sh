#!/bin/sh
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
OUT=${FX13_OUTPUT_ROOT:-/private/tmp/labyrinth_codex/fx-13/native}
export LABYRINTH_CEL_LOOK=all PYTHONDONTWRITEBYTECODE=1

capture() {
    take=$1
    shift
    dir="$OUT/$take"
    mkdir -p "$dir"
    export FX13_CLOCK_FILE="$dir/clock.avi"
    python3 tools/visual_probe_runner.py tools/fx13/native_capture.gd --task-id fx-13 \
        --no-headless --display-driver macos --audio-driver Dummy --godot tools/fx13/movie_clock.sh \
        --timeout 480 --proof-contract tools/fx13/proof_contract.json \
        --result-manifest "$dir/manifest.json" -- --case "$take" --out "$dir" "$@"
    rm -f "$FX13_CLOCK_FILE"
    if [ "$take" = "recording" ]; then
        ffmpeg -nostdin -v error -y -f rawvideo -pixel_format rgb24 -video_size 1920x1080 \
            -framerate 60 -i "$dir/frames.rgb" -frames:v 300 -c:v libx264 -pix_fmt yuv420p "$dir/brace-glass-mending-illusion-summon.mp4"
        rm -f "$dir/frames.rgb"
    fi
}

if [ "$#" -gt 0 ]; then
    capture "$@"
    exit
fi
for take in brace stone_plate glass_mending whetstone retaliate quicken mantle illusion guard_ally \
    enemy_heal tick_summon reinforcement expose_enemy expose_hero block_2x2 recording
do
    capture "$take"
done
