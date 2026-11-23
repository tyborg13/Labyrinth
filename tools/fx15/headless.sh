#!/bin/sh
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
base=e0b29e0b6
out=${FX15_PROOF_ROOT:-/private/tmp/labyrinth_codex/fx-15/headless}
staging=$(mktemp -d .godot/fx15-base.XXXXXX)
trap 'rm -rf "$staging"' EXIT
export LABYRINTH_CEL_LOOK=all

# Read the base playback scripts without disturbing this worktree. Only rebind
# the preload paths of the three playback helpers whose source changed.
python3 - "$base" "$staging" <<'PY'
from pathlib import Path
import subprocess
import sys

base, staging = sys.argv[1:]
helpers = (
    "scripts/battlefield_rules/playback.gd",
    "scripts/meteorfall_landing_view.gd",
    "scripts/enemy_mechanics/icefall_view.gd",
)

def base_text(path):
    return subprocess.check_output(["git", "show", f"{base}:{path}"], text=True)

run = base_text("scripts/run_scene.gd")
for path in helpers:
    copy = Path(staging) / path.removeprefix("scripts/")
    copy.parent.mkdir(parents=True, exist_ok=True)
    copy.write_text(base_text(path))
    run = run.replace(f"res://{path}", f"res://{copy.as_posix()}")
(Path(staging) / "run_scene.gd").write_text(run)
PY

take() {
    set=$1
    case_id=$2
    shift 2
    dir="$out/$set/$case_id"
    mkdir -p "$dir"
    if python3 tools/godot_task_runner.py --task-id fx-15 --stream -- godot --headless --fixed-fps 60 --path . \
        --script tools/fx15/native_capture.gd -- --case "$case_id" --out "$dir" --plan "$@" > "$dir/run.log" 2>&1; then
        sed -n '/^FX-15 PLAN /p' "$dir/run.log"
    else
        cat "$dir/run.log"
        return 1
    fi
}

compare_take() (
    case_id=$1
    suffix=$2
    shift 2
    take "base$suffix" "$case_id" --baseline-run-script "res://$staging/run_scene.gd" "$@" &
    old_process=$!
    take "current$suffix" "$case_id" "$@" &
    new_process=$!
    status=0
    wait "$old_process" || status=1
    wait "$new_process" || status=1
    exit "$status"
)

for case_id in skybreak board_rule zekarion vyraketh meteorfall icefall; do
    compare_take "$case_id" ""
done
compare_take icefall -fallback --icefall-fallback
python3 - "$out" <<'PY'
import json
from pathlib import Path
import sys

root = Path(sys.argv[1])
fields = ("contact_frame", "completion_frame", "authored_frames", "rendered_frames", "authored_duration_usec")
passed = True
for case in ("skybreak", "board_rule", "zekarion", "vyraketh", "meteorfall", "icefall"):
    def read(group):
        take = json.loads((root / group / case / "take.json").read_text())
        return tuple(take[field] for field in fields)
    before, after = read("base"), read("current")
    passed &= before == after
    print(f"FX-15 PACING {case}: base={before} current={after} {'PASS' if before == after else 'FAIL'}")
before, after = read("base-fallback"), read("current-fallback")
passed &= before == after
print(f"FX-15 PACING icefall_fallback: base={before} current={after} {'PASS' if before == after else 'FAIL'}")
raise SystemExit(0 if passed else 1)
PY

for case_id in occlusion half_hidden; do take current "$case_id"; done
for case_id in skybreak board_rule zekarion vyraketh meteorfall icefall; do take reduced "$case_id" --reduced-motion; done
