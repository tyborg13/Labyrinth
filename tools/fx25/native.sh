#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
cd "$root"
out=${FX25_OUTPUT_ROOT:-/private/tmp/labyrinth_codex/fx-25}
export LABYRINTH_CEL_LOOK=all PYTHONDONTWRITEBYTECODE=1 GIT_OPTIONAL_LOCKS=0
stage=$(mktemp -d "$root/.godot/fx25-base.XXXXXX")
trap 'rm -rf "$stage"' EXIT
python3 tools/fx25/stage.py "$stage"

if [ "${1:-}" = --dry-run ]; then
    shift
    printf '%s\n' "$out/headless/{before,after}/<case>/take.json" \
        "$out/native/{before,after}/<case>/{strip.png,native-evidence.png,take.json,manifest.json}" \
        "$out/native/after/recording/{area-contact.png,melee-contact.png,take.json,manifest.json}" \
        "$out/native/shadow-tendrils.mp4"
    python3 tools/godot_task_runner.py --task-id fx-25 --stream -- godot --headless --fixed-fps 60 \
        --path "$stage" --script tools/fx25/verify.gd -- --out "$out/headless/before" "$@"
    python3 tools/godot_task_runner.py --task-id fx-25 --stream -- godot --headless --fixed-fps 60 \
        --path "$root" --script tools/fx25/verify.gd -- --out "$out/headless/after" \
        --compare-before "$out/headless/before" "$@"
    exit
fi

capture() {
    revision=$1
    case_id=$2
    project=$3
    dir="$out/native/$revision/$case_id"
    contract=proof_contract.json
    if [ "$case_id" = recording ]; then contract=reel_contract.json; fi
    mkdir -p "$dir"
    export FX15_CLOCK_FILE="$dir/clock.avi"
    python3 tools/visual_probe_runner.py tools/fx25/native_capture.gd --project "$project" --task-id fx-25 \
        --no-headless --display-driver macos --audio-driver Dummy --godot "$root/tools/fx15/movie_clock.sh" \
        --timeout 300 --expect-size 1920x1080 --proof-contract "$root/tools/fx25/$contract" \
        --overwrite-result-manifest --result-manifest "$dir/manifest.json" -- --case "$case_id" --out "$dir"
    rm -f "$FX15_CLOCK_FILE"
    printf '%s\n' "$dir/take.json" "$dir/manifest.json"
    if [ "$case_id" = recording ]; then
        printf '%s\n' "$dir/area-contact.png" "$dir/melee-contact.png"
    else
        printf '%s\n' "$dir/strip.png" "$dir/native-evidence.png"
    fi
}

record=false
if [ "$#" -eq 0 ]; then
    record=true
    set -- area_ranged closing_shade veil_needle
fi
for case_id in "$@"; do
    capture before "$case_id" "$stage"
    capture after "$case_id" "$root"
done
if [ "$record" = true ]; then
    capture after recording "$root"
    raw="$out/native/after/recording/frames.rgb"
    clip="$out/native/shadow-tendrils.mp4"
    ffmpeg -nostdin -v error -y -f rawvideo -pixel_format rgb24 -video_size 1920x1080 \
        -framerate 60 -i "$raw" -an -frames:v 240 -c:v libx264 -pix_fmt yuv420p "$clip"
    rm -f "$raw"
    printf '%s\n' "$clip"
fi
