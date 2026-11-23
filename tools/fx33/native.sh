#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
cd "$root"
out=${FX33_OUTPUT_ROOT:-/private/tmp/labyrinth_codex/fx-33}
capture_timeout=300
export LABYRINTH_CEL_LOOK=all PYTHONDONTWRITEBYTECODE=1 GIT_OPTIONAL_LOCKS=0
stage=$(mktemp -d "$root/.godot/fx33-proof.XXXXXX")
trap 'rm -rf "$stage"' EXIT
mkdir "$stage/before"

if [ "${1:-}" = "--dry-run" ]; then
    shift
    mkdir "$stage/after"
    python3 tools/fx33/stage.py "$stage/before" --before --instrument
    python3 tools/fx33/stage.py "$stage/after" --instrument
    printf '%s\n' "$out/headless/{before,after}/<case>/take.json" \
        "$out/native/{before,after}/{tick,chain_bolt,storm_relay,capacitor,spark_conduction}/{strip.png,native-evidence.png,take.json,manifest.json}" \
        "$out/native/after/recording/{burst-contact.png,chain-contact.png,take.json,manifest.json}" \
        "$out/native/ember-tick-then-chain-bolt.mp4"
    python3 tools/godot_task_runner.py --task-id fx-33 --stream -- godot --headless --fixed-fps 60 \
        --path "$stage/before" --script tools/fx33/verify.gd -- --out "$out/headless/before" --reel "$@"
    python3 tools/godot_task_runner.py --task-id fx-33 --stream -- godot --headless --fixed-fps 60 \
        --path "$stage/after" --script tools/fx33/verify.gd -- --out "$out/headless/after" \
        --compare-before "$out/headless/before" --reel "$@"
    exit
fi

mkdir "$stage/after"
python3 tools/fx33/stage.py "$stage/before" --before --instrument
python3 tools/fx33/stage.py "$stage/after" --instrument
capture() {
    revision=$1
    case_id=$2
    project=$3
    contract=$4
    dir="$out/native/$revision/$case_id"
    mkdir -p "$dir"
    export FX15_CLOCK_FILE="$dir/clock.avi"
    python3 tools/visual_probe_runner.py tools/fx33/native_capture.gd --project "$project" --task-id fx-33 \
        --no-headless --display-driver macos --audio-driver Dummy --godot "$root/tools/fx15/movie_clock.sh" \
        --timeout "$capture_timeout" --proof-contract "$root/tools/fx33/$contract" --overwrite-result-manifest \
        --result-manifest "$dir/manifest.json" -- --case "$case_id" --out "$dir"
    rm -f "$FX15_CLOCK_FILE"
    printf '%s\n' "$dir"
}

for case_id in tick chain_bolt storm_relay capacitor spark_conduction; do
    contract=chain_contract.json
    if [ "$case_id" = tick ]; then contract=proof_contract.json; fi
    capture before "$case_id" "$stage/before" "$contract"
    capture after "$case_id" "$stage/after" "$contract"
done
capture after recording "$root" reel_contract.json
raw="$out/native/after/recording/frames.rgb"
clip="$out/native/ember-tick-then-chain-bolt.mp4"
ffmpeg -nostdin -v error -y -f rawvideo -pixel_format rgb24 -video_size 1920x1080 \
    -framerate 60 -i "$raw" -an -frames:v 360 -c:v libx264 -pix_fmt yuv420p "$clip"
rm -f "$raw"
printf '%s\n' "$clip"
