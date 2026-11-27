#!/usr/bin/env bash
set -euo pipefail

tool_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$tool_dir/../.."
export LABYRINTH_CEL_LOOK=all
capture_timeout=180

case "${1:-}" in
    --dry-run) mode=dry ;;
    "") mode=native ;;
    *) echo "Usage: $0 [--dry-run]" >&2; exit 2 ;;
esac
if [[ "$#" -gt 1 ]]; then
    echo "Usage: $0 [--dry-run]" >&2
    exit 2
fi

mkdir -p "$tool_dir/captures"
touch "$tool_dir/captures/.gdignore"
FEL06_CAPTURE_DIR="$(mktemp -d "$tool_dir/captures/$mode.XXXXXX")"
export FEL06_CAPTURE_DIR
printf 'Capture directory %s\n' "$FEL06_CAPTURE_DIR"

if [[ "$mode" == dry ]]; then
    export FEL06_DRY_RUN=1
    python3 tools/godot_task_runner.py --task-id fel-08 --timeout "$capture_timeout" \
        --stream -- godot --headless --path . --script tools/fel08/witness.gd \
        2>&1 | tee "$FEL06_CAPTURE_DIR/runner.log"
else
    unset FEL06_DRY_RUN
    python3 tools/visual_probe_runner.py --task-id fel-08 --no-headless \
        --display-driver macos --audio-driver Dummy --timeout "$capture_timeout" \
        --expect-size 1920x1080 --proof-contract "$tool_dir/proof_contract.json" \
        --result-manifest "$FEL06_CAPTURE_DIR/visual-proof.json" tools/fel08/witness.gd \
        2>&1 | tee "$FEL06_CAPTURE_DIR/runner.log"
fi
