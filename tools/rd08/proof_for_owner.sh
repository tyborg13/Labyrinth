#!/bin/sh
set -eu
export LABYRINTH_CEL_LOOK=all
RD08_OUTPUT=/private/tmp/labyrinth_codex/rd-08
stills_case() {
    RD08_CASE=$1
    python3 tools/visual_probe_runner.py tools/rd08/capture.gd --task-id rd-08 --godot "$PWD/tools/rd08/native_capture.sh" --no-headless --display-driver macos --audio-driver Dummy --rendering-driver metal --rendering-method mobile --fallback-rendering-driver metal --timeout 300 --expect-size 1920x1080 --proof-contract "tools/rd08/${RD08_CASE}_contract.json" --result-manifest "$RD08_OUTPUT/native-$RD08_CASE.json" -- --case "$RD08_CASE"
}
case "${1:-stills}" in
hover-enemy|hover-zekarion)
    RD08_CASE=overlap
    RD08_CONTRACT=enemy
    if [ "$1" = hover-zekarion ]; then RD08_CASE=zekarion; RD08_CONTRACT=zekarion; fi
    python3 tools/visual_probe_runner.py tools/rd08/capture.gd --task-id rd-08 --godot "$PWD/tools/rd08/native_capture.sh" --no-headless --display-driver macos --audio-driver Dummy --rendering-driver metal --rendering-method mobile --fallback-rendering-driver metal --timeout 300 --expect-size 1920x1080 --proof-contract "tools/rd08/${RD08_CONTRACT}_hover_contract.json" --result-manifest "$RD08_OUTPUT/feedback1/native-$RD08_CASE.json" -- --case "$RD08_CASE" --hover-only
    ;;
fixture) python3 tools/rd08/prepare_fixtures.py ;;
stills) stills_case overlap; stills_case zekarion; stills_case vyraketh ;;
stills-overlap) stills_case overlap ;;
stills-zekarion) stills_case zekarion ;;
stills-vyraketh) stills_case vyraketh ;;
movie)
    export RD08_MOVIE=1
    python3 tools/visual_probe_runner.py tools/rd08/movie_capture.gd --task-id rd-08 --godot "$PWD/tools/rd08/native_capture.sh" --no-headless --display-driver macos --audio-driver Dummy --rendering-driver metal --rendering-method mobile --fallback-rendering-driver metal --timeout 300 --expect-size 1920x1080 --proof-contract tools/rd08/movie_contract.json --result-manifest "$RD08_OUTPUT/native-movie.json" -- --fixed-fps 30
    python3 tools/rd08/finalize_movie.py
    ;;
performance) python3 tools/rd08/performance_pairs.py ;;
*) printf '%s\n' 'Usage: proof_for_owner.sh fixture|stills|stills-overlap|stills-zekarion|stills-vyraketh|movie|performance' >&2; exit 2 ;;
esac
