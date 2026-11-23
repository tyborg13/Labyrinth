#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
cd "$root"
out=${FX36_OUTPUT_ROOT:-/private/tmp/labyrinth_codex/fx-36}
capture_timeout=300
fps=60
part_frames=180
cases="chain_bolt storm_relay capacitor"
export LABYRINTH_CEL_LOOK=all PYTHONDONTWRITEBYTECODE=1 GIT_OPTIONAL_LOCKS=0
stage=$(mktemp -d "$root/.godot/fx36-proof.XXXXXX")
trap 'rm -rf "$stage"' EXIT

python3 tools/fx36/stage.py "$root"
python3 tools/fx36/stage.py "$stage/old" --revision codex/mrg-14
python3 tools/fx36/stage.py "$stage/fx33" --revision codex/fx-34
python3 tools/fx36/stage.py "$stage/now"

if [ "${1:-}" = "--dry-run" ]; then
    dir="$out/headless"
    printf 'FX-36 headless output %s\n' "$dir"
    for revision in old fx33; do
        for case_id in $cases; do
            set --
            if [ "$revision" = old ] && [ "$case_id" = capacitor ]; then set -- --legacy-flight; fi
            python3 tools/godot_task_runner.py --task-id fx-36 --stream -- godot --headless --fixed-fps "$fps" \
                --path "$stage/$revision" --script tools/fx36/native_capture.gd -- --plan --case "$case_id" --out "$dir/$revision/$case_id" "$@"
        done
    done
    python3 tools/godot_task_runner.py --task-id fx-36 --stream -- godot --headless --fixed-fps "$fps" \
        --path "$stage/now" --script tools/fx36/verify.gd -- --out "$dir/now" --record
    python3 tools/fx36/compare.py "$dir" --dry-run
    printf 'FX-36 native output plan %s\n' "$out/native"
    exit
fi

dir="$out/native"
capture() {
    take_dir=$1
    case_id=$2
    project=$3
    shift 3
    mkdir -p "$take_dir"
    export FX15_CLOCK_FILE="$take_dir/clock.avi"
    python3 tools/visual_probe_runner.py tools/fx36/native_capture.gd --project "$project" --task-id fx-36 \
        --no-headless --display-driver macos --audio-driver Dummy --godot "$root/tools/fx15/movie_clock.sh" \
        --timeout "$capture_timeout" --proof-contract "$root/tools/fx36/proof_contract.json" --overwrite-result-manifest \
        --result-manifest "$take_dir/manifest.json" -- --case "$case_id" --out "$take_dir" "$@"
}

for case_id in $cases; do
    for revision in old fx33; do
        set --
        if [ "$revision" = old ] && [ "$case_id" = capacitor ]; then set -- --legacy-flight; fi
        capture "$dir/$revision/$case_id" "$case_id" "$stage/$revision" "$@"
        rm -f "$dir/$revision/$case_id/clock.avi"
    done
    take_dir="$dir/now/$case_id"
    capture "$take_dir" "$case_id" "$stage/now" --record
    audio_start=$(python3 -c 'import json, sys; print(json.load(open(sys.argv[1]))["movie_first_frame"] / int(sys.argv[2]))' "$take_dir/take.json" "$fps")
    ffmpeg -nostdin -v error -y -f rawvideo -pixel_format rgb24 -video_size 1920x1080 -framerate "$fps" \
        -i "$take_dir/frames.rgb" -ss "$audio_start" -i "$take_dir/clock.avi" -map 0:v:0 -map 1:a:0 \
        -af apad -t "$((part_frames / fps))" -frames:v "$part_frames" -c:v libx264 -pix_fmt yuv420p \
        -c:a aac "$take_dir/segment.mp4"
    rm -f "$take_dir/frames.rgb" "$take_dir/clock.avi"
done
python3 tools/fx36/compare.py "$dir"
clip="$dir/chain-bolt-storm-relay-arc-lash.mp4"
for case_id in $cases; do printf "file '%s/segment.mp4'\n" "$case_id"; done > "$dir/now/segments.txt"
ffmpeg -nostdin -v error -y -f concat -safe 0 -i "$dir/now/segments.txt" -c copy -movflags +faststart "$clip"
printf '%s\n' "$clip" "$dir"
