#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
export LABYRINTH_CEL_LOOK=all PYTHONDONTWRITEBYTECODE=1

base_ref=7ba6cacac36037ca11967a6205cb6562f18e54ae
capture_timeout=180
mode=native
baseline_only=false
case "${1:-}" in
    --dry-run) mode=dry ;;
    --baseline-dry-run) mode=dry; baseline_only=true ;;
    --reproduce) baseline_only=true ;;
    "") ;;
    *) printf '%s\n' 'Usage: tools/fel11/native.sh [--dry-run|--baseline-dry-run|--reproduce]' >&2; exit 2 ;;
esac

# Keep staged scripts under .godot, like the existing comparison probes. The
# production files and Git checkout stay in place for both takes.
stage=$(mktemp -d .godot/fel11-base.XXXXXX)
trap 'rm -rf "$stage"' EXIT
git show "$base_ref:scripts/run_scene.gd" > "$stage/run_scene.gd"
git show "$base_ref:scripts/combat_board_view.gd" > "$stage/combat_board_view.gd"
git show "$base_ref:scripts/section_map_panel.gd" > "$stage/section_map_panel.gd"
python3 - "$stage" <<'PY'
import sys
from pathlib import Path

stage = Path(sys.argv[1])
run = stage / "run_scene.gd"
run.write_text(run.read_text().replace(
    "res://scripts/section_map_panel.gd", f"res://{stage}/section_map_panel.gd"
))
for file in ("combat_board_view.gd", "section_map_panel.gd"):
    path = stage / file
    path.write_text("".join(
        line for line in path.read_text().splitlines(keepends=True)
        if not line.startswith("class_name ")
    ))
PY

mkdir -p .godot/fel11-proof
export FEL11_OUTPUT
FEL11_OUTPUT=$(mktemp -d "$PWD/.godot/fel11-proof/$mode.XXXXXX")
printf 'Proof directory %s\n' "$FEL11_OUTPUT"
printf 'Windowed comparison: cd %q && tools/fel11/native.sh\n' "$PWD"
printf 'Windowed baseline reproduction: cd %q && tools/fel11/native.sh --reproduce\n' "$PWD"

capture() {
    local revision=$1
    export FEL11_REVISION="$revision"
    if [[ "$revision" == base ]]; then export FEL11_BASE_DIR="res://$stage"; else unset FEL11_BASE_DIR; fi
    if [[ "$mode" == dry ]]; then
        python3 tools/godot_task_runner.py --task-id fel-11 --stream -- godot --headless --path . \
            --script tools/fel11/witness.gd 2>&1 | tee "$FEL11_OUTPUT/$revision.log"
    else
        python3 tools/visual_probe_runner.py tools/fel11/witness.gd --task-id fel-11 --no-headless \
            --display-driver macos --audio-driver Dummy --timeout "$capture_timeout" --expect-size 1920x1080 \
            --proof-contract tools/fel11/proof_contract.json --result-manifest "$FEL11_OUTPUT/$revision-visual-proof.json" \
            2>&1 | tee "$FEL11_OUTPUT/$revision.log"
    fi
}
capture base
if [[ "$baseline_only" == false ]]; then capture branch; fi
