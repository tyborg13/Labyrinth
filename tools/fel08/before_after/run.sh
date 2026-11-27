#!/usr/bin/env bash
set -euo pipefail

tool_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project="$(cd "$tool_dir/../../.." && pwd)"
release="$(cd "$project/../release" && pwd)"
cd "$project"
capture_timeout=240
expected_release=7ba6cacac

case "$#:${1:-}" in
    0:) mode=native ;;
    1:--dry-run) mode=dry ;;
    *) echo "Usage: $0 [--dry-run]" >&2; exit 2 ;;
esac

if [[ "$(git -C "$release" rev-parse --abbrev-ref HEAD)" != codex/release ||
      "$(git -C "$release" rev-parse --short=9 HEAD)" != "$expected_release" ||
      -n "$(git --no-optional-locks -C "$release" status --porcelain --untracked-files=no)" ]]; then
    echo "FEL08 BA requires a clean release at codex/release $expected_release" >&2
    exit 1
fi

mkdir -p "$tool_dir/captures"
touch "$tool_dir/captures/.gdignore"
output="$(mktemp -d "$tool_dir/captures/$mode.XXXXXX")"
mkdir "$output/release" "$output/branch"
printf 'FEL08 BA capture directory %s\n' "$output"
export PYTHONDONTWRITEBYTECODE=1
export LABYRINTH_CEL_LOOK=all
export FEL08_BA_MODE="$mode" FEL08_BA_OUTPUT="$output" FEL08_BA_TOOL="$tool_dir"

python3 "$tool_dir/cases.py" "$output"
run_headless() {
    python3 tools/godot_task_runner.py --task-id fel-08 --timeout "$capture_timeout" \
        --stream -- godot --headless --path "$1" --script "$2"
}
run_headless "$project" "$tool_dir/prepare.gd" 2>&1 | tee "$output/prepare.log"

# The visual runner may bootstrap imports and writes a temporary window override.
# Give it an APFS copy of release so those writes never reach the release worktree.
release_project="$release"
if [[ "$mode" == native ]]; then
    release_project="$output/release-project"
    trap 'rm -rf "$release_project"' EXIT
    cp -cRp "$release" "$release_project"
fi

failed=0
for side in release branch; do
    repo="$project"
    if [[ "$side" == release ]]; then repo="$release_project"; fi
    export FEL08_BA_SIDE="$side"
    printf 'FEL08 BA %s %s\n' "$mode" "$side"
    if [[ "$mode" == dry ]]; then
        run_headless "$repo" "$tool_dir/session.gd" 2>&1 | tee "$output/$side/runner.log" || failed=1
    else
        python3 tools/visual_probe_runner.py --task-id fel-08 --project "$repo" \
            --no-headless --display-driver macos --audio-driver Dummy --timeout "$capture_timeout" \
            --expect-size 1920x1080 --proof-contract "$output/proof-contract.json" \
            --result-manifest "$output/$side/visual-proof.json" "$tool_dir/session.gd" \
            2>&1 | tee "$output/$side/runner.log" || failed=1
    fi
done
if [[ "$mode" == native ]]; then
    python3 "$tool_dir/pairs.py" "$output" || failed=1
fi
exit "$failed"
