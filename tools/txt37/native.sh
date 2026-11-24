#!/bin/bash
set -euo pipefail

repo=$(cd "$(dirname "$0")/../.." && pwd -P)
cd "$repo"

case "${1:-}" in
    ""|--dry-run) ;;
    *) printf 'Usage: %s [--dry-run]\n' "$0" >&2; exit 2 ;;
esac

proof_root=/private/tmp/labyrinth_codex/txt-37
mkdir -p "$proof_root"
output=$(mktemp -d "$proof_root/proof.XXXXXX")
export LABYRINTH_CEL_LOOK=all
export TXT37_GRIMOIRE="$output/txt36-grimoire.json"
export TXT37_OUTPUT="$output/after"
git show codex/txt-36:data/grimoire.json > "$TXT37_GRIMOIRE"
printf 'TXT37 OUTPUT FOLDER %s\n' "$output"

if [[ "${1:-}" == --dry-run ]]; then
    python3 tools/godot_task_runner.py --task-id txt-37 --stream -- godot --headless \
        --path . --script res://tools/txt37/pages.gd | tee "$output/after.log"
else
    python3 tools/visual_probe_runner.py --task-id txt-37 --no-headless \
        --display-driver macos --audio-driver Dummy --expect-size 1920x1080 \
        --proof-contract tools/txt37/native_contract.json \
        --result-manifest "$output/after-captures.json" res://tools/txt37/pages.gd | tee "$output/after.log"
fi
