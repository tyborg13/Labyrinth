#!/bin/sh
set -eu
ROOT=/Users/borgerding/workspace/Labyrinth.worktrees/fx-17
BASE=${FX17_BASE_PROJECT:-/Users/borgerding/workspace/Labyrinth.worktrees/fx-13}
BASE_HEAD=e0b29e0b6cd9fd6217d77347f31b16ef5c3e8218
PROOF_ROOT=${FX17_PROOF_ROOT:-/private/tmp/labyrinth_codex/fx-17}
cd "$ROOT"
mkdir -p "$PROOF_ROOT"
export LABYRINTH_CEL_LOOK=all PYTHONDONTWRITEBYTECODE=1

mode=native
if [ "${1:-}" = "--dry-run" ]; then
    mode=plan
    shift
fi
run_dir=$(mktemp -d "$PROOF_ROOT/$mode.XXXXXX")
printf 'FX-17 %s output: %s\n' "$mode" "$run_dir"
if [ "$(git -C "$BASE" rev-parse HEAD)" != "$BASE_HEAD" ]; then
    printf 'FX17_BASE_PROJECT must point at %s\n' "$BASE_HEAD" >&2
    exit 1
fi
for source in scripts/run_scene.gd scripts/combat_board_view.gd scripts/board_surface_presentation.gd \
    scripts/enemy_mechanics/burrow_view.gd scripts/enemy_mechanics/bramble_view.gd scripts/tile_burst_fx.gd
do
    if ! git -C "$BASE" diff --quiet "$BASE_HEAD" -- "$source"; then
        printf 'FX17_BASE_PROJECT has local changes in %s\n' "$source" >&2
        exit 1
    fi
done

capture() {
    variant=$1
    take=$2
    project=$ROOT
    if [ "$variant" = base ]; then project=$BASE; fi
    dir="$run_dir/$variant/$take"
    mkdir -p "$dir"
    export FX17_CLOCK_FILE="$dir/clock.avi"
    printf 'FX-17 %s/%s: %s\n' "$variant" "$take" "$dir"
    if [ "$mode" = plan ]; then
        python3 tools/godot_task_runner.py --task-id fx-17 --stream -- godot --headless --fixed-fps 60 \
            --path "$project" --script "$ROOT/tools/fx17/native.gd" \
            -- --case "$take" --variant "$variant" --out "$dir" --plan
    else
        python3 tools/visual_probe_runner.py "$ROOT/tools/fx17/native.gd" --project "$project" --task-id fx-17 \
            --no-headless --display-driver macos --audio-driver Dummy --godot "$ROOT/tools/fx17/movie_clock.sh" \
            --timeout 480 --expect-size 1920x1080 --expect-size 3840x480 \
            --proof-contract "$ROOT/tools/fx17/proof_contract.json" --result-manifest "$dir/manifest.json" \
            -- --case "$take" --variant "$variant" --out "$dir"
        if [ "$take" = recording ]; then
            ffmpeg -hide_banner -loglevel error -nostdin -f rawvideo -pixel_format rgb24 -video_size 1920x1080 \
                -framerate 60 -i "$dir/frames.rgb" -frames:v 300 -c:v libx264 -pix_fmt yuv420p "$dir/melee-exchanges.mp4"
            rm "$dir/frames.rgb"
            printf 'FX-17 recording: %s\n' "$dir/melee-exchanges.mp4"
        fi
    fi
    rm -f "$FX17_CLOCK_FILE"
}

if [ "$#" -eq 0 ]; then
    set -- strike bite block surgeon push_wall push_unit pull_prop ice_break trap dive erupt bramble shadow hurl_spear recording
fi
for take in "$@"; do
    if [ "$take" != recording ]; then capture base "$take"; fi
    capture after "$take"
done

python3 - "$run_dir" <<'PY'
import json
from pathlib import Path
import sys

directory = Path(sys.argv[1])
matches = True
for take in ("strike", "bite", "push_wall", "erupt", "hurl_spear"):
    base = directory / "base" / take / "take.json"
    current = directory / "after" / take / "take.json"
    if not base.exists() or not current.exists():
        continue
    old_frames = json.loads(base.read_text())["action_frames"]
    new_frames = json.loads(current.read_text())["action_frames"]
    matches &= old_frames == new_frames
    print(f"FX-17 PACING {take}: base={old_frames}, after={new_frames}")
print(f"FX-17 proof paths: {directory}")
raise SystemExit(0 if matches else 1)
PY
