#!/bin/bash
set -euo pipefail

repo=$(cd "$(dirname "$0")/../.." && pwd -P)
cd "$repo"
phase=${1:?Usage: inventories.sh before|after [output-directory]}
case "$phase" in
    before|after) ;;
    *) exit 2 ;;
esac
proof=${2:-"$repo/output/txt43"}
mkdir -p "$proof"
proof=$(cd "$proof" && pwd -P)
touch "$repo/output/.gdignore"

run() {
    python3 tools/godot_task_runner.py --task-id txt-43 --stream -- godot --headless --path . "$@"
}
TXT38_GRIMOIRE="$repo/data/grimoire.json" TXT38_INVENTORY="$proof/$phase.json" \
    run --script tools/txt38/inventory.gd | tee "$proof/$phase.log"
run --script tools/txt41/live_inventory.gd -- "$proof/live-$phase.json" | tee "$proof/live-$phase.log"
run --script tools/crd33/dump_cards.gd -- "$proof/cards-$phase.json" | tee "$proof/cards-$phase.log"
