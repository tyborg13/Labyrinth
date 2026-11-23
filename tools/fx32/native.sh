#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
cd "$root"
out=${FX32_OUTPUT_ROOT:-/private/tmp/labyrinth_codex/fx-32}
stage=$(mktemp -d "$root/.godot/fx32-base.XXXXXX")
trap 'rm -rf "$stage"' EXIT
export LABYRINTH_CEL_LOOK=all PYTHONDONTWRITEBYTECODE=1 GIT_OPTIONAL_LOCKS=0
python3 tools/fx32/stage.py "$stage"

if [ "${1:-}" = --dry-run ]; then
    shift
    printf '%s\n' "$out/headless/{before,after}/<case>/take.json" \
        "$out/native/{before,after}/{lodestone_reversal,cold_shoulder,root_snare,lash_hidden}/{strip.png,release.png,travel-third.png,travel-two-thirds.png,contact.png,contact-plus-100ms.png,contact-plus-233ms.png,take.json,manifest.json}" \
        "$out/native/after/recording/{lodestone_reversal-contact.png,cold_shoulder-contact.png,root_snare-contact.png,lash_hidden-contact.png,take.json,manifest.json}" \
        "$out/native/force-and-earth.mp4"
    python3 tools/godot_task_runner.py --task-id fx-32 --stream -- godot --headless --fixed-fps 60 \
        --path "$stage" --script tools/fx32/verify.gd -- --out "$out/headless/before" "$@"
    if [ "${FX32_BASE_ONLY:-0}" = 0 ]; then
        python3 tools/godot_task_runner.py --task-id fx-32 --stream -- godot --headless --fixed-fps 60 \
            --path "$root" --script tools/fx32/verify.gd -- --out "$out/headless/after" \
            --compare-before "$out/headless/before" "$@"
    fi
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
    python3 tools/visual_probe_runner.py tools/fx32/native_capture.gd --project "$project" --task-id fx-32 \
        --no-headless --display-driver macos --audio-driver Dummy --godot "$root/tools/fx15/movie_clock.sh" \
        --timeout 300 --expect-size 1920x1080 --proof-contract "$root/tools/fx32/$contract" \
        --overwrite-result-manifest --result-manifest "$dir/manifest.json" -- --case "$case_id" --out "$dir"
    rm -f "$FX15_CLOCK_FILE"
    printf '%s\n' "$dir"
}

for case_id in lodestone_reversal cold_shoulder root_snare lash_hidden; do
    capture before "$case_id" "$stage"
    capture after "$case_id" "$root"
done
capture after recording "$root"
raw="$out/native/after/recording/frames.rgb"
clip="$out/native/force-and-earth.mp4"
ffmpeg -nostdin -v error -y -f rawvideo -pixel_format rgb24 -video_size 1920x1080 \
    -framerate 60 -i "$raw" -an -frames:v 360 -c:v libx264 -pix_fmt yuv420p "$clip"
rm -f "$raw"
printf '%s\n' "$clip"
