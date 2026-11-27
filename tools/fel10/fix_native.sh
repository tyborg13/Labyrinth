#!/usr/bin/env bash
set -euo pipefail

tool_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project="$(cd "$tool_dir/../.." && pwd)"
cd "$project"
script=tools/fel10/pickup_fix/capture.gd
release="$(cd "${FEL10_RELEASE_PROJECT:-$project/../release}" && pwd)"
timeout=240

case "$#:${1:-}" in
    0:) mode=native ;;
    1:--dry-run) mode=dry ;;
    *) printf 'Usage: %s [--dry-run]\n' "$0" >&2; exit 2 ;;
esac

release_head="$(git --no-optional-locks -C "$release" rev-parse HEAD)"
if [[ -n "$(git --no-optional-locks -C "$release" status --porcelain --untracked-files=no)" ]]; then
    printf 'FEL10 FIX needs a clean release checkout at %s\n' "$release" >&2
    exit 1
fi
if [[ "$mode" == native ]]; then
    command -v ffmpeg >/dev/null
    command -v ffprobe >/dev/null
fi

mkdir -p "$tool_dir/captures"
touch "$tool_dir/captures/.gdignore"
out="$(mktemp -d "$tool_dir/captures/fix-$mode.XXXXXX")"
mkdir "$out/release" "$out/branch" "$out/movie"
release_copy="$out/release-project"
export LABYRINTH_CEL_LOOK=all FEL10_FIX_OUTPUT="$out"
export FEL10_FIX_CHECKPOINT="$tool_dir/fixtures/campaign-seed-000010-turn-000001"
export FX15_CLOCK_FILE="$out/stills-clock.avi" FEL10_FIX_CLOCK="$out/movie-clock.avi"
cleanup() {
    rm -rf -- "$release_copy"
    rm -f -- "$FX15_CLOCK_FILE" "$FEL10_FIX_CLOCK"
}
trap cleanup EXIT

printf 'FEL10 FIX output=%s release=%s\n' "$out" "$release_head"
printf '%s\n' "$release_head" > "$out/release-revision.txt"
cp -cRp "$release" "$release_copy"

# Copy the same replay driver into the clone without changing its production files.
for file in tools/fel01/checkpoint.gd tools/fel01/policy.gd \
    tools/fel10/combat_inputs.gd "$script" tools/fel10/pickup_fix/media.gd; do
    mkdir -p "$release_copy/$(dirname "$file")"
    cp -p "$project/$file" "$release_copy/$file"
done

headless() {
    local repo="$1" fps="$2"
    python3 tools/godot_task_runner.py --task-id fel-10 --timeout "$timeout" --stream -- \
        godot --headless --fixed-fps "$fps" --path "$repo" --script "$repo/$script"
}

native() {
    local repo="$1" wrapper="$2" contract="$3" destination="$4" min_images="$5"
    shift 5
    python3 tools/visual_probe_runner.py "$repo/$script" --task-id fel-10 --project "$repo" \
        --no-headless --display-driver macos --audio-driver Dummy --godot "$project/$wrapper" \
        --timeout "$timeout" --expect-size 1920x1080 --min-images "$min_images" \
        --proof-contract "$tool_dir/pickup_fix/$contract" --result-manifest "$destination/visual-proof.json" "$@"
}

export FEL10_FIX_PASS=stills FEL10_FIX_SIDE=release
if [[ "$mode" == dry ]]; then
    headless "$release_copy" 60 2>&1 | tee "$out/release/runner.log"
    export FEL10_FIX_SIDE=branch
    headless "$project" 60 2>&1 | tee "$out/branch/runner.log"
    export FEL10_FIX_PASS=reduced
    headless "$project" 60 2>&1 | tee "$out/branch/reduced.log"
    export FEL10_FIX_PASS=movie
    headless "$project" 30 2>&1 | tee "$out/movie/runner.log"
    printf 'FEL10 FIX DRY RUN PASS sides=2 strip_frames_each=12 midpoint_pair=planned trail_crop=4x movie=1920x1080@30\n'
    exit 0
fi

native "$release_copy" tools/fx15/movie_clock.sh stills_contract.json "$out/release" 2 2>&1 | tee "$out/release/runner.log"
rm -f -- "$FX15_CLOCK_FILE"
export FEL10_FIX_SIDE=branch
native "$project" tools/fx15/movie_clock.sh stills_contract.json "$out/branch" 4 2>&1 | tee "$out/branch/runner.log"

export FEL10_FIX_PASS=movie
native "$project" tools/fel10/pickup_fix/movie_clock.sh movie_contract.json "$out/movie" 2 -- --fixed-fps 30 \
    2>&1 | tee "$out/movie/runner.log"
clip="$out/movie/loot_pickup.mp4"
ffmpeg -nostdin -v error -f rawvideo -pixel_format rgb24 -video_size 1920x1080 -framerate 30 \
    -i "$out/movie/frames.rgb" -c:v libx264 -pix_fmt yuv420p -crf 18 -movflags +faststart "$clip"
[[ "$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height,r_frame_rate -of csv=p=0 "$clip")" == "1920,1080,30/1" ]]
rm -- "$out/movie/frames.rgb"
printf 'FEL10 FIX NATIVE PASS output=%s movie=%s\n' "$out" "$clip"
