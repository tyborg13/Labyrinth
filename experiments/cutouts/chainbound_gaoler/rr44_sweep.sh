#!/bin/sh
# Every worker process is bounded to 85 seconds; no window-server access.
set -eu
rig_case="${1:-experiments/cutouts/chainbound_gaoler/rr44/proof/production_case}"
plan="$rig_case/proof/logs/rr44_sweep_commands.txt"
mkdir -p "$(dirname "$plan")"
python3 -B experiments/cutouts/chainbound_gaoler/rr44_sweep.py --case "$rig_case" --plan > "$plan"
python3 -B experiments/cutouts/chainbound_gaoler/rr44_sweep_dispatch.py --plan "$plan"
python3 -B experiments/cutouts/chainbound_gaoler/rr44_sweep.py --case "$rig_case" --merge
