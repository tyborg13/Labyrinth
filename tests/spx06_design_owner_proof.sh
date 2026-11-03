#!/bin/bash
# Windowed proof belongs to the design owner; implementation has no window server.
set -euo pipefail
cd "$(dirname "$0")/.."

case "${1:-capture}" in
  capture)
    python3 tools/visual_probe_runner.py --task-id spx-06 \
      --no-headless --display-driver macos --audio-driver Dummy --timeout 180 \
      --expect-size 1920x1080 --proof-contract tests/proof_contracts/spx06_snare_pressures.json \
      --result-manifest /private/tmp/labyrinth_codex/spx-06-pressure-captures.json \
      tests/snare_probe.gd -- --pressures-only
    ;;
  fixture)
    BIOME="${2:?Use fixture earth|fire|air|ice|lightning|shadow}"
    case "$BIOME" in earth|fire|air|ice|lightning|shadow) ;; *) exit 2 ;; esac
    python3 tools/inspection_fixture.py --task-id spx-06 \
      --run-id "spx-06-${BIOME}-pressure-turn3" \
      --manifest "/private/tmp/labyrinth-inspection-manifests/spx-06-${BIOME}-pressure-turn3.json" \
      --launch --scenario snare --snare-biome "$BIOME" --snare-tier 2 \
      --snare-case pressure_turn3 --seed 83
    ;;
  *) exit 2 ;;
esac
