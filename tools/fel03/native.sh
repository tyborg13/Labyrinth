#!/usr/bin/env bash
set -euo pipefail

tool_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$tool_dir/../.."
export LABYRINTH_CEL_LOOK=all
capture_timeout=180

if [[ "$#" == 1 && "$1" == --dry-run ]]; then
    exec python3 tools/godot_task_runner.py --task-id fel-03 --timeout "$capture_timeout"         --stream -- godot --headless --fixed-fps 60 --path .         --script tools/fel03/capture.gd -- --dry-run
fi
if [[ "$#" != 0 ]]; then
    echo "Usage: $0 [--dry-run]" >&2
    exit 2
fi

mkdir -p "$tool_dir/captures"
touch "$tool_dir/captures/.gdignore"
out="$(mktemp -d "$tool_dir/captures/native.XXXXXX")"
export FEL03_CAPTURE_DIR="$out"
export FX15_CLOCK_FILE="$out/clock.avi"
trap 'rm -f "$FX15_CLOCK_FILE"' EXIT

python3 tools/visual_probe_runner.py tools/fel03/capture.gd --task-id fel-03     --no-headless --display-driver macos --audio-driver Dummy     --godot tools/fx15/movie_clock.sh --timeout "$capture_timeout"     --proof-contract tools/fel03/proof_contract.json --result-manifest "$out/visual-proof.json"     2>&1 | tee "$out/runner.log"
printf '%s\n' "$out/index.md" "$out/visual-proof.json"
