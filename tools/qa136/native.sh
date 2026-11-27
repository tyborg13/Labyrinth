#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
export LABYRINTH_CEL_LOOK=all

if [[ "${1:-}" == "--headless" ]]; then
	exec python3 tools/godot_task_runner.py --task-id qa-136 --stream -- godot --headless --path . --script tools/qa136/witness.gd -- --native
fi

exec python3 tools/visual_probe_runner.py tools/qa136/witness.gd --task-id qa-136 \
	--no-headless --display-driver macos --audio-driver Dummy \
	--proof-contract tools/qa136/chronicle_contract.json \
	--result-manifest output/qa136/native-result.json "$@" -- --native
