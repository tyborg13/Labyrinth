#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
cd "$root"
out=${FX34_OUTPUT_ROOT:-/private/tmp/labyrinth_codex/fx-34}
capture_timeout=300
fps=60
part_frames=180
export LABYRINTH_CEL_LOOK=all PYTHONDONTWRITEBYTECODE=1 GIT_OPTIONAL_LOCKS=0
stage=$(mktemp -d "$root/.godot/fx34-proof.XXXXXX")
trap 'rm -rf "$stage"' EXIT
mkdir "$stage/before"
dir="$out/native"
clip="$dir/after/spark-then-missed-gear.mp4"

if [ "${1:-}" = "--dry-run" ]; then
    shift
    mkdir "$stage/after"
    python3 tools/fx34/stage.py "$stage/before" --before --instrument
    python3 tools/fx34/stage.py "$stage/after" --instrument
    printf '%s\n' "$out/headless/{before,after}/<case>/take.json" \
        "$dir/{before,after}/{spark,missed}/{strip.png,native-evidence.png,take.json,manifest.json}" "$clip"
    python3 tools/godot_task_runner.py --task-id fx-34 --stream -- godot --headless --fixed-fps "$fps" \
        --path "$stage/before" --script tools/fx34/verify.gd -- --baseline --out "$out/headless/before" "$@"
    python3 tools/godot_task_runner.py --task-id fx-34 --stream -- godot --headless --fixed-fps "$fps" \
        --path "$stage/after" --script tools/fx34/verify.gd -- --out "$out/headless/after" \
        --compare-before "$out/headless/before" "$@"
    exit
fi

python3 tools/fx34/stage.py "$stage/before" --before
capture() {
    take_dir=$1
    case_id=$2
    project=$3
    shift 3
    mkdir -p "$take_dir"
    export FX15_CLOCK_FILE="$take_dir/clock.avi"
    python3 tools/visual_probe_runner.py tools/fx34/native_capture.gd --project "$project" --task-id fx-34 \
        --no-headless --display-driver macos --audio-driver Dummy --godot "$root/tools/fx15/movie_clock.sh" \
        --timeout "$capture_timeout" --proof-contract "$root/tools/fx34/proof_contract.json" --overwrite-result-manifest \
        --result-manifest "$take_dir/manifest.json" -- --case "$case_id" --out "$take_dir" "$@"
    printf '%s\n' "$take_dir"
}

for case_id in spark missed; do
    capture "$dir/before/$case_id" "$case_id" "$stage/before" --baseline
    rm -f "$dir/before/$case_id/clock.avi"
    take_dir="$dir/after/$case_id"
    capture "$take_dir" "$case_id" "$root" --record
    audio_start=$(python3 -c 'import json, sys; print(json.load(open(sys.argv[1]))["movie_first_frame"] / int(sys.argv[2]))' "$take_dir/take.json" "$fps")
    ffmpeg -nostdin -v error -y -f rawvideo -pixel_format rgb24 -video_size 1920x1080 -framerate "$fps" \
        -i "$take_dir/frames.rgb" -ss "$audio_start" -i "$take_dir/clock.avi" -map 0:v:0 -map 1:a:0 \
        -af apad -t "$((part_frames / fps))" -frames:v "$part_frames" -c:v libx264 -pix_fmt yuv420p \
        -c:a aac "$take_dir/segment.mp4"
    rm -f "$take_dir/frames.rgb" "$take_dir/clock.avi"
done
printf '%s\n' "file 'spark/segment.mp4'" "file 'missed/segment.mp4'" > "$dir/after/segments.txt"
ffmpeg -nostdin -v error -y -f concat -safe 0 -i "$dir/after/segments.txt" -c copy -movflags +faststart "$clip"
printf '%s\n' "$clip"
