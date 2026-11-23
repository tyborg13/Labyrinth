#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
cd "$root"
out=${FX36_OUTPUT_ROOT:-/private/tmp/labyrinth_codex/fx-36}/regressions
export PYTHONDONTWRITEBYTECODE=1 LABYRINTH_CEL_LOOK=all GIT_OPTIONAL_LOCKS=0
stage=$(mktemp -d "$root/.godot/fx36-regressions.XXXXXX")
trap 'rm -rf "$stage"' EXIT
mkdir -p "$out"

run() {
    project=$1
    script=$2
    shift 2
    python3 tools/godot_task_runner.py --task-id fx-36 --stream -- godot --headless --fixed-fps 60 \
        --path "$project" --script "$script" -- "$@"
}

if [ "${1:-}" != "--fx34-only" ]; then
    mkdir "$stage/fx33-control" "$stage/fx33-now"
    python3 tools/fx33/stage.py "$stage/fx33-control" --instrument
    python3 tools/fx33/stage.py "$stage/fx33-now" --instrument
    for project in fx33-control fx33-now; do
        # fx-34 leaves a preview-only helper with no dashed argument. Remove the
        # obsolete injected floor probe from the staged copy of that helper.
        python3 - "$stage/$project/scripts/combat_board_view.gd" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
source = path.read_text()
hook = '\tif not dashed and alpha > 0.0: preload("res://tools/fx33/painter_log.gd").record("floor_line")\n'
assert source.count(hook) == 1
path.write_text(source.replace(hook, ""))
PY
    done
    for path in scripts/chain_attack_feedback.gd scripts/enemy_mechanics/capacitor_view.gd; do
        git show "codex/fx-34:$path" > "$stage/fx33-control/$path"
    done

    # Use fx-34 as the comparison because it deliberately removed the floor line
    # observed by the historical fx-33 verifier. Keep the legacy assertions intact
    # and require current failures to match an independently run fx-34 control.
    run "$stage/fx33-control" tools/fx33/verify.gd --out "$out/fx33-control" --reel > "$out/fx33-control.log" 2>&1
    run "$stage/fx33-control" tools/fx33/verify.gd --out "$out/fx33-self" \
        --compare-before "$out/fx33-control" --reel > "$out/fx33-self.log" 2>&1 || control_status=$?
    run "$stage/fx33-now" tools/fx33/verify.gd --out "$out/fx33-now" \
        --compare-before "$out/fx33-control" --reel > "$out/fx33-now.log" 2>&1 || now_status=$?
    test "${control_status:-0}" = "${now_status:-0}"
    for name in fx33-self fx33-now; do
        rg '^FX-33 (FAIL|VERIFY)' "$out/$name.log" > "$out/$name-summary.txt"
        cat "$out/$name-summary.txt"
    done
    diff -u "$out/fx33-self-summary.txt" "$out/fx33-now-summary.txt"
    run "$root" tools/fx33/verify.gd --focused > "$out/fx33-focused.log" 2>&1
    rg '^FX-33 (FOCUSED|VERIFY)' "$out/fx33-focused.log"
fi

mkdir "$stage/fx34-before" "$stage/fx34-now"
python3 tools/fx34/stage.py "$stage/fx34-before" --before --instrument
python3 tools/fx34/stage.py "$stage/fx34-now" --instrument
# The reward roll uses PresentationClock directly. Its fallback to wall time
# is nondeterministic at fixed headless FPS, so use the existing movie clock in
# both temporary projects. Neither production source nor assertions change.
python3 - "$stage/fx34-before" "$stage/fx34-now" <<'PY'
from pathlib import Path
import sys

for project in sys.argv[1:]:
    clock = Path(project) / "scripts/presentation_clock.gd"
    source = clock.read_text()
    fps = 'if not Engine.get_write_movie_path().is_empty() else 0'
    wall = '\tif Engine.get_write_movie_path().is_empty(): return Time.get_ticks_usec()\n'
    assert source.count(fps) == 1 and source.count(wall) == 1
    clock.unlink()
    clock.write_text(source.replace(fps, '').replace(wall, ''))
PY
run "$stage/fx34-before" tools/fx34/verify.gd --baseline --out "$out/fx34-before" > "$out/fx34-before.log" 2>&1
run "$stage/fx34-now" tools/fx34/verify.gd --out "$out/fx34-now" \
    --compare-before "$out/fx34-before" > "$out/fx34-now.log" 2>&1 || status=$?
rg '^FX-34 BASELINE' "$out/fx34-before.log"
rg '^FX-34 VERIFY' "$out/fx34-now.log"
printf '%s\n' "$out"
exit "${status:-0}"
