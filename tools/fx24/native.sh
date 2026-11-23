#!/bin/sh
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
out=${FX24_OUTPUT_ROOT:-/private/tmp/labyrinth_codex/fx-24}
base=28d367a90
verify=tools/fx24/verify.gd
files='run_scene.gd combat_board_view.gd board_surface_presentation.gd resolved_contact_bursts.gd shot_fx.gd veilbound_acolyte_cutout/fx.gd'
dry=false
case "${1:-}" in
    --dry-run)
        dry=true
        shift ;;
    --verify-fx20)
        dry=true
        base=f21b6ff47
        verify=tools/fx20/verify.gd
        out="$out/fx20"
        files="$files enemy_mechanics/reflect_view.gd enemy_strike_points.gd enemy_strike_trail.gd bile_bloomer_cutout/bloom_fx.gd cinder_ooze_cutout/action_fx.gd vaeloryx_cutout/wind_feedback.gd"
        shift ;;
    --verify-fx22)
        dry=true
        base=8f38fb277
        verify=tools/fx22/verify.gd
        out="$out/fx22"
        files="$files bile_bloomer_cutout/bloom_fx.gd cinder_ooze_cutout/action_fx.gd vaeloryx_cutout/wind_feedback.gd"
        shift ;;
esac
export LABYRINTH_CEL_LOOK=all PYTHONDONTWRITEBYTECODE=1 GIT_OPTIONAL_LOCKS=0
mkdir -p .godot "$out"
staging=$(mktemp -d .godot/fx24-base.XXXXXX)
trap 'rm -rf "$staging"' EXIT
for file in $files; do
    mkdir -p "$staging/$(dirname "$file")"
    git show "$base:scripts/$file" > "$staging/$file"
done
git show "$base:data/shots.json" > "$staging/shots.json"
python3 - "$staging" $files <<'PY'
import sys
from pathlib import Path

stage = Path(sys.argv[1])
paths = sys.argv[2:]
for name in paths:
    path = stage / name
    source = path.read_text().replace("class_name CombatBoardView\n", "")
    source = source.replace("res://data/shots.json", f"res://{stage}/shots.json")
    for other in paths:
        source = source.replace(f"res://scripts/{other}", f"res://{stage}/{other}")
    path.write_text(source)
PY
base_dir="res://$staging"

if [ "$dry" = true ]; then
    python3 tools/godot_task_runner.py --task-id fx-24 --stream -- godot --headless --fixed-fps 60 --path . \
        --script "$verify" -- --out "$out/headless" --base-dir "$base_dir" "$@"
    printf '%s\n' "$out/headless/{before,after}/<case>/take.json"
    if [ "$verify" = tools/fx24/verify.gd ]; then
        printf '%s\n' "$out/native/{before,after}/<case>/{strip.png,native-evidence.png,take.json,manifest.json}"
    fi
    exit
fi

capture() {
    revision=$1
    case_id=$2
    shift 2
    dir="$out/native/$revision/$case_id"
    mkdir -p "$dir"
    export FX15_CLOCK_FILE="$dir/clock.avi"
    python3 tools/visual_probe_runner.py tools/fx24/native_capture.gd --task-id fx-24 \
        --no-headless --display-driver macos --audio-driver Dummy --godot tools/fx15/movie_clock.sh \
        --timeout 300 --proof-contract tools/fx24/proof_contract.json --overwrite-result-manifest \
        --result-manifest "$dir/manifest.json" -- --case "$case_id" --out "$dir" "$@"
    rm -f "$FX15_CLOCK_FILE"
    printf '%s\n' "$dir/strip.png" "$dir/native-evidence.png" "$dir/take.json" "$dir/manifest.json"
}

if [ "$#" -eq 0 ]; then
    set -- ice_melt rubble_clear fire_out collision_hit veil_needle targeted_fire fire_entry push_wall ice_trap elementless_trap
fi
for case_id in "$@"; do
    capture before "$case_id" --base-dir "$base_dir"
    capture after "$case_id"
done
