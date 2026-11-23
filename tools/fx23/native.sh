#!/bin/sh
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
out=${FX23_OUTPUT_ROOT:-/private/tmp/labyrinth_codex/fx-23}
stage=$(mktemp -d .godot/fx23-base.XXXXXX)
trap 'rm -rf "$stage"' EXIT
export LABYRINTH_CEL_LOOK=all PYTHONDONTWRITEBYTECODE=1

if [ "${1:-}" = --dry-run ]; then
    shift
    python3 tools/fx23/stage.py "$stage" --observe
    mkdir -p "$out/headless"
    printf 'FX-23 HEADLESS: %s\nFX-23 NATIVE OUTPUT: %s\nFX-23 REEL: %s\n' \
        "$out/headless" "$out/native/{before,after}/<case>/{strip.png,take.json,manifest.json}" "$out/native/fire-lightning.mp4"
    python3 tools/godot_task_runner.py --task-id fx-23 --stream -- godot --headless --fixed-fps 60 --path . \
        --script tools/fx23/verify.gd -- --out "$out/headless" --base-dir "res://$stage/before" --after-dir "res://$stage/after" "$@"
    exit
fi

python3 tools/fx23/stage.py "$stage"
capture() {
    revision=$1
    case_id=$2
    shift 2
    dir="$out/native/$revision/$case_id"
    contract=tools/fx23/proof_contract.json
    if [ "$case_id" = recording ]; then contract=tools/fx23/reel_contract.json; fi
    mkdir -p "$dir"
    export FX15_CLOCK_FILE="$dir/clock.avi"
    python3 tools/visual_probe_runner.py tools/fx23/native.gd --task-id fx-23 \
        --no-headless --display-driver macos --audio-driver Dummy --godot tools/fx15/movie_clock.sh \
        --timeout 300 --expect-size 1920x1080 --proof-contract "$contract" --overwrite-result-manifest \
        --result-manifest "$dir/manifest.json" -- --case "$case_id" --out "$dir" "$@"
    rm -f "$FX15_CLOCK_FILE"
    printf '%s\n' "$dir/take.json" "$dir/manifest.json"
    if [ "$case_id" != recording ]; then printf '%s\n' "$dir/strip.png" "$dir/native-evidence.png"; fi
}

record=false
if [ "$#" -eq 0 ]; then
    record=true
    inventory=$(python3 tools/godot_task_runner.py --task-id fx-23 --stream -- godot --headless --path . \
        --script tools/fx23/verify.gd -- --list-cases)
    set -- $(printf '%s\n' "$inventory" | sed -n 's/^FX-23 CASES: //p')
    test "$#" -gt 0
fi
for case_id in "$@"; do
    capture before "$case_id" --base-dir "res://$stage/before"
    capture after "$case_id"
done
if [ "$record" = true ]; then
    capture after recording
    raw="$out/native/after/recording/frames.rgb"
    clip="$out/native/fire-lightning.mp4"
    ffmpeg -nostdin -v error -y -f rawvideo -pixel_format rgb24 -video_size 1920x1080 \
        -framerate 60 -i "$raw" -frames:v 240 -c:v libx264 -pix_fmt yuv420p "$clip"
    rm -f "$raw"
    printf '%s\n' "$clip"
fi
