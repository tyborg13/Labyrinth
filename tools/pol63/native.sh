#!/bin/sh
set -eu

if [ "${POL63_WINDOWED_ENGINE:-}" = 1 ]; then
    exec python3 tools/godot_task_runner.py --task-id pol-63 --stream --timeout 60 -- godot "$@"
fi

launcher=$0
if [ -L "$launcher" ]; then
    target=$(readlink "$launcher")
    case "$target" in
        /*) launcher=$target ;;
        *) launcher=$(dirname "$launcher")/$target ;;
    esac
fi
project=$(cd "$(dirname "$launcher")/../.." && pwd)
before=${POL63_BEFORE_PROJECT:-"$(dirname "$project")/scn-01"}
base_head=060674b1a090d5a7e06624eb03a9e37e77fc5a5d
proof_root=/private/tmp/labyrinth_codex/pol-63
large=warband,guardian,guardian_ashen_reaver,guardian_last_lamplighter,ember_hoarder,dragon_tharokh,dragon_vyraketh,dragon_noctyrax,pre_battle,treasure,combat_idle,combat_hand_hover,combat_card_aim,combat_keyword_popup
small=dragon_tharokh,dragon_vyraketh,dragon_vaeloryx,dragon_iskaldra,dragon_zekarion,dragon_noctyrax

case "$#:${1:-}" in
    0:|1:--dry-run) ;;
    *) echo "Usage: $0 [--dry-run]" >&2; exit 2 ;;
esac
if [ "$(git -C "$before" rev-parse HEAD)" != "$base_head" ] ||
   ! git --no-optional-locks -C "$before" diff --quiet HEAD; then
    echo "Set POL63_BEFORE_PROJECT to a clean scn-01 worktree at $base_head." >&2
    exit 1
fi
mkdir -p "$proof_root"
run=$(mktemp -d "$proof_root/census.XXXXXXXX")
export PYTHONDONTWRITEBYTECODE=1

census() (
    source=$1; name=$2; size=$3; shots=$4
    shift 4
    cd "$source"
    dir=$run/$name
    printf '%s\n' "$name output: $dir"
    python3 tools/scn01/census.py --out "$dir" --size "$size" --only "$shots" "$@"
    # The census allows partial success. This handoff requires each chosen shot.
    python3 - "$dir/manifest.json" <<'PY'
import json
from pathlib import Path
import sys

manifest = json.loads(Path(sys.argv[1]).read_text())
for shot in manifest["shots"]:
    if not shot["ok"]:  # settle caps are normal for animated scenes (46/50 in the full census)
        sys.exit(f"{shot['shot']} did not settle successfully.")
PY
)

census "$before" before-1920x1080 1920x1080 "$large" "$@"
census "$project" after-1920x1080 1920x1080 "$large" "$@"
census "$project" after-1280x800 1280x800 "$small" "$@"
cd "$project"
entry_mode=--native
if [ "${1:-}" = --dry-run ]; then entry_mode=; fi
printf '%s\n' "settled-entry output: $run/settled-entry"
python3 tools/pol63/state_proof.py after --entry-census ${entry_mode:+"$entry_mode"} --out "$run/settled-entry"
printf '%s\n' "POL63 NATIVE PROOF: $run"
