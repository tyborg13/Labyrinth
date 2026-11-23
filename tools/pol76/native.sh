#!/bin/sh
set -eu
export LABYRINTH_CEL_LOOK=all
export PYTHONDONTWRITEBYTECODE=1
export GIT_OPTIONAL_LOCKS=0
task=/Users/borgerding/workspace/Labyrinth.worktrees/pol-76
base=/Users/borgerding/workspace/Labyrinth.worktrees/mrg-17
proof=/private/tmp/labyrinth_codex/pol-76
if [ "${POL76_GODOT_WRAPPER:-}" = "1" ]; then
    exec python3 "$task/tools/godot_task_runner.py" --task-id pol-76 --stream -- godot "$@"
fi
mode=windowed
if [ "${1:-}" = "--headless" ]; then
    mode=headless
    shift
fi
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 [--headless] before|after" >&2
    exit 2
fi
export POL76_PHASE="$1"
case "$POL76_PHASE" in
    before) project="$base" ;;
    after) project="$task" ;;
    *) echo "Expected before or after" >&2; exit 2 ;;
esac
cd "$project"
if [ "$POL76_PHASE" = "before" ]; then
    test "$(git rev-parse HEAD)" = 33d6d09f22c7d846358accccfb7125e6cc43d90f
    git diff --quiet HEAD -- scripts scenes data tests
fi
export POL76_OUTPUT
POL76_OUTPUT="$(mktemp -d "$proof/$POL76_PHASE-$mode.XXXXXX")"
echo "POL-76 output $POL76_OUTPUT"
if [ "$mode" = headless ]; then
    exec python3 "$task/tools/godot_task_runner.py" --task-id pol-76 --stream -- godot \
        --headless --path "$project" --script "$task/tools/pol76/probe.gd"
fi
export POL76_GODOT_WRAPPER=1
exec python3 "$task/tools/visual_probe_runner.py" "$task/tools/pol76/probe.gd" \
    --project "$project" --task-id pol-76 --no-headless --display-driver macos --audio-driver Dummy \
    --godot "$task/tools/pol76/native.sh" \
    --timeout 120 --proof-contract "$task/tools/pol76/native_contract.json" \
    --result-manifest "$POL76_OUTPUT/visual_manifest.json"
