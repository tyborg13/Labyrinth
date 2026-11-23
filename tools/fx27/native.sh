#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
cd "$root"
out=${FX27_OUTPUT_ROOT:-/private/tmp/labyrinth_codex/fx-27}
capture_timeout=300
export LABYRINTH_CEL_LOOK=all PYTHONDONTWRITEBYTECODE=1 GIT_OPTIONAL_LOCKS=0
mkdir -p .godot
stage=$(mktemp -d .godot/fx27-base.XXXXXX)
trap 'python3 -c "import shutil,sys; shutil.rmtree(sys.argv[1])" "$stage"' EXIT
python3 tools/fx27/stage.py "$stage"
base_dir="res://$stage"

if [ "${1:-}" = --dry-run ]; then
    python3 tools/godot_task_runner.py --task-id fx-27 --stream -- godot --headless --fixed-fps 60 --path . \
        --script tools/fx27/verify.gd -- --out "$out/headless" --base-dir "$base_dir"
    exit
fi

capture() {
    revision=$1
    case_id=$2
    contract=$3
    shift 3
    dir="$out/native/$revision/$case_id"
    mkdir -p "$dir"
    export FX15_CLOCK_FILE="$dir/clock.avi"
    python3 tools/visual_probe_runner.py tools/fx27/native_capture.gd --task-id fx-27 \
        --no-headless --display-driver macos --audio-driver Dummy --godot tools/fx15/movie_clock.sh \
        --timeout "$capture_timeout" --expect-size 1920x1080 --proof-contract "tools/fx27/$contract" \
        --overwrite-result-manifest --result-manifest "$dir/manifest.json" -- --case "$case_id" --out "$dir" "$@"
    unlink "$FX15_CLOCK_FILE"
    printf '%s\n' "$dir"
}

for case_id in shade_bolt echo veil_needle area_ranged; do
    capture before "$case_id" proof_contract.json --base-dir "$base_dir"
    capture after "$case_id" proof_contract.json
done
capture after recording reel_contract.json
raw="$out/native/after/recording/frames.rgb"
clip="$out/native/hollow-mimic-shade-bolt.mp4"
ffmpeg -nostdin -v error -y -f rawvideo -pixel_format rgb24 -video_size 1920x1080 \
    -framerate 60 -i "$raw" -an -frames:v 240 -c:v libx264 -pix_fmt yuv420p "$clip"
unlink "$raw"
printf '%s\n' "$clip"
