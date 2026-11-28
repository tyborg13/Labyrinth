#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
root="$PWD"
release="$(cd "${1:?release worktree}" && pwd)"
out="${2:?fresh output directory}"
mkdir -p "$out"
out="$(cd "$out" && pwd)"
export FEL28_TOOLS="$root/tools" LABYRINTH_CEL_LOOK=all
for build in release branch; do
    project="$root"
    if [[ "$build" == release ]]; then project="$release"; fi
    for name in shadow humanoid multi enemy_turn; do
        export FEL28_CASE="$name" FEL28_OUTPUT="$out/$build/$name" FEL28_QUIT_AT=""
        mkdir -p "$FEL28_OUTPUT"
        python3 tools/visual_probe_runner.py --task-id fel-28 --project "$project" --no-headless \
            --display-driver macos --timeout 90 --expect-size 1920x1080 \
            --proof-contract "$root/tools/fel28/proof_contract.json" \
            --result-manifest "$FEL28_OUTPUT/visual-proof.json" "$root/tools/fel28/probe.gd" \
            2>&1 | tee "$FEL28_OUTPUT/runner.log"
    done
done
python3 tools/fel28/report.py native "$out" | tee "$out/native-results.log"
