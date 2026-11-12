#!/bin/sh
set -eu
RD03_MODE=${1:-stills}
RD03_OUTPUT=/private/tmp/labyrinth_codex/rd-03/feedback1
case "$RD03_MODE" in
    stills) RD03_ENGINE=tools/rd03/native_capture.sh; RD03_CONTRACT=tools/rd03/capture_contract.json ;;
    movie) RD03_ENGINE=tools/rd03/movie_capture.sh; RD03_CONTRACT=tools/rd03/movie_contract.json ;;
    *) printf 'Usage: %s [stills|movie]\n' "$0" >&2; exit 2 ;;
esac
export LABYRINTH_CEL_LOOK=all
exec python3 tools/visual_probe_runner.py --godot "$RD03_ENGINE" --no-headless --display-driver macos --audio-driver Dummy --rendering-driver metal --rendering-method mobile --fallback-rendering-driver metal --timeout 120 --expect-size 1920x1080 --proof-contract "$RD03_CONTRACT" --result-manifest "$RD03_OUTPUT/${RD03_MODE}_probe_manifest.json" tools/rd03/capture.gd --task-id rd-03 -- --fixed-fps 30
