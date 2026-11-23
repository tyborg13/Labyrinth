#!/bin/sh
set -eu

repo=$(pwd -P)
out=/private/tmp/labyrinth_codex/gfix-33/round1
probe=tools/gfix33/verify.gd
native_timeout=90
baseline=c01b68859c719b10d6541cd0426c0f76597a8ca5

if [ ! -f "$probe" ]; then
    printf '%s\n' "Run this script from the gfix-33 worktree." >&2
    exit 2
fi
case ${1:-} in
    ''|--dry-run) ;;
    *) exit 2 ;;
esac
mkdir -p "$out"
export LABYRINTH_CEL_LOOK=all

# Isolate the original HUD sources while sharing immutable imported assets.
# The live worktree and its branch stay in place during both captures.
original=$(mktemp -d "$out/baseline-project.XXXXXX")
trap 'rm -rf "$original"' EXIT
for entry in "$repo"/*; do
    case ${entry##*/} in
        scripts) cp -cR "$entry" "$original/scripts" ;;
        *) ln -s "$entry" "$original/${entry##*/}" ;;
    esac
done
mkdir "$original/.godot"
ln -s "$repo/.godot/imported" "$original/.godot/imported"
for cache in extension_list.cfg global_script_class_cache.cfg uid_cache.bin; do
    cp "$repo/.godot/$cache" "$original/.godot/"
done
for path in scripts/board_hero_hud_clearance.gd scripts/board_status_layout_cache.gd scripts/combat_board_view.gd scripts/intent_badges.gd; do
    git show "$baseline:$path" > "$original/$path"
done

headless() {
    project=$1
    shift
    python3 tools/godot_task_runner.py --task-id gfix-33 --stream -- godot \
        --headless --path "$project" --fixed-fps 60 --script "$probe" -- "$@"
}
if [ ! -s "$out/before.json" ]; then
    headless "$original" --before
fi
python3 - "$out" <<'PY'
import json
import sys
from pathlib import Path

out = Path(sys.argv[1])
cases = ["harrier_e_crowded", "vyraketh_n_crowded", "vyraketh_e_crowded"]
(out / "capture_placements.json").write_text(json.dumps(cases) + "\n")
contract = {
    "min_images": 3,
    "expected_sizes": ["1920x1080"],
    "required_images": [
        {"pattern": f"{case}_1920x1080.png", "width": 1920, "height": 1080,
         "regions": [{"rect": [480, 160, 960, 600], "min_luma_range": 8, "min_luma_stdev": 2}]}
        for case in cases
    ],
}
(out / "capture_contract.json").write_text(json.dumps(contract, indent=2) + "\n")
PY

if [ "${1:-}" = "--dry-run" ]; then
    headless "$original" --before --dry-run
    headless "$repo" --dry-run
    exit
fi

capture() {
    project=$1
    phase=$2
    shift 2
    python3 tools/visual_probe_runner.py "$probe" \
        --project "$project" --no-headless --display-driver macos --audio-driver Dummy \
        --task-id gfix-33 --timeout "$native_timeout" --expect-size 1920x1080 --min-images 3 \
        --proof-contract "$out/capture_contract.json" \
        --result-manifest "$out/$phase/result-manifest.json" --overwrite-result-manifest \
        -- --native "$@"
}

capture "$original" before --before
capture "$repo" after
