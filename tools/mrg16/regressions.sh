#!/bin/sh
# Re-run the candidate 4 comparison witnesses with their pinned historical inputs.
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
out=${MRG16_OUTPUT_ROOT:-/private/tmp/labyrinth_codex/mrg-16}
stage=$(mktemp -d .godot/mrg16-regressions.XXXXXX)
trap 'rm -rf "$stage"' EXIT
mkdir -p "$out/logs"
export PYTHONDONTWRITEBYTECODE=1

verify() {
    name=$1
    rate=$2
    script=$3
    shift 3
    if python3 tools/godot_task_runner.py --task-id mrg-16 --stream -- godot \
        --headless "$rate" 60 --path . --script "$script" -- "$@" > "$out/logs/$name.log" 2>&1; then
        grep -E 'VERIFY|TEST RESULT|AFFECTED SUITES' "$out/logs/$name.log" | tail -8
    else
        tail -35 "$out/logs/$name.log" >&2
        return 1
    fi
}

rc=0
python3 tools/mrg15/stage_proof.py gfix34 "$stage/gfix34"
python3 tools/mrg16/stage_legacy.py gfix34 "$stage/gfix34"
verify gfix34 --max-fps tools/gfix34/verify.gd --base "res://$stage/gfix34" || rc=1
verify mrg15-reflection --max-fps tools/mrg15/verify_reflected_shots.gd --base "res://$stage/gfix34" || rc=1
verify fx17 --fixed-fps tools/fx17/verify.gd || rc=1
verify fx20-suites --fixed-fps tools/fx20/verify.gd --suites || rc=1
verify fx14 --max-fps tools/fx14/verify.gd --affected || rc=1
python3 tools/mrg15/stage_proof.py fx20 "$stage/fx20"
python3 tools/mrg16/stage_legacy.py fx20 "$stage/fx20"
verify fx20 --fixed-fps tools/fx20/verify.gd --out "$out/fx20" --base-dir "res://$stage/fx20" || rc=1
python3 tools/mrg15/stage_proof.py fx23 "$stage/fx23"
python3 tools/mrg16/stage_legacy.py fx23 "$stage/fx23"
verify fx23 --fixed-fps tools/fx23/verify.gd --out "$out/fx23" \
    --base-dir "res://$stage/fx23/before" --after-dir "res://$stage/fx23/after" || rc=1
python3 tools/mrg15/stage_proof.py fx29 "$stage/fx29"
python3 tools/mrg16/stage_legacy.py fx29 "$stage/fx29"
verify fx29 --max-fps tools/fx29/verify.gd --base "res://$stage/fx29" || rc=1
exit "$rc"
