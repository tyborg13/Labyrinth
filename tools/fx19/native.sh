#!/bin/sh
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
out=${FX19_OUTPUT_ROOT:-/private/tmp/labyrinth_codex/fx-19/native}
native_out=$out
base=7d1ba7df9
mode=native
if [ "${1:-}" = "--plan" ] || [ "${1:-}" = "--verify" ]; then
    mode=${1#--}
    shift
fi
if [ "$mode" != native ]; then out="$out/$mode"; fi
mkdir -p "$out"
export LABYRINTH_CEL_LOOK=all PYTHONDONTWRITEBYTECODE=1
git show "$base:scripts/run_scene.gd" > "$out/base-run.gd"
git show "$base:scripts/combat_board_view.gd" > "$out/base-board.gd"

capture() {
    group=$1
    take=$2
    motion=$3
    dir="$out/$group/$motion/$take"
    mkdir -p "$dir"
    set -- --case "$take" --out "$dir"
    if [ "$group" = base ]; then
        set -- "$@" --baseline-run-script "$out/base-run.gd" --baseline-board-script "$out/base-board.gd"
    fi
    if [ "$motion" = reduced ]; then set -- "$@" --reduced-motion; fi
    probe=tools/fx19/native_capture.gd
    if [ "$mode" = verify ] && [ "$group" = current ]; then
        probe=tools/fx19/verify.gd
        set -- "$@" --reference "$out/base/$motion/$take/take.json"
    fi
    if [ "$mode" != native ]; then
        python3 tools/godot_task_runner.py --task-id fx-19 --stream -- godot \
            --headless --fixed-fps 60 --path . --script "$probe" -- "$@" --plan
        if [ "$mode" = plan ]; then
            planned="$native_out/$group/$motion/$take"
            if [ "$take" = recording ]; then
                printf 'Planned %s\n' "$planned/two-blinks.mp4"
            else
                printf 'Planned %s\n' "$planned/strip.png"
            fi
            printf 'Planned %s\n' "$planned/native-evidence.png" "$planned/take.json" "$planned/manifest.json"
        fi
        return
    fi
    export FX19_CLOCK_FILE="$dir/clock.avi"
    if [ "$take" = recording ]; then
        set -- --min-images 1 --expect-size 1920x1080 -- "$@"
    else
        set -- --proof-contract tools/fx19/proof_contract.json -- "$@"
    fi
    python3 tools/visual_probe_runner.py "$probe" --task-id fx-19 \
        --no-headless --display-driver macos --audio-driver Dummy --godot tools/fx19/movie_clock.sh \
        --timeout 300 --result-manifest "$dir/manifest.json" "$@"
    rm -f "$FX19_CLOCK_FILE"
    if [ "$take" = recording ]; then
        ffmpeg -nostdin -v error -y -f rawvideo -pixel_format rgb24 -video_size 1920x1080 \
            -framerate 60 -i "$dir/frames.rgb" -frames:v 300 -c:v libx264 -pix_fmt yuv420p "$dir/two-blinks.mp4"
        rm -f "$dir/frames.rgb"
        printf '%s\n' "$dir/two-blinks.mp4"
    else
        printf '%s\n' "$dir/strip.png"
    fi
    printf '%s\n' "$dir/native-evidence.png" "$dir/take.json" "$dir/manifest.json"
}

if [ "$mode" = verify ]; then
    if [ "$#" -eq 0 ]; then set -- hero2 hero4 ghost_stride glassway shadowstep afterimage fade ambush; fi
    for take in "$@"; do
        for motion in full reduced; do
            capture base "$take" "$motion"
            capture current "$take" "$motion"
        done
    done
else
    if [ "$#" -eq 0 ]; then set -- hero3 glassway shadowstep recording; fi
    for take in "$@"; do
        if [ "$take" != recording ]; then capture base "$take" full; fi
        capture current "$take" full
    done
fi
