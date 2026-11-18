#!/bin/sh
# Director-only native feedback-1 proof: existing cel presentation, 1920x1080.
set -eu
TASK_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
cd "$TASK_ROOT"
export LABYRINTH_TASK_ID=area-02
export ATK13_CAPTURE_SCRIPT=res://tools/area02/capture.gd
export ATK13_CAPTURE_OUT=/private/tmp/labyrinth_codex/area-02/captures
if test "$#" -eq 0; then set -- upheaval gust; fi
for scenario in "$@"; do
  case "$scenario" in
    upheaval) fixture=craghide ;;
    gust) fixture=gallows_roc ;;
    *) echo "Expected upheaval or gust" >&2; exit 2 ;;
  esac
  export ATK13_PROOF_CONTRACT="tools/area02/${scenario}_contract.json"
  sh tools/atk13/native_capture.sh "/private/tmp/labyrinth_codex/area-02/f1/truth/fixtures/$fixture" area02 "$scenario" --case "$scenario"
done
