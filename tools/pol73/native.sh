#!/usr/bin/env bash
set -euo pipefail

proof_root=/private/tmp/labyrinth_codex/pol-73
script_dir="$PWD/tools/pol73"
baseline="$PWD/../txt-27"
baseline_head=35b683909a444d60f4d35c3406963e38fa6a37d7
native_timeout=180
export LABYRINTH_CEL_LOOK=all

if [[ ! -f "$script_dir/capture.gd" || "$(git branch --show-current)" != codex/pol-73 ]]; then
    printf 'Run this launcher from the codex/pol-73 worktree.\n' >&2
    exit 2
fi
if [[ "$(git -C "$baseline" branch --show-current)" != codex/txt-27 ||
      "$(git -C "$baseline" rev-parse HEAD)" != "$baseline_head" ]]; then
    printf 'The sibling txt-27 worktree must be on codex/txt-27 at %s.\n' "$baseline_head" >&2
    exit 2
fi
if ! git -C "$baseline" diff --quiet "$baseline_head" --; then
    printf 'The sibling txt-27 worktree has tracked changes.\n' >&2
    exit 2
fi

mkdir -p "$proof_root"
output="$(mktemp -d "$proof_root/captures.XXXXXX")"
printf 'pol-73 proof output folder: %s\n' "$output"

render() {
    local project="$1" label="$2" contract="$3"
    shift 3
    python3 tools/visual_probe_runner.py "$script_dir/capture.gd" --project "$project" \
        --task-id pol-73 --no-headless --display-driver macos --audio-driver Dummy \
        --timeout "$native_timeout" --expect-size 1920x1080 --proof-contract "$contract" \
        --result-manifest "$output/$label/proof.json" -- --output="$output/$label" "$@"
}

validate() {
    local project="$1" label="$2"
    shift 2
    local log="$output/$label.log"
    if ! python3 tools/godot_task_runner.py --task-id pol-73 --stream -- godot \
        --headless --path "$project" --script "$script_dir/capture.gd" \
        -- --validate-only --output="$output/$label" "$@" > "$log" 2>&1; then
        tail -n 30 "$log" >&2
        return 1
    fi
    rg '^POL73 HEADLESS LAYOUT' "$log"
}

case "${1:-}" in
    --dry-run)
        validate "$baseline" before --before
        validate "$PWD" after
        ;;
    "")
        render "$baseline" before "$script_dir/proof-before.json" --before
        render "$PWD" after "$script_dir/proof-after.json"
        ;;
    *)
        printf 'Usage: %s [--dry-run]\n' "$0" >&2
        exit 2
        ;;
esac
