#!/bin/sh
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
out=${FX28_OUTPUT_ROOT:-/private/tmp/labyrinth_codex/fx-28}
stage=$(mktemp -d .godot/fx28-base.XXXXXX)
trap 'rm -rf "$stage"' EXIT
export LABYRINTH_CEL_LOOK=all PYTHONDONTWRITEBYTECODE=1

if [ "${1:-}" = --dry-run ]; then
    python3 tools/fx28/stage.py "$stage" --observe
    python3 tools/godot_task_runner.py --task-id fx-28 --stream -- godot --headless --fixed-fps 60 --path . \
        --script tools/fx28/verify.gd -- --out "$out/headless" --base-dir "res://$stage/before" --after-dir "res://$stage/after"
    exit
fi

python3 tools/fx28/stage.py "$stage"
capture() {
    revision=$1
    case_id=$2
    shift 2
    dir="$out/native/$revision/$case_id"
    mkdir -p "$dir"
    export FX15_CLOCK_FILE="$dir/clock.avi"
    python3 tools/visual_probe_runner.py tools/fx28/native.gd --task-id fx-28 \
        --no-headless --display-driver macos --audio-driver Dummy --godot tools/fx15/movie_clock.sh \
        --timeout 300 --expect-size 1920x1080 --proof-contract "tools/fx28/$contract" \
        --overwrite-result-manifest --result-manifest "$dir/manifest.json" -- --case "$case_id" --out "$dir" "$@"
    rm -f "$FX15_CLOCK_FILE"
    printf '%s\n' "$dir"
}

contract=strip_contract.json
for case_id in hero empty; do
    capture before "$case_id" --base-dir "res://$stage/before"
    capture after "$case_id" --base-dir "res://$stage/after"
done
contract=reel_contract.json
capture after recording --base-dir "res://$stage/after"
raw="$out/native/after/recording/frames.rgb"
clip="$out/native/slag-mortar-lob.mp4"
ffmpeg -nostdin -v error -y -f rawvideo -pixel_format rgb24 -video_size 1920x1080 \
    -framerate 60 -i "$raw" -frames:v 240 -an -c:v libx264 -pix_fmt yuv420p "$clip"
rm -f "$raw"
printf '%s\n' "$clip"
