#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
out="${1:?fresh output directory}"
mkdir -p "$out"
export FEL28_OUTPUT="$(cd "$out" && pwd)"
root="$PWD"
export LABYRINTH_CEL_LOOK=all FEL28_TOOLS="$root/tools"
python3 tools/visual_probe_runner.py --task-id fel-28 --project "${FEL28_PROJECT:-$root}" --no-headless --display-driver macos \
    --timeout 1800 --expect-size 1920x1080 --proof-contract tools/fel28/proof_contract.json \
    --result-manifest "$FEL28_OUTPUT/visual-proof.json" "$root/tools/fel28/deaths.gd" \
    2>&1 | tee "$FEL28_OUTPUT/runner.log"
