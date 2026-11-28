#!/usr/bin/env bash
# Shared replay setup. Run from the fel-32 worktree.
set -euo pipefail

release="$(cd "${1:?release worktree required}" && pwd)"
transcript="${FEL32_TRANSCRIPT:-/private/tmp/labyrinth_codex/fel-30/inputs.jsonl}"
test -s "$transcript"
output="$(python3 -c 'import pathlib,sys; print(pathlib.Path(sys.argv[1]).resolve())' "${2:?fresh output directory required}")"
mkdir "$output"
export LABYRINTH_CEL_LOOK=all LABYRINTH_PROBE_WINDOW=1
runner=(python3 tools/godot_task_runner.py --task-id fel-32 --stream)
replay_timeout=600
for side in release branch; do
    project="$PWD"
    if [[ "$side" == release ]]; then project="$release"; fi
    pack_args=("$project" "$output/$side.pck")
    if [[ "${FEL32_TRACE:-0}" == 1 ]]; then
        python3 tools/fel32/stage_trace.py "$project" "$output/$side-sources"
        pack_args+=("$output/$side-sources")
    fi
    "${runner[@]}" -- godot --headless --path . --script tools/fel32/pack.gd -- "${pack_args[@]}"
done
