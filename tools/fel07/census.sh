#!/usr/bin/env bash
set -euo pipefail

tool_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$tool_dir/../.."
export LABYRINTH_CEL_LOOK=all
capture_timeout=180

case "${1:-}" in
    --dry-run) mode=branch ;;
    "") mode=native ;;
    *) echo "Usage: $0 [--dry-run]" >&2; exit 2 ;;
esac
if [[ "$#" -gt 1 ]]; then
    echo "Usage: $0 [--dry-run]" >&2
    exit 2
fi

mkdir -p "$tool_dir/captures"
touch "$tool_dir/captures/.gdignore"
capture_dir="$(mktemp -d "$tool_dir/captures/$mode.XXXXXX")"
printf 'Capture directory\n%s\n' "$capture_dir"

run_census() {
    export FEL06_CAPTURE_DIR="$1"
    if [[ "$mode" == branch ]]; then
        export FEL06_DRY_RUN=1
        python3 tools/godot_task_runner.py --task-id fel-07 --stream -- godot --headless --path . \
            --script tools/fel07/census_probe.gd 2>&1 | tee "$FEL06_CAPTURE_DIR/runner.log"
    else
        unset FEL06_DRY_RUN
        python3 tools/visual_probe_runner.py --task-id fel-07 --no-headless \
            --display-driver macos --audio-driver Dummy --timeout "$capture_timeout" \
            --expect-size 1920x1080 --proof-contract tools/fel06/proof_contract.json \
            --result-manifest "$FEL06_CAPTURE_DIR/visual-proof.json" tools/fel07/census_probe.gd \
            2>&1 | tee "$FEL06_CAPTURE_DIR/runner.log"
    fi
    python3 tools/fel06/report.py "$FEL06_CAPTURE_DIR" "$FEL06_CAPTURE_DIR/census.md"
}

base_dir="$capture_dir/base"
mkdir "$base_dir"
export FEL07_BASE_TOOLTIP_SCRIPT="$base_dir/base_tooltip.gd"
python3 tools/fel07/stage_base_tooltip.py "$FEL07_BASE_TOOLTIP_SCRIPT"
run_census "$base_dir"
unset FEL07_BASE_TOOLTIP_SCRIPT
run_census "$capture_dir"

if [[ "$mode" == branch ]]; then
    python3 tools/fel07/compare_census.py "$base_dir/observations.json" "$capture_dir/observations.json" \
        | tee "$capture_dir/comparison.log"
else
    python3 -B tools/fel07/pair_sheet.py "$base_dir" "$capture_dir" | tee "$capture_dir/pairs.log"
fi
