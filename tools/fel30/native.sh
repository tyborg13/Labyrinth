#!/usr/bin/env bash
set -euo pipefail

tool_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$tool_dir/../.."
output=/private/tmp/labyrinth_codex/fel-30
dry_run=0
while (( $# )); do
    case "$1" in
        --dry-run) dry_run=1; shift ;;
        --output) output="${2:?missing census output path}"; shift 2 ;;
        *) printf 'Usage: %s [--dry-run] [--output PATH]\n' "$0" >&2; exit 2 ;;
    esac
done
output="$(cd "$output" && pwd)"
python3 tools/fel30/report.py check --output "$output"
if (( dry_run )); then
    printf 'FEL30 WINDOWED COMMAND cd %q && bash tools/fel30/native.sh --output %q\n' "$PWD" "$output"
    exit 0
fi

run="$(mktemp -d "$output/native.XXXXXX")"
overlay="$run/overlay"
runner=(python3 tools/godot_task_runner.py --task-id fel-30 --stream)
export LABYRINTH_CEL_LOOK=all LABYRINTH_PROBE_WINDOW=1
export FEL30_OUTPUT="$run/frames" FEL30_OVERLAY="$overlay/census.pck"
export FEL30_REPLAY="$output/inputs.jsonl" FEL30_SELECTION="$output/selection.json"
unset FEL30_SEED_START FEL30_SEED_LIMIT
python3 tools/fel30/prepare.py "$overlay"
"${runner[@]}" -- godot --headless --path . --script tools/fel30/pack.gd -- "$overlay"
python3 tools/visual_probe_runner.py --task-id fel-30 --no-headless --display-driver macos --godot "$tool_dir/godot-native.sh" \
    --timeout 3600 --expect-size 1920x1080 --min-images "$(python3 -c 'import json,sys; print(len(json.load(open(sys.argv[1]))))' "$FEL30_SELECTION")" \
    --proof-contract tools/fel30/proof_contract.json --result-manifest "$run/visual-proof.json" \
    tools/fel30/census.gd 2>&1 | tee "$run/runner.log"
"${runner[@]}" -- godot --headless --path . --script tools/fel30/media.gd -- "$output" "$FEL30_OUTPUT"
python3 tools/fel30/report.py native --output "$output"
printf 'FEL30 VISUAL PROOF %s\n' "$run/visual-proof.json"
