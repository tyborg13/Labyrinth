#!/bin/sh
set -eu
FX13_CLOCK_FILE=${FX19_CLOCK_FILE:?}
export FX13_CLOCK_FILE
exec tools/fx13/movie_clock.sh "$@"
