#!/usr/bin/env bash
set -euo pipefail

tool_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$tool_dir/../.."
output="${1:-/private/tmp/labyrinth_codex/fel-30}"
mkdir -p "$output"
output="$(cd "$output" && pwd)"
run="$(mktemp -d "$output/headless.XXXXXX")"
overlay="$run/overlay"
export LABYRINTH_CEL_LOOK=all

python3 tools/fel30/prepare.py "$overlay"
runner=(python3 tools/godot_task_runner.py --task-id fel-30 --stream)
"${runner[@]}" -- godot --headless --path . --script tools/fel30/pack.gd -- "$overlay"
export FEL30_OVERLAY="$overlay/census.pck"

seeds=()
for index in {0..5}; do
    seed=$((30001 + index))
    if (( index >= 3 )) && python3 - "${seeds[@]}" <<'PY'
import json
from pathlib import Path
import sys
kinds = set()
for folder in sys.argv[1:]:
    for line in (Path(folder) / "runs.jsonl").read_text().splitlines():
        kinds.add(json.loads(line).get("encounter"))
raise SystemExit(not {"Warband", "Guardian", "dragon"}.issubset(kinds))
PY
    then
        break
    fi
    export FEL30_SEED_START="$index" FEL30_SEED_LIMIT=1 FEL30_OUTPUT="$run/$seed"
    mkdir -p "$FEL30_OUTPUT"
    "${runner[@]}" --timeout 1800 -- godot --headless --fixed-fps 60 --path . --main-pack "$FEL30_OVERLAY" --script tools/fel30/census.gd \
        2>&1 | tee "$FEL30_OUTPUT/godot.log"
    seeds+=("$FEL30_OUTPUT")
done
python3 tools/fel30/report.py collect "${seeds[@]}" --output "$output"
python3 tools/fel30/report.py check --output "$output"
printf 'FEL30 HEADLESS OUTPUT %s\n' "$output"
