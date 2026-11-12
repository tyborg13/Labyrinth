#!/bin/sh
set -eu
RD04_OUTPUT=/private/tmp/labyrinth_codex/rd-04/feedback2
RD04_PROBE_TIMEOUT_SECONDS=300
export LABYRINTH_CEL_LOOK=all
stills_case() {
    RD04_CASE=$1
    python3 tools/visual_probe_runner.py tools/rd04/threat_isolation_proof.gd --task-id rd-04 --godot "$PWD/tools/rd04/native_capture.sh" --no-headless --display-driver macos --audio-driver Dummy --rendering-method mobile --rendering-driver metal --fallback-rendering-driver metal --timeout "$RD04_PROBE_TIMEOUT_SECONDS" --expect-size 1920x1080 --proof-contract "tools/rd04/${RD04_CASE}_capture_contract.json" --result-manifest "$RD04_OUTPUT/native-$RD04_CASE.json" -- --capture --case "$RD04_CASE" --fixture-manifest "$RD04_OUTPUT/$RD04_CASE.json" --output-dir "$RD04_OUTPUT/stills/$RD04_CASE"
}
case "${1:-stills}" in
fixture)
    exec python3 tools/rd04/prepare_fixtures.py
    ;;
stills)
    stills_case overlap
    stills_case zekarion
    stills_case vyraketh
    ;;
stills-overlap) stills_case overlap ;;
stills-zekarion) stills_case zekarion ;;
stills-vyraketh) stills_case vyraketh ;;
movie)
    export RD04_MOVIE=1
    python3 tools/visual_probe_runner.py tools/rd04/movie_capture.gd --task-id rd-04 --godot "$PWD/tools/rd04/native_capture.sh" --no-headless --display-driver macos --audio-driver Dummy --rendering-method mobile --rendering-driver metal --fallback-rendering-driver metal --timeout "$RD04_PROBE_TIMEOUT_SECONDS" --expect-size 1920x1080 --proof-contract tools/rd04/movie_contract.json --result-manifest "$RD04_OUTPUT/native-movie.json" -- --fixed-fps 30 --fixture-manifest "$RD04_OUTPUT/overlap.json" --output-dir "$RD04_OUTPUT/clip"
    python3 tools/rd04/finalize_movie.py
    ;;
*)
    printf '%s\n' 'Usage: tools/rd04/proof_for_owner.sh fixture|stills|stills-overlap|stills-zekarion|stills-vyraketh|movie' >&2
    exit 2
    ;;
esac
