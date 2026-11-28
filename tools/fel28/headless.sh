#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
release="$(cd "${1:?release worktree}" && pwd)"
out="${2:?fresh output directory}"
mkdir -p "$out"
out="$(cd "$out" && pwd)"
export FEL28_TOOLS="$root/tools"
cd "$root"
cases=(shadow humanoid multi burst terrain enemy_turn midfight reduced)
for build in release branch; do
    project="$root"
    if [[ "$build" == release ]]; then project="$release"; fi
    FEL28_OUTPUT="$out/$build/roster"
    mkdir -p "$FEL28_OUTPUT"
    export FEL28_OUTPUT
    python3 tools/godot_task_runner.py --task-id fel-28 --stream -- godot --headless --path "$project" \
        --script "$root/tools/fel28/deaths.gd" > "$FEL28_OUTPUT/runner.log" 2>&1
    for name in "${cases[@]}" quit-death quit-victory quit-reveal quit-enemy-death quit-enemy-victory quit-enemy-reveal; do
        export FEL28_OUTPUT="$out/$build/$name" FEL28_QUIT_AT="" FEL28_CASE="$name"
        if [[ "$name" == quit-enemy-* ]]; then
            export FEL28_CASE=enemy_turn FEL28_QUIT_AT="${name#quit-enemy-}"
        elif [[ "$name" == quit-* ]]; then
            export FEL28_CASE=shadow FEL28_QUIT_AT="${name#quit-}"
        fi
        mkdir -p "$FEL28_OUTPUT"
        python3 tools/godot_task_runner.py --task-id fel-28 --stream -- godot --headless --path "$project" \
            --script "$root/tools/fel28/probe.gd" >"$FEL28_OUTPUT/runner.log" 2>&1
    done
done
export FEL28_OUTPUT="$out/branch/quit-enemy-checkpoint" FEL28_CASE=enemy_turn FEL28_QUIT_AT=checkpoint
mkdir -p "$FEL28_OUTPUT"
python3 tools/godot_task_runner.py --task-id fel-28 --stream -- godot --headless --path "$root" \
    --script "$root/tools/fel28/probe.gd" > "$FEL28_OUTPUT/runner.log" 2>&1
python3 tools/fel28/report.py headless "$out"
