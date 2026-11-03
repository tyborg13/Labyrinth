#!/bin/sh
# Window-server access required. Before is frozen pt13-02. One attempt only.
# Every invocation allocates a fresh manifest; the runner isolates PNG output.
set -eu
cd "$(dirname "$0")/.."
manifest_dir="$(mktemp -d /private/tmp/pt14-04-native-proof.XXXXXX)"
python3 tools/visual_probe_runner.py tests/intent_chip_placement_probe.gd \
  --task-id pt14-04 --no-headless --display-driver macos --audio-driver Dummy \
  --timeout 180 --attempts 1 --min-images 10 --expect-size 1920x1080 \
  --proof-contract tests/pt14_01_placement_proof.json \
  --result-manifest "$manifest_dir/manifest.json"
