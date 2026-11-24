#!/bin/bash
set -euo pipefail

cd "$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
project="$PWD"
probe=tools/gfix55/native.gd
# codex/release at the start of gfix-55.
baseline_ref=e3b27e209cd2f4a9e6ccc2e971d4b0a23c581e1a
before=0
dry_run=0
for arg in "$@"; do
    case "$arg" in
        --before) before=1 ;;
        --dry-run) dry_run=1 ;;
        *) printf 'Usage: %s [--before] [--dry-run]\n' "$0" >&2; exit 2 ;;
    esac
done
export LABYRINTH_CEL_LOOK=all PYTHONDONTWRITEBYTECODE=1
export GFIX55_BASELINE="$before"
if [[ ! -f cel_look_variants/manifest.json ]]; then
    printf 'GFIX55 requires the prepared cel-look variants in this worktree.\n' >&2
    exit 1
fi
mkdir -p .godot/gfix55

if [[ "$before" == 1 ]]; then
    label=before
    stage=$(mktemp -d "$PWD/.godot/gfix55/release.XXXXXX")
    trap 'rm -rf "$stage"' EXIT
    git archive "$baseline_ref" | tar -xf - -C "$stage"
    mkdir -p "$stage/tools/gfix55" "$stage/.godot"
    cp "$probe" tools/gfix55/.gdignore "$stage/tools/gfix55/"
    cp -cRp cel_look_variants "$stage/"
    # This worktree has the release imports. Clone them so the staged project
    # can use or rebuild its own cache without writing to the active cache.
    if [[ "$(git rev-parse HEAD)" == "$baseline_ref" && -d .godot/imported ]]; then
        cp -cRp .godot/imported "$stage/.godot/"
        for name in global_script_class_cache.cfg uid_cache.bin extension_list.cfg; do
            if [[ -f ".godot/$name" ]]; then cp -p ".godot/$name" "$stage/.godot/"; fi
        done
    fi
    project="$stage"
else
    label=after
fi

if [[ "$dry_run" == 1 ]]; then
    python3 tools/godot_task_runner.py --task-id gfix-55 --project "$project" --stream -- godot \
        --headless --path "$project" --script "$probe"
    exit
fi

GFIX55_OUTPUT=$(mktemp -d "$PWD/.godot/gfix55/$label.XXXXXX")
export GFIX55_OUTPUT
status=0
python3 tools/visual_probe_runner.py "$probe" --project "$project" --task-id gfix-55 \
    --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 \
    --godot-home-root "$GFIX55_OUTPUT/home" --proof-contract tools/gfix55/proof_contract.json \
    --result-manifest "$GFIX55_OUTPUT/manifest.json" \
    2>&1 | tee "$GFIX55_OUTPUT/runner.log" || status=$?

if [[ -s "$GFIX55_OUTPUT/board.png" ]]; then
    printf 'GFIX55 CAPTURE: %s\n' "$GFIX55_OUTPUT/board.png"
fi
logs=("$GFIX55_OUTPUT"/home/*/godot.log)
if [[ "${#logs[@]}" != 1 || ! -f "${logs[0]}" ]]; then
    printf 'GFIX55 BOOT ERRORS: unavailable (missing or ambiguous Godot log)\n' >&2
    exit 1
fi
log="${logs[0]}"
grep -E '^(SCRIPT ERROR|ERROR|WARNING):' "$log" || true
errors=$(grep -Ec '^(SCRIPT ERROR|ERROR):' "$log" || true)
warnings=$(grep -Ec '^WARNING:' "$log" || true)
printf 'GFIX55 BOOT ERRORS: %s\nGFIX55 BOOT WARNINGS: %s\nGFIX55 BOOT LOG: %s\n' "$errors" "$warnings" "$log"
[[ -s "$GFIX55_OUTPUT/board.png" ]] && grep -Fq 'GFIX55 NATIVE PROOF: PASS' "$log" || exit 1

if [[ "$before" == 1 ]]; then
    # The visual runner correctly flags the release script error. The control
    # succeeds only if the probe finished and all three reported errors appear.
    grep -Fq 'Parent node is busy setting up children' "$log"
    grep -Fq 'Parameter "data.tree" is null' "$log"
    grep -Fq "Invalid access to property or key 'process_frame'" "$log"
else
    [[ "$status" == 0 && "$errors" == 0 && "$warnings" == 0 ]]
fi
