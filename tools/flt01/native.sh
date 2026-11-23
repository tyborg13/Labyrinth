#!/usr/bin/env bash
set -euo pipefail

project="${LABYRINTH_FLT01_PROJECT:-/Users/borgerding/workspace/Labyrinth.worktrees/flt-01}"
base="${LABYRINTH_FLT01_BASE_PROJECT:-$(dirname "$project")/mrg-12}"
base_commit=3a81edc0804a83ac5056b523b007270f0eb78883
proof_root="${LABYRINTH_FLT01_PROOF_ROOT:-/private/tmp/labyrinth_codex/flt-01}"
if [[ "$(git -C "$base" rev-parse HEAD)" != "$base_commit" ]]; then
    printf 'Point LABYRINTH_FLT01_BASE_PROJECT at a prepared checkout of %s\n' "$base_commit" >&2
    exit 1
fi
GIT_OPTIONAL_LOCKS=0 git -C "$base" -c core.fsmonitor=false diff --quiet "$base_commit" -- project.godot scripts scenes data assets

cd "$project"
mkdir -p "$proof_root"
capture="$(mktemp -d "$proof_root/native-XXXXXX")"
printf 'FLT-01 native proof directory %s\n' "$capture"
python3 tools/flt01/sheet.py --contract "$capture/proof-contract.json"

export LABYRINTH_CEL_LOOK=all
for variant in before after; do
    source="$project"
    if [[ "$variant" == before ]]; then source="$base"; fi
    (cd "$source" && python3 tools/cel_look.py build --if-stale)
    LABYRINTH_FLT01_VARIANT="$variant" LABYRINTH_FLT01_OUTPUT="$capture/$variant" \
        python3 tools/visual_probe_runner.py --project "$source" --task-id flt-01 \
        --no-headless --display-driver macos --audio-driver Dummy --rendering-driver metal \
        --timeout 120 --expect-size 1920x1080 --expect-size 640x480 \
        --proof-contract "$capture/proof-contract.json" --result-manifest "$capture/$variant.json" \
        "$project/tools/flt01/fight_probe.gd"
done

python3 tools/flt01/sheet.py "$capture"
