#!/usr/bin/env bash
set -euo pipefail
tool_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$tool_dir/../.."
export LABYRINTH_CEL_LOOK=all
export FEL13_TOOL_DIR="$tool_dir"
if [[ "${1:-}" == --headless ]]; then
    export FEL13_MODE=check
    export FEL13_FIXTURE="${2:-}"
    exec python3 tools/godot_task_runner.py --task-id fel-16 --stream -- godot --headless --path . --script tools/fel13/session.gd
fi
if [[ $# != 1 || ! -f "$tool_dir/fixtures/$1/run.save" || "$1" == */* ]]; then
    echo "Usage: $0 <fixture> | --headless [fixture]" >&2
    exit 2
fi
export FEL13_MODE=play
export FEL13_FIXTURE="$1"
exec python3 tools/godot_task_runner.py --task-id fel-16 --timeout 0 --stream -- godot --windowed --path . --script tools/fel13/session.gd
