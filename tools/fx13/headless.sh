#!/bin/sh
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
out=${FX13_PROOF_ROOT:-$(mktemp -d /private/tmp/labyrinth_codex/fx-13/proof.XXXXXX)}
mkdir -p "$out"
export LABYRINTH_CEL_LOOK=all

verify() {
    python3 tools/godot_task_runner.py --task-id fx-13 --stream -- godot --headless --path . --script "$@"
}

plan() {
    group=$1
    take=$2
    shift 2
    dir="$out/$group/$take"
    mkdir -p "$dir"
    python3 tools/godot_task_runner.py --task-id fx-13 --stream -- godot --headless --fixed-fps 60 --path . \
        --script tools/fx13/native_capture.gd -- --case "$take" --out "$dir" --plan "$@"
}

verify tools/fx13/verify.gd
verify tools/fx12/verify.gd

git show HEAD:scripts/run_scene.gd > "$out/HEAD_RunScene.gd"
for take in brace stone_plate glass_mending whetstone mantle guard_ally enemy_heal block_2x2; do
    plan base "$take" --baseline-run-script "$out/HEAD_RunScene.gd"
    plan current "$take"
done
python3 - "$out" <<'PY'
import json
from pathlib import Path
import sys

output = Path(sys.argv[1])
passed = True
for base in sorted((output / "base").glob("*/take.json")):
    relative = base.relative_to(output / "base")
    old = json.loads(base.read_text())["complete_frame"]
    current = json.loads((output / "current" / relative).read_text())["complete_frame"]
    passed = passed and old == current
    print(f"FX-13 PACING {base.parent.name}: HEAD={old}, fx-13={current}")
raise SystemExit(0 if passed else 1)
PY

for take in retaliate quicken illusion tick_summon guardian_summon dragon_summon reinforcement expose_enemy expose_hero recording; do
    plan current "$take"
done
for take in illusion tick_summon reinforcement; do
    plan reduced "$take" --reduced-motion
done
