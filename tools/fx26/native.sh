#!/bin/sh
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
out=${FX26_OUTPUT_ROOT:-/private/tmp/labyrinth_codex/fx-26}
stage=$(mktemp -d .godot/fx26-base.XXXXXX)
trap 'rm -rf "$stage"' EXIT
export LABYRINTH_CEL_LOOK=all PYTHONDONTWRITEBYTECODE=1

if [ "${1:-}" = --dry-run ]; then
    shift
    python3 tools/fx26/stage.py "$stage" --observe
    mkdir -p "$out/headless"
    printf 'FX-26 HEADLESS: %s\nFX-26 NATIVE OUTPUT: %s\nFX-26 REEL: %s\n' \
        "$out/headless/{before,after}/<case>/take.json" "$out/native/{before,after}/<case>/{strip.png,take.json,manifest.json}" "$out/native/chain-ice.mp4"
    python3 tools/godot_task_runner.py --task-id fx-26 --stream -- godot --headless --fixed-fps 60 --path . \
        --script tools/fx26/verify.gd -- --out "$out/headless" --base-dir "res://$stage/before" --after-dir "res://$stage/after" "$@"
    exit
fi

python3 tools/fx26/stage.py "$stage"
capture() {
    revision=$1
    case_id=$2
    shift 2
    dir="$out/native/$revision/$case_id"
    contract=tools/fx23/proof_contract.json
    case "$case_id" in
        chain) contract=tools/fx26/chain_contract.json ;;
        recording) contract=tools/fx26/reel_contract.json ;;
    esac
    mkdir -p "$dir"
    export FX15_CLOCK_FILE="$dir/clock.avi"
    python3 tools/visual_probe_runner.py tools/fx26/native.gd --task-id fx-26 \
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
    inventory=$(python3 tools/godot_task_runner.py --task-id fx-26 --stream -- godot --headless --path . \
        --script tools/fx26/verify.gd -- --list-native)
    set -- $(printf '%s\n' "$inventory" | sed -n 's/^FX-26 NATIVE CASES: //p')
    test "$#" -gt 0
fi
for case_id in "$@"; do
    capture before "$case_id" --base-dir "res://$stage/before"
    capture after "$case_id"
done
if [ "$record" = true ]; then
    capture after recording
    raw="$out/native/after/recording/frames.rgb"
    clip="$out/native/chain-ice.mp4"
    ffmpeg -nostdin -v error -y -f rawvideo -pixel_format rgb24 -video_size 1920x1080 \
        -framerate 60 -i "$raw" -frames:v 300 -an -c:v libx264 -pix_fmt yuv420p "$clip"
    rm -f "$raw"
    printf '%s\n' "$clip"
fi
