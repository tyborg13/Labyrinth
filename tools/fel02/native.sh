#!/usr/bin/env bash
set -euo pipefail

tool_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$tool_dir/../.."
export LABYRINTH_CEL_LOOK=all
export FEL01_FIXTURES="$PWD/tools/fel01/samples"
export FEL01_SAMPLES=1
unset FEL01_DRY_RUN FEL01_FIXTURE FEL01_WITNESS_ONLY
capture_timeout=180
dry_run=0
for option in "$@"; do
    case "$option" in
        --samples) ;;
        --dry-run) dry_run=1 ;;
        *) echo "Usage: $0 [--samples] [--dry-run]" >&2; exit 2 ;;
    esac
done

# Reuse fel-01's Continue and input sequence for a matched comparison.
probe=tools/fel01/resume_probe.gd
if [[ "$dry_run" == 1 ]]; then
    export FEL01_DRY_RUN=1
    exec python3 tools/godot_task_runner.py --task-id fel-02 --timeout "$capture_timeout" \
        --stream -- godot --headless --path . --script "$probe"
fi

mkdir -p "$tool_dir/captures"
touch "$tool_dir/captures/.gdignore"
FEL01_CAPTURE_DIR="$(mktemp -d "$tool_dir/captures/native.XXXXXX")"
export FEL01_CAPTURE_DIR
manifest="$FEL01_CAPTURE_DIR/visual-proof.json"
python3 tools/visual_probe_runner.py --task-id fel-02 --no-headless \
    --display-driver macos --audio-driver Dummy --timeout "$capture_timeout" \
    --expect-size 1920x1080 --proof-contract "$tool_dir/proof_contract.json" \
    --result-manifest "$manifest" "$probe" 2>&1 | tee "$FEL01_CAPTURE_DIR/runner.log"
python3 - "$manifest" <<'PY'
import json
import sys
from pathlib import Path

for image in json.loads(Path(sys.argv[1]).read_text())["images"]:
    print(image["path"])
PY
