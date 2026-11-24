#!/bin/sh
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
root=$PWD
output=${POL80_OUTPUT_ROOT:-/private/tmp/labyrinth_codex/pol-80}
candidate=7b3176ac60526b4d249f0e330631e98097a1ed1c
native_timeout=300
case "$#:${1:-}" in
    0:) mode=native ;;
    1:--dry-run) mode=headless ;;
    *) printf 'Usage: %s [--dry-run]\n' "$0" >&2; exit 2 ;;
esac
case "$output" in
    /*) ;;
    *) printf 'POL80_OUTPUT_ROOT must be an absolute path.\n' >&2; exit 2 ;;
esac

export LABYRINTH_CEL_LOOK=all GIT_OPTIONAL_LOCKS=0 PYTHONDONTWRITEBYTECODE=1
mkdir -p "$output"
folder=$(mktemp -d "$output/$mode.XXXXXX")
printf 'POL-80 output: %s\n' "$folder"
# Stage the native project as in POL-79 so imports and window overrides stay
# out of both worktrees. Restore the owned files from the pinned candidate.
stage=$(mktemp -d "$root/.godot/pol80-stage.XXXXXX")
trap 'rm -rf "$stage"' EXIT
for path in project.godot addons assets data experiments fonts scenes scripts shaders spec tests themes tools cel_look_variants; do
    cp -cRp "$root/$path" "$stage/$path"
done
mkdir -p "$stage/.godot"
for path in imported global_script_class_cache.cfg uid_cache.bin extension_list.cfg; do
    cp -cRp "$root/.godot/$path" "$stage/.godot/$path"
done

for phase in before after; do
    out="$folder/$phase"
    mkdir -p "$out"
    set --
    if [ "$phase" = before ]; then
        for path in scripts/card_focus_tooltip_stack.gd scripts/combat_board_view.gd scripts/inline_icon_text.gd scripts/large_map_backdrop.gd scripts/pattern_text.gd scripts/run_scene.gd scripts/ui_tooltip_panel.gd; do
            git show "$candidate:$path" > "$stage/$path"
        done
        rm -f "$stage/scripts/room_title_panel_fade.gd" "$stage/scripts/room_title_panel_fade.gd.uid"
        set -- --before
    else
        for path in scripts/card_focus_tooltip_stack.gd scripts/combat_board_view.gd scripts/inline_icon_text.gd scripts/large_map_backdrop.gd scripts/pattern_text.gd scripts/room_title_panel_fade.gd scripts/room_title_panel_fade.gd.uid scripts/run_scene.gd scripts/ui_tooltip_panel.gd; do
            if [ -f "$root/$path" ]; then cp -p "$root/$path" "$stage/$path"; fi
        done
    fi
    probe="$stage/tools/pol80/probe.gd"
    if [ "$mode" = headless ]; then
        python3 tools/godot_task_runner.py --task-id pol-80 --stream -- godot \
            --headless --path "$stage" --script "$probe" -- --dry-run --out "$out" "$@"
    else
        python3 tools/visual_probe_runner.py "$probe" --project "$stage" --task-id pol-80 \
            --no-headless --display-driver macos --audio-driver CoreAudio --timeout "$native_timeout" \
            --expect-size 1920x1080 --proof-contract "$root/tools/pol80/proof.json" \
            --result-manifest "$out/renderer_manifest.json" -- --out "$out" "$@"
    fi
done
if [ "$mode" = headless ]; then
    python3 - "$folder" <<'PY'
import json
import sys
from pathlib import Path

folder = Path(sys.argv[1])
before, after = [
    {row["id"]: row for row in json.loads((folder / phase / "observations.json").read_text())["text"]}
    for phase in ("before", "after")
]
if before.keys() != after.keys():
    raise SystemExit("Burst routes differ between revisions.")
for key in before:
    for field in ("raw", "plain", "panel_rect"):
        if before[key].get(field) != after[key].get(field):
            raise SystemExit(f"{key} changed {field}: {before[key].get(field)} -> {after[key].get(field)}")
print("POL-80 BURST COPY AND POP-UP BOUNDS: PASS")
PY
    printf 'POL-80 NATIVE DRY RUN PASS — %s\n' "$folder"
fi
