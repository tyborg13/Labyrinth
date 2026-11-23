#!/bin/sh
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
out=${FX20_OUTPUT_ROOT:-/private/tmp/labyrinth_codex/fx-20}
base=f21b6ff47
staging=$(mktemp -d .godot/fx20-base.XXXXXX)
trap 'rm -rf "$staging"' EXIT
export LABYRINTH_CEL_LOOK=all PYTHONDONTWRITEBYTECODE=1

# The comparators run inside one project. Stage only the changed playback scripts
# and rebind their cross-references. TileBurst's shared types stay installed.
files='run_scene.gd combat_board_view.gd resolved_contact_bursts.gd shot_fx.gd enemy_mechanics/reflect_view.gd enemy_strike_points.gd enemy_strike_trail.gd veilbound_acolyte_cutout/fx.gd'
if [ "${1:-}" = --verify-fx18 ]; then
    base=7d1ba7df9
    # Its base board preloads the old Veilbound and Bramble painters.
    files='run_scene.gd combat_board_view.gd dragon_spell_presentation.gd enemy_mechanics/bramble_view.gd enemy_mechanics/reflect_view.gd veilbound_acolyte_cutout/fx.gd enemy_strike_points.gd enemy_strike_trail.gd'
fi
for file in $files; do
    mkdir -p "$staging/$(dirname "$file")"
    git show "$base:scripts/$file" > "$staging/$file"
done
python3 - "$staging" $files <<'PY'
import sys
from pathlib import Path

stage = Path(sys.argv[1])
paths = sys.argv[2:]
for name in paths:
    path = stage / name
    source = path.read_text().replace("class_name CombatBoardView\n", "")
    for other in paths:
        source = source.replace(f"res://scripts/{other}", f"res://{stage}/{other}")
    path.write_text(source)
PY
base_dir="res://$staging"

if [ "${1:-}" = --verify-fx18 ]; then
    shift
    mkdir -p "$out/fx18-headless"
    python3 tools/godot_task_runner.py --task-id fx-20 --stream -- godot --headless --fixed-fps 60 --path . \
        --script tools/fx18/verify.gd -- --out "$out/fx18-headless" --base-dir "$base_dir" "$@"
    exit
fi
if [ "${1:-}" = --dry-run ]; then
    shift
    mkdir -p "$out/headless"
    python3 tools/godot_task_runner.py --task-id fx-20 --stream -- godot --headless --fixed-fps 60 --path .         --script tools/fx20/verify.gd -- --out "$out/headless" --base-dir "$base_dir" "$@"
    printf '%s\n' "$out/headless"
    exit
fi

capture() {
    revision=$1
    case_id=$2
    shift 2
    dir="$out/native/$revision/$case_id"
    mkdir -p "$dir"
    export FX15_CLOCK_FILE="$dir/clock.avi"
    contract=tools/fx20/proof_contract.json
    case "$case_id" in bite|rake|refraction|skybreak) contract=tools/fx20/proof_contract_large.json ;; esac
    python3 tools/visual_probe_runner.py tools/fx20/native_capture.gd --task-id fx-20         --no-headless --display-driver macos --audio-driver Dummy --godot tools/fx15/movie_clock.sh         --timeout 300 --proof-contract "$contract" --overwrite-result-manifest         --result-manifest "$dir/manifest.json" -- --case "$case_id" --out "$dir" "$@"
    rm -f "$FX15_CLOCK_FILE"
    printf '%s\n' "$dir/strip.png" "$dir/native-evidence.png" "$dir/take.json" "$dir/manifest.json"
}

record=false
if [ "$#" -eq 0 ]; then
    record=true
    set -- frostbolt bite rake veilbound refraction reflect_spear hurl_spear skybreak
fi
for case_id in "$@"; do
    capture before "$case_id" --base-dir "$base_dir"
    capture after "$case_id"
done
if [ "$record" = true ]; then
    capture after recording
    clip="$out/native/frostbolt-reflect-refraction.mp4"
    raw="$out/native/after/recording/frames.rgb"
    ffmpeg -nostdin -v error -y -f rawvideo -pixel_format rgb24 -video_size 1920x1080         -framerate 60 -i "$raw" -frames:v 300 -c:v libx264 -pix_fmt yuv420p "$clip"
    rm -f "$raw"
    printf '%s\n' "$clip"
fi
