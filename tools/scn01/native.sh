#!/bin/sh
set -eu

# The visual runner owns the GUI lease, import bootstrap and PNG validation.
# Its batch runs each engine in a fresh task-runner home.
if [ "${SCN01_WINDOWED_BATCH:-}" = 1 ]; then
    exec python3 "$(dirname "$0")/native_batch.py" "$@"
fi

# visual_probe_runner owns window setup, the GUI lease and PNG validation.
# Keep each renderer process under the same task-runner watchdog as dry runs.
if [ "${SCN01_WINDOWED_ENGINE:-}" = 1 ]; then
    exec python3 tools/godot_task_runner.py --task-id "${SCN01_TASK_ID:-scn-01}" --stream \
        --timeout "${SCN01_ENGINE_TIMEOUT}" -- godot "$@"
fi

launcher=$0
if [ -L "$launcher" ]; then
    target=$(readlink "$launcher")
    case "$target" in
        /*) launcher=$target ;;
        *) launcher=$(dirname "$launcher")/$target ;;
    esac
fi
cd "$(dirname "$launcher")/../.."
exec python3 tools/scn01/census.py "$@"
