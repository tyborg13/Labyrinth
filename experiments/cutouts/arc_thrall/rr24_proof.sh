#!/bin/sh
# Director's exact mq7b sequence. Captures require the macOS window server.
set -eu
export LABYRINTH_TASK_ID="${LABYRINTH_TASK_ID:-rr-24}"
stage="${1:?Use density, rest, native, sheets, idle, production, review or crops}"
case "$stage" in
crops)
python3 -B experiments/cutouts/arc_thrall/rr24_crops.py
;;
*)
sh experiments/cutouts/arc_thrall/rr11_proof.sh "$stage"
;;
esac
