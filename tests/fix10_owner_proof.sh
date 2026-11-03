#!/bin/bash
# Windowed proof for the design owner. Run from the fix-10 worktree only.
# Existing production captures assert real action progression/contact, canvas
# bounds, actor-only playback, 1920x1080 and 100% UI scale before exporting PNGs.
set -euo pipefail
mkdir -p output/fix-10/native
python3 tools/output_gdignore.py
proof_root="$PWD/output/fix-10/native"
for view in front rear; do
  view_flag=""
  if [[ "$view" == rear ]]; then view_flag=--rear; fi
  python3 tools/visual_probe_runner.py --task-id fix-10 --no-headless --display-driver macos --audio-driver Dummy --timeout 900 --expect-size 1920x1080 --proof-contract tests/proof_contracts/fix10_thrall_cast.json --overwrite-result-manifest --result-manifest "output/fix-10/native/thrall-${view}.json" tests/rr11/production_capture.gd -- --type arc_thrall --output "${proof_root}/thrall-${view}" --view "$view" --expect-facing "$view"
  python3 tools/visual_probe_runner.py --task-id fix-10 --no-headless --display-driver macos --audio-driver Dummy --timeout 900 --expect-size 1920x1080 --proof-contract tests/proof_contracts/fix10_weaver_cast.json --overwrite-result-manifest --result-manifest "output/fix-10/native/weaver-${view}.json" tests/rr21/production_capture.gd -- --type briar_weaver --output "${proof_root}/weaver-${view}" --expect-facing "$view" ${view_flag:+"$view_flag"}
done
python3 tools/visual_probe_runner.py --task-id fix-10 --no-headless --display-driver macos --audio-driver Dummy --timeout 900 --expect-size 1920x1080 --overwrite-result-manifest --result-manifest output/fix-10/native/seer.json tests/rr10/production_capture.gd -- --type hoarfrost_seer --output "${proof_root}/seer"
python3 tools/visual_probe_runner.py --task-id fix-10 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --proof-contract tests/proof_contracts/enemy_intent_continuity.json --overwrite-result-manifest --result-manifest output/fix-10/native/continuity.json tests/enemy_intent_continuity_probe.gd
python3 tools/visual_probe_runner.py --task-id fix-10 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --overwrite-result-manifest --result-manifest output/fix-10/native/threats.json tests/threats_at_rest_probe.gd
