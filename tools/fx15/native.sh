#!/bin/sh
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
out=${FX15_OUTPUT_ROOT:-/private/tmp/labyrinth_codex/fx-15/native}
export LABYRINTH_CEL_LOOK=all PYTHONDONTWRITEBYTECODE=1

capture() {
    take=$1
    shift
    dir="$out/$take"
    mkdir -p "$dir"
    export FX15_CLOCK_FILE="$dir/clock.avi"
    python3 tools/visual_probe_runner.py tools/fx15/native_capture.gd --task-id fx-15 \
        --no-headless --display-driver macos --audio-driver Dummy --godot tools/fx15/movie_clock.sh \
        --timeout 300 --proof-contract tools/fx15/proof_contract.json \
        --result-manifest "$dir/manifest.json" -- --case "$take" --out "$dir" "$@"
    rm -f "$FX15_CLOCK_FILE"
    printf '%s\n' "$dir/strip.png" "$dir/native-evidence.png" "$dir/take.json" "$dir/manifest.json"
}

if [ "$#" -gt 0 ]; then
    for take in "$@"; do capture "$take"; done
    exit
fi
for take in skybreak board_rule zekarion vyraketh meteorfall icefall occlusion half_hidden; do
    case "$take" in
        skybreak|meteorfall|icefall) capture "$take" --record-part ;;
        *) capture "$take" ;;
    esac
done
cat "$out/skybreak/frames.rgb" "$out/meteorfall/frames.rgb" "$out/icefall/frames.rgb" |
    ffmpeg -nostdin -v error -y -f rawvideo -pixel_format rgb24 -video_size 1920x1080 \
        -framerate 60 -i - -frames:v 300 -c:v libx264 -pix_fmt yuv420p "$out/skybreak-meteorfall-icefall.mp4"
rm -f "$out/skybreak/frames.rgb" "$out/meteorfall/frames.rgb" "$out/icefall/frames.rgb"
printf '%s\n' "$out/skybreak-meteorfall-icefall.mp4"
