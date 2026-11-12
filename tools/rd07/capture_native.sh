#!/bin/sh
set -eu
RD07_MODE=${1:-stills}
RD07_OUTPUT=/private/tmp/labyrinth_codex/rd-07
mkdir -p "$RD07_OUTPUT"
case "$RD07_MODE" in
    stills) RD07_ENGINE=tools/rd07/native_capture.sh; RD07_CONTRACT=tools/rd07/capture_contract.json; set -- ;;
    zekarion) RD07_ENGINE=tools/rd07/native_capture.sh; RD07_CONTRACT=tools/rd07/zekarion_contract.json; set -- --zekarion ;;
    movie) RD07_ENGINE=tools/rd07/movie_capture.sh; RD07_CONTRACT=tools/rd07/movie_contract.json; set -- --clip --fixed-fps 30 ;;
    *) printf 'Usage: %s [stills|zekarion|movie]\n' "$0" >&2; exit 2 ;;
esac
export LABYRINTH_CEL_LOOK=all
RD07_LOG="$RD07_OUTPUT/native_$RD07_MODE.log"
if python3 tools/visual_probe_runner.py --godot "$RD07_ENGINE" --no-headless --display-driver macos --audio-driver Dummy --rendering-driver metal --rendering-method mobile --timeout 300 --expect-size 1920x1080 --proof-contract "$RD07_CONTRACT" --result-manifest "$RD07_OUTPUT/${RD07_MODE}_manifest.json" tools/rd07/capture.gd --task-id rd-07 -- "$@" > "$RD07_LOG" 2>&1; then
    cat "$RD07_LOG"
else
    cat "$RD07_LOG"
    exit 1
fi
if rg -q 'Cel look variant unavailable' "$RD07_LOG"; then
    printf 'RD07 NATIVE: FAIL (Cel look variant unavailable)\n' >&2
    exit 1
fi
if [ "$RD07_MODE" = movie ]; then python3 tools/rd07/finalize_movie.py; fi
