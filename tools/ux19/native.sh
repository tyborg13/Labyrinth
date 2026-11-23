#!/usr/bin/env bash
# Run from the ux-19 worktree.
set -euo pipefail

output=/private/tmp/labyrinth_codex/ux-19
captures="$output/captures"
export LABYRINTH_CEL_LOOK=all
mkdir -p "$output"

case "${1:---windowed}" in
  --dry-run)
    state="$(mktemp -d "$output/restart.XXXXXX")/settings.json"
    probe=(python3 tools/godot_task_runner.py --task-id ux-19 --stream -- godot
      --headless --path . --script tools/ux19/probe.gd --)
    "${probe[@]}" --settings-path "$state" --output-dir "$captures"
    "${probe[@]}" --settings-path "$state" --verify-restart
    ;;
  --windowed)
    python3 tools/visual_probe_runner.py --task-id ux-19 --no-headless \
      --display-driver macos --audio-driver Dummy --timeout 120 --startup-timeout 25 \
      --expect-size 1920x1080 --expect-size 1280x800 \
      --proof-contract tools/ux19/proof_contract.json \
      --result-manifest "$output/renderer.json" --overwrite-result-manifest \
      tools/ux19/probe.gd -- --output-dir "$captures"
    ;;
  *)
    echo "Usage: $0 [--windowed|--dry-run]" >&2
    exit 2
    ;;
esac
