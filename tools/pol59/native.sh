#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: $0 before|after [--dry-run]" >&2
    exit 2
}

[[ $# -ge 1 && $# -le 2 ]] || usage
variant="$1"
dry_run="${2:-}"
[[ -z "$dry_run" || "$dry_run" == --dry-run ]] || usage

worktree="${POL59_WORKTREE:-/Users/borgerding/workspace/Labyrinth.worktrees/pol-59}"
worktree="$(cd "$worktree" && pwd -P)"
release_sha=92ed73479e58c97aa091300579eeef6f0039e59c
project="$worktree"
case "$variant" in
    before)
        variant_args=(--before)
        project="${POL59_RELEASE_CHECKOUT:-$worktree/../release}"
        project="$(cd "$project" && pwd -P)"
        if [[ "$(git -C "$project" rev-parse HEAD)" != "$release_sha" ]] ||
            ! git -C "$project" diff --quiet "$release_sha" --; then
            echo "The baseline must be a clean checkout of $release_sha. Set POL59_RELEASE_CHECKOUT to its path." >&2
            exit 1
        fi
        ;;
    after) variant_args=(--after) ;;
    *) usage ;;
esac

out_root="${POL59_OUTPUT_ROOT:-/private/tmp/labyrinth_codex/pol-59}"
mkdir -p "$out_root"
out="$(mktemp -d "$out_root/$variant.XXXXXX")"
printf 'POL59 output directory %s\n' "$out"
printf 'POL59 scenario manifest %s\n' "$out/semantics.json"
probe="$worktree/tools/pol59/capture.gd"
cd "$project"
export LABYRINTH_CEL_LOOK=all
python3 tools/cel_look.py status
if [[ "$dry_run" == --dry-run ]]; then
    exec python3 tools/godot_task_runner.py --task-id pol-59 --stream -- \
        godot --headless --fixed-fps 60 --path . --script "$probe" -- \
        "${variant_args[@]}" --dry-run --output-dir "$out"
fi

printf 'POL59 visual manifest %s\n' "$out/visual-result.json"
exec python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy --timeout 180 \
    "$probe" --task-id pol-59 --expect-size 1920x1080 \
    --proof-contract "$worktree/tools/pol59/proof_contract.json" \
    --result-manifest "$out/visual-result.json" -- "${variant_args[@]}" --output-dir "$out"
