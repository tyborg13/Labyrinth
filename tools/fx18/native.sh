#!/bin/sh
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
out=${FX18_OUTPUT_ROOT:-/private/tmp/labyrinth_codex/fx-18}
base=7d1ba7df9
staging=$(mktemp -d .godot/fx18-base.XXXXXX)
trap 'rm -rf "$staging"' EXIT
export LABYRINTH_CEL_LOOK=all PYTHONDONTWRITEBYTECODE=1

# Stage the base scripts without swapping the desktop worktree's sources.
git show "$base:scripts/run_scene.gd" > "$staging/run_scene.gd"
git show "$base:scripts/dragon_shadow_fx.gd" > "$staging/dragon_shadow_fx.gd"
git show "$base:scripts/dragon_spell_presentation.gd" | sed \
    -e "s|res://scripts/dragon_shadow_fx.gd|res://$staging/dragon_shadow_fx.gd|g" > "$staging/dragon_spell_presentation.gd"
git show "$base:scripts/combat_board_view.gd" | sed \
    -e '/^class_name CombatBoardView$/d' \
    -e "s|res://scripts/dragon_spell_presentation.gd|res://$staging/dragon_spell_presentation.gd|g" \
    -e "s|res://scripts/combat_board_view.gd|res://$staging/combat_board_view.gd|g" > "$staging/combat_board_view.gd"
base_dir="res://$staging"

if [ "${1:-}" = --dry-run ]; then
    shift
    mkdir -p "$out/headless"
    python3 tools/godot_task_runner.py --task-id fx-18 --stream -- godot --headless --fixed-fps 60 --path . \
        --script tools/fx18/verify.gd -- --out "$out/headless" --base-dir "$base_dir" "$@"
    exit
fi

capture() {
    revision=$1
    case_id=$2
    shift 2
    dir="$out/native/$revision/$case_id"
    mkdir -p "$dir"
    export FX15_CLOCK_FILE="$dir/clock.avi"
    python3 tools/visual_probe_runner.py tools/fx18/native_capture.gd --task-id fx-18 \
        --no-headless --display-driver macos --audio-driver Dummy --godot tools/fx15/movie_clock.sh \
        --timeout 300 --proof-contract tools/fx18/proof_contract.json --overwrite-result-manifest \
        --result-manifest "$dir/manifest.json" -- --case "$case_id" --out "$dir" "$@"
    rm -f "$FX15_CLOCK_FILE"
    printf '%s\n' "$dir/strip.png" "$dir/native-evidence.png" "$dir/take.json" "$dir/manifest.json"
}

recording=false
if [ "$#" -eq 0 ]; then
    recording=true
    set -- cinder_breath crownfire bedrock_breath faultline hollow_gale whiteout_lance shatterstorm overload storm_lash starless_breath
fi
for case_id in "$@"; do
    capture before "$case_id" --base-dir "$base_dir"
    if [ "$recording" = true ] && { [ "$case_id" = cinder_breath ] || [ "$case_id" = whiteout_lance ]; }; then
        capture after "$case_id" --record-part
    else
        capture after "$case_id"
    fi
done
if [ "$recording" = true ]; then
    after="$out/native/after"
    clip="$out/native/cinder-breath-whiteout-lance.mp4"
    cat "$after/cinder_breath/frames.rgb" "$after/whiteout_lance/frames.rgb" |
        ffmpeg -nostdin -v error -y -f rawvideo -pixel_format rgb24 -video_size 1920x1080 \
        -framerate 60 -i - -frames:v 300 -c:v libx264 -pix_fmt yuv420p "$clip"
    rm -f "$after/cinder_breath/frames.rgb" "$after/whiteout_lance/frames.rgb"
    printf '%s\n' "$clip"
fi
