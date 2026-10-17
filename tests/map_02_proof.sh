#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
exec python3 tools/visual_probe_runner.py tests/section_map_variety_probe.gd \
  --task-id map-02 --no-headless --display-driver macos --audio-driver Dummy \
  --expect-size 1920x1080 \
  --proof-contract tests/section_map_variety_visual_contract.json \
  --result-manifest "${MAP_02_PROOF_MANIFEST:-/private/tmp/labyrinth-inspection-manifests/map-02-variety.json}" \
  -- --debug-reveal-section
