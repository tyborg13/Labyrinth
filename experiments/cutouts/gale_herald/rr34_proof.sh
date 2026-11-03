#!/bin/sh
# Reuse the approved rr32 native probes/contracts, isolated under this task.
set -eu
export LABYRINTH_TASK_ID=rr-34
exec sh experiments/cutouts/gale_herald/proof.sh "$@"
