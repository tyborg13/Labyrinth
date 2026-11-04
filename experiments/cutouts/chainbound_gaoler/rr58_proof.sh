#!/bin/sh
set -eu
exec sh experiments/cutouts/held_items_rr58/proof.sh chainbound_gaoler "${1:?prepare, native, compare or density}"
