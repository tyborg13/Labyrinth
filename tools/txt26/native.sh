#!/usr/bin/env bash
set -euo pipefail

task_checkout=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)
cd "$task_checkout"
base_checkout=$(cd "${TXT26_BASE_CHECKOUT:-../mrg-14}" && pwd -P)
base_ref=$(git rev-parse codex/mrg-14)
base_head=$(git -C "$base_checkout" rev-parse HEAD)
if [[ "$base_head" != "$base_ref" ]]; then
    printf 'Base checkout %s is at %s. Capture requires codex/mrg-14 at %s.\n' "$base_checkout" "$base_head" "$base_ref" >&2
    exit 1
fi

out_root=$(mktemp -d /private/tmp/labyrinth_codex/txt-26/captures.XXXXXX)
printf 'Capture output folder: %s\n' "$out_root"
export LABYRINTH_CEL_LOOK=all
probe="$task_checkout/tools/txt26/capture_relics.gd"
export TXT26_OUTPUT="$out_root/after"
mkdir -p "$TXT26_OUTPUT"

if [[ "${1:-}" == --dry-run ]]; then
    export TXT26_BATCH=director TXT26_CAPTURE=0
    mkdir -p "$out_root/before"
    TXT26_PHASE=before TXT26_OUTPUT="$out_root/before" python3 tools/godot_task_runner.py \
        --project "$base_checkout" --task-id txt-26 --stream -- godot --headless --path . --script "$probe"
    TXT26_PHASE=after python3 tools/godot_task_runner.py \
        --task-id txt-26 --stream -- godot --headless --path . --script "$probe"
    exit
fi

run_capture() {
    local phase=$1 batch=$2 project=$3 contract=$4 directory=$5
    export TXT26_PHASE="$phase" TXT26_BATCH="$batch" TXT26_OUTPUT="$out_root/$directory" TXT26_CAPTURE=1
    mkdir -p "$TXT26_OUTPUT"
    python3 tools/visual_probe_runner.py "$probe" --project "$project" --task-id txt-26 \
        --no-headless --display-driver macos --audio-driver Dummy \
        --proof-contract "$task_checkout/tools/txt26/${contract}_proof.json" \
        --result-manifest "$TXT26_OUTPUT/manifest.json"
}

run_capture before director "$base_checkout" before before
run_capture after director "$task_checkout" after after
run_capture after edited "$task_checkout" text_fit text_fit
printf 'Capture output folder: %s\n' "$out_root"
