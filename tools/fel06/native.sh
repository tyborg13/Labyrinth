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
echo "Capture directory $FEL06_CAPTURE_DIR"

if [[ "$mode" == dry ]]; then
    export FEL06_DRY_RUN=1
    python3 tools/godot_task_runner.py --task-id fel-06 --stream -- godot --headless --path . \
        --script tools/fel06/hover_probe.gd 2>&1 | tee "$FEL06_CAPTURE_DIR/runner.log"
    python3 tools/fel06/report.py "$FEL06_CAPTURE_DIR" "$FEL06_CAPTURE_DIR/census.md"
else
    unset FEL06_DRY_RUN
    python3 tools/visual_probe_runner.py --task-id fel-06 --no-headless \
        --display-driver macos --audio-driver Dummy --timeout "$capture_timeout" \
        --expect-size 1920x1080 --proof-contract "$tool_dir/proof_contract.json" \
        --result-manifest "$FEL06_CAPTURE_DIR/visual-proof.json" tools/fel06/hover_probe.gd \
        2>&1 | tee "$FEL06_CAPTURE_DIR/runner.log"
    python3 tools/fel06/report.py "$FEL06_CAPTURE_DIR" "$tool_dir/census.md"
fi
