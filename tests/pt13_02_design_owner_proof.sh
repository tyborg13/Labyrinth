#!/bin/sh
# Window-server access is required. One attempt; a fresh manifest every run.
set -eu
cd "$(dirname "$0")/.."
manifest_dir="$(mktemp -d /private/tmp/pt13-02-native-proof.XXXXXX)"
python3 tools/visual_probe_runner.py tests/intent_chip_placement_probe.gd \
  --task-id pt13-02 --no-headless --display-driver macos --audio-driver Dummy \
  --timeout 180 --attempts 1 --min-images 10 --expect-size 1920x1080 \
  --proof-contract tests/intent_chip_placement_proof.json \
  --result-manifest "$manifest_dir/manifest.json"
