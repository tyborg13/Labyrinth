#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."

mode=${1:-}
case "$mode" in
    ""|--dry-run|--witness) ;;
    *) printf 'Usage: %s [--dry-run|--witness]\n' "$0" >&2; exit 2 ;;
esac

output="$PWD/output/fel12/feedback-1"
staging=$(mktemp -d .godot/fel12-base.XXXXXX)
trap 'rm -rf "$staging"' EXIT
export LABYRINTH_CEL_LOOK=all PYTHONDONTWRITEBYTECODE=1

# Use the director-approved round-0 implementation with both hand guards.
base_revision=f613d398ebcb20b03dfe176f382f387d680a888a
printf 'FEL12 base revision: %s\n' "$base_revision"
git show "$base_revision:scripts/combat_board_view.gd" | sed \
    -e '/^class_name CombatBoardView$/d' \
    -e "s|res://scripts/combat_board_view.gd|res://$staging/combat_board_view.gd|g" \
    > "$staging/combat_board_view.gd"

headless=(python3 tools/godot_task_runner.py --task-id fel-12 --stream -- godot
    --headless --fixed-fps 60 --path . --script tools/fel12/witness.gd)
if [[ "$mode" == "--dry-run" ]]; then
    printf 'FEL12 windowed command: cd %q && LABYRINTH_CEL_LOOK=all bash tools/fel12/native.sh\n' "$PWD"
fi

run_version() {
    local version=$1
    shift
    local destination="$output/native/$version"
    case "$mode" in
        --witness) "${headless[@]}" -- "$@" ;;
        --dry-run) "${headless[@]}" -- --native --out "$destination" "$@" ;;
        "")
            mkdir -p "$destination"
            python3 tools/visual_probe_runner.py tools/fel12/witness.gd --task-id fel-12 \
                --no-headless --display-driver macos --audio-driver Dummy \
                --expect-size 1920x1080 --proof-contract tools/fel12/proof_contract.json \
                --result-manifest "$destination/manifest.json" --overwrite-result-manifest \
                -- --native --out "$destination" "$@"
            ;;
    esac
}

# The base is expected to fail; keep going so the branch always runs.
base_status=0
run_version base --base-script "res://$staging/combat_board_view.gd" || base_status=$?
printf 'FEL12 base exit: %s\n' "$base_status"
run_version branch
