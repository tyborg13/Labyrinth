#!/usr/bin/env bash
set -euo pipefail

tool_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$tool_dir/../.."
export LABYRINTH_CEL_LOOK=all
capture_timeout=180
if [[ "${1:-}" == "--dry-run" && "$#" == 1 ]]; then
    exec python3 tools/godot_task_runner.py --task-id fel-04 --timeout "$capture_timeout" \
        --stream -- godot --headless --path . --script tools/fel04/witness.gd
fi
if [[ "$#" != 0 ]]; then
    echo "Usage: $0 [--dry-run]" >&2
    exit 2
fi
mkdir -p "$tool_dir/captures"
touch "$tool_dir/captures/.gdignore"
FEL04_CAPTURE_DIR="$(mktemp -d "$tool_dir/captures/native.XXXXXX")"
export FEL04_CAPTURE_DIR

python3 tools/visual_probe_runner.py --task-id fel-04 --no-headless \
    --display-driver macos --audio-driver Dummy --timeout "$capture_timeout" \
    --expect-size 1920x1080 --proof-contract "$tool_dir/proof_contract.json" \
    --result-manifest "$FEL04_CAPTURE_DIR/visual-proof.json" tools/fel04/witness.gd \
    2>&1 | tee "$FEL04_CAPTURE_DIR/runner.log"
