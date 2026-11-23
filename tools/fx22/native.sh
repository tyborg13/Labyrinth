#!/bin/sh
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
out=${FX22_OUTPUT_ROOT:-/private/tmp/labyrinth_codex/fx-22}
base=8f38fb277
dry=false
if [ "${1:-}" = --dry-run ]; then
    dry=true
    shift
fi
if [ "${1:-}" = --verify-fx20 ]; then
    shift
    # Keep fx-20's original assertions and stage its original dependencies.
    # Its launcher runs from this worktree with fx-22's task isolation.
    base=f21b6ff47
    verify=tools/fx20/verify.gd
    out="$out/fx20"
else
    verify=tools/fx22/verify.gd
fi
export LABYRINTH_CEL_LOOK=all PYTHONDONTWRITEBYTECODE=1 GIT_OPTIONAL_LOCKS=0
mkdir -p .godot "$out"
staging=$(mktemp -d .godot/fx22-base.XXXXXX)
trap 'rm -rf "$staging"' EXIT
files='run_scene.gd combat_board_view.gd board_surface_presentation.gd resolved_contact_bursts.gd shot_fx.gd veilbound_acolyte_cutout/fx.gd bile_bloomer_cutout/bloom_fx.gd cinder_ooze_cutout/action_fx.gd vaeloryx_cutout/wind_feedback.gd'
if [ "$verify" = tools/fx20/verify.gd ]; then
    files="$files enemy_mechanics/reflect_view.gd enemy_strike_points.gd enemy_strike_trail.gd"
fi
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

if [ "$dry" = true ] || [ "$verify" = tools/fx20/verify.gd ]; then
    python3 tools/godot_task_runner.py --task-id fx-22 --stream -- godot --headless --fixed-fps 60 --path . \
        --script "$verify" -- --out "$out/headless" --base-dir "$base_dir" "$@"
    if [ "$dry" = true ]; then
        printf '%s\n' "$out/headless/{before,after}/<case>/take.json" "$out/native/{before,after}/<case>/{strip.png,native-evidence.png,take.json,manifest.json}"
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
    contract=tools/fx22/proof_contract.json
    case "$case_id" in vaeloryx_*) contract=tools/fx22/proof_contract_large.json ;; esac
    python3 tools/visual_probe_runner.py tools/fx22/native_capture.gd --task-id fx-22 \
        --no-headless --display-driver macos --audio-driver Dummy --godot tools/fx15/movie_clock.sh \
        --timeout 300 --proof-contract "$contract" --overwrite-result-manifest \
        --result-manifest "$dir/manifest.json" -- --case "$case_id" --out "$dir" "$@"
    rm -f "$FX15_CLOCK_FILE"
    printf '%s\n' "$dir/strip.png" "$dir/native-evidence.png" "$dir/take.json" "$dir/manifest.json"
}

if [ "$#" -eq 0 ]; then
    set -- shale_hit shale_blocked shale_aoe cinder_bloom vaeloryx_push vaeloryx_pull
fi
for case_id in "$@"; do
    capture before "$case_id" --base-dir "$base_dir"
    capture after "$case_id"
done
