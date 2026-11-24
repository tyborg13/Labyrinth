#!/bin/bash
set -euo pipefail

repo=$(cd "$(dirname "$0")/../.." && pwd -P)
cd "$repo"
base=23152865ae25efdea3a915fc7bb56fe2a10e18fd
base_project=${TXT34_BASE_PROJECT:-"$repo/../release"}
proof_root=/private/tmp/labyrinth_codex/txt-34
export LABYRINTH_CEL_LOOK=all

case "${1:-}" in
    "") dry_run=0 ;;
    --dry-run) dry_run=1 ;;
    *) printf 'Usage: %s [--dry-run]\n' "$0" >&2; exit 2 ;;
esac
if [[ $(git -C "$base_project" rev-parse HEAD) != "$base" ]] || \
        [[ -n $(git -C "$base_project" status --porcelain) ]]; then
    printf 'TXT34_BASE_PROJECT must point to a clean checkout of %s\n' "$base" >&2
    exit 1
fi

mkdir -p "$proof_root"
output=$(mktemp -d "$proof_root/proof.XXXXXX")
printf 'TXT34 OUTPUT FOLDER %s\n' "$output"

# Copy-on-write snapshot keeps import files, cel variants and GUI runner
# overrides local to this proof. Neither worktree's Git metadata is changed.
baseline="$output/base-project"
mkdir "$baseline"
shopt -s dotglob
for path in "$base_project"/*; do
    case "${path##*/}" in .git|.codex|override.cfg) continue ;; esac
    cp -cRp "$path" "$baseline/"
done
mkdir -p "$baseline/tools/txt34"
cp tools/txt34/pages.gd tools/txt34/pages.gd.uid "$baseline/tools/txt34/"

for version in before after; do
    project="$baseline"
    [[ "$version" == before ]] || project="$repo"
    export TXT34_VERSION="$version"
    export TXT34_OUTPUT="$output/$version"
    if [[ "$dry_run" == 1 ]]; then
        python3 tools/godot_task_runner.py --task-id txt-34 --stream -- godot --headless \
            --path "$project" --script res://tools/txt34/pages.gd | tee "$output/$version.log"
    else
        python3 tools/visual_probe_runner.py --project "$project" --task-id txt-34 --no-headless \
            --display-driver macos --audio-driver Dummy --expect-size 1920x1080 \
            --proof-contract tools/txt34/native_contract.json \
            --result-manifest "$output/$version-captures.json" res://tools/txt34/pages.gd | tee "$output/$version.log"
    fi
done

python3 - "$output" <<'PY'
import json
from pathlib import Path
import sys

root = Path(sys.argv[1])
before, after = (
    json.loads((root / version / "inventory.json").read_text())
    for version in ("before", "after")
)
assert before["inspection"] == after["inspection"], "Bone Harrier inspection control tree changed"
print("TXT34 COMPARISON: PASS (Bone Harrier pre-battle text, icons and layout identical)")
PY

TXT34_OUTPUT="$output/after" python3 tools/godot_task_runner.py --task-id txt-34 --stream -- \
    godot --headless --path . --script tools/txt34/witnesses.gd | tee "$output/witnesses.log"
printf 'TXT34 OUTPUT FOLDER %s\n' "$output"
