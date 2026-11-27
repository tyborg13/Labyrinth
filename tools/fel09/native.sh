#!/usr/bin/env bash
set -euo pipefail

tool_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$tool_dir/../.."
export LABYRINTH_CEL_LOOK=all
capture_timeout=150
witness_timeout=300

if [[ "${1:-}" == --dry-run && "$#" == 1 ]]; then
    export FEL09_DRY_RUN=1
    python3 tools/godot_task_runner.py --task-id fel-09 --timeout "$witness_timeout" \
        --stream -- godot --headless --path . --script tools/fel09/census.gd
    python3 tools/fel09/native_report.py --check
    printf 'FEL09 WINDOWED COMMAND cd %q && bash tools/fel09/native.sh\n' "$PWD"
    exit 0
fi
if (( $# != 0 )); then
    printf 'Usage: %s [--dry-run]\n' "$0" >&2
    exit 2
fi

capture_root="$tool_dir/captures"
mkdir -p "$capture_root"
touch "$capture_root/.gdignore"
run_dir="$(mktemp -d "$capture_root/native.XXXXXX")"
printf 'FEL09 NATIVE OUTPUT %s\n' "$run_dir"

for fixture in "$tool_dir"/../fel01/fixtures/*/; do
    fixture="${fixture%/}"
    export FEL09_FIXTURE="${fixture##*/}"
    export FEL09_CAPTURE_DIR="$run_dir/$FEL09_FIXTURE"
    mkdir "$FEL09_CAPTURE_DIR"
    python3 tools/visual_probe_runner.py --task-id fel-09 --no-headless \
        --display-driver macos --audio-driver Dummy --timeout "$capture_timeout" \
        --expect-size 1920x1080 --proof-contract tools/fel09/proof_contract.json \
        --result-manifest "$FEL09_CAPTURE_DIR/visual-proof.json" tools/fel09/census.gd \
        2>&1 | tee "$FEL09_CAPTURE_DIR/runner.log"
    python3 tools/fel09/native_report.py --fixture "$FEL09_CAPTURE_DIR"
done
python3 tools/fel09/native_report.py --merge "$run_dir"
