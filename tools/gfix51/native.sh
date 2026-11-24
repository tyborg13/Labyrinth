#!/bin/bash
set -euo pipefail

case "${1:-}" in
    ""|--dry-run) ;;
    *) printf 'Usage: %s [--dry-run]\n' "$0" >&2; exit 2 ;;
esac

repo=$(cd "$(dirname "$0")/../.." && pwd -P)
cd "$repo"
export LABYRINTH_CEL_LOOK=all
proof_root="$repo/output/gfix51"
probe=res://tools/gfix51/list_scroll.gd

mkdir -p "$proof_root"
python3 tools/output_gdignore.py >/dev/null
export GFIX51_CAPTURE_OUTPUT
GFIX51_CAPTURE_OUTPUT=$(mktemp -d "$proof_root/native.XXXXXX")
if [[ "${1:-}" == --dry-run ]]; then
    python3 tools/godot_task_runner.py --task-id gfix-51 --stream -- godot --headless \
        --path . --script "$probe" 2>&1 | tee "$GFIX51_CAPTURE_OUTPUT/probe.log"
else
    python3 tools/visual_probe_runner.py --task-id gfix-51 --no-headless \
        --display-driver macos --audio-driver Dummy --expect-size 1920x1080 \
        --proof-contract tools/gfix51/native_contract.json \
        --result-manifest "$GFIX51_CAPTURE_OUTPUT/captures.json" "$probe" 2>&1 | tee "$GFIX51_CAPTURE_OUTPUT/probe.log"
fi
