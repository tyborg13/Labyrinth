#!/usr/bin/env bash
set -euo pipefail

# Keep the same probe in both revisions. The candidate worktree is read in place.
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if [[ ! -f "$script_dir/capture.gd" ]]; then
    script_dir="/Users/borgerding/workspace/Labyrinth.worktrees/txt-27/tools/txt27"
fi
worktree="$(cd -- "$script_dir/../.." && pwd)"
baseline="${TXT27_BASELINE:-$worktree/../txt-25}"
proof_root="${TXT27_OUTPUT_ROOT:-/private/tmp/labyrinth_codex/txt-27}"
output="$(mktemp -d "$proof_root/captures.XXXXXX")"
native_timeout=180
export LABYRINTH_CEL_LOOK=all

render() {
    local project="$1" label="$2" size="$3"
    shift 3
    mkdir -p "$output/$label"
    (
        cd "$project"
        python3 tools/visual_probe_runner.py "$script_dir/capture.gd" \
            --task-id txt-27 --no-headless --display-driver macos --audio-driver Dummy \
            --timeout "$native_timeout" --expect-size "$size" \
            --proof-contract "$script_dir/proof-$size.json" \
            --result-manifest "$output/$label/proof.json" -- --output="$output/$label" "$@"
    )
}

validate() {
    local label="$1"
    shift
    (
        cd "$worktree"
        python3 tools/godot_task_runner.py --task-id txt-27 --stream -- godot \
            --headless --path . --script "$script_dir/capture.gd" \
            -- --validate-only --output="$output/$label" "$@" > "$output/$label.log" 2>&1
    )
    tail -n 5 "$output/$label.log"
}

printf 'txt-27 proof output folder: %s\n' "$output"
case "${1:-}" in
    --dry-run)
        validate after-1920x1080
        validate after-1280x800 --compact
        ;;
    "")
        render "$baseline" before-1920x1080 1920x1080 --before
        render "$worktree" after-1920x1080 1920x1080
        render "$worktree" after-1280x800 1280x800 --compact
        ;;
    *)
        printf 'Usage: %s [--dry-run]\n' "$0" >&2
        exit 2
        ;;
esac
