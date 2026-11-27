#!/usr/bin/env bash
set -euo pipefail

tool_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$tool_dir/../.."

export LABYRINTH_CEL_LOOK=all
if [[ -z "${FEL10_BUNDLE:-}" ]]; then
    export FEL10_BUNDLE="$tool_dir/fixtures"
    export FEL10_RETRIES="${FEL10_RETRIES:-$tool_dir/retries}"
fi
export FEL10_ONLY=""
capture_timeout=1800
mode=native

usage() {
    printf 'Usage: %s [--dry-run | --witness] [--only id,...]\n' "$0" >&2
    exit 2
}

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --dry-run|--witness)
            [[ "$mode" == native ]] || usage
            mode="${1#--}"
            shift ;;
        --only)
            [[ -z "$FEL10_ONLY" && "$#" -ge 2 && "$2" =~ ^[a-z0-9_]+(,[a-z0-9_]+)*$ ]] || usage
            export FEL10_ONLY="$2"
            shift 2 ;;
        *) usage ;;
    esac
done

if [[ "$mode" != native ]]; then
    exec python3 tools/godot_task_runner.py --task-id fel-10 --timeout "$capture_timeout" \
        --stream -- godot --headless --fixed-fps 60 --path . \
        --script tools/fel10/replay.gd -- "--$mode"
fi

mkdir -p "$tool_dir/captures"
touch "$tool_dir/captures/.gdignore"
out="$(mktemp -d "$tool_dir/captures/native.XXXXXX")"
export FEL10_CAPTURE_DIR="$out"
export FX15_CLOCK_FILE="$out/clock.avi"
trap 'test ! -f "$FX15_CLOCK_FILE" || rm -- "$FX15_CLOCK_FILE"' EXIT

python3 tools/visual_probe_runner.py tools/fel10/replay.gd --task-id fel-10 \
    --no-headless --display-driver macos --audio-driver Dummy \
    --godot tools/fx15/movie_clock.sh --timeout "$capture_timeout" \
    --proof-contract tools/fel10/proof_contract.json --result-manifest "$out/visual-proof.json" \
    2>&1 | tee "$out/runner.log"
printf '%s\n' "$out/index.md" "$out/visual-proof.json"
