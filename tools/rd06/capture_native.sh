#!/bin/sh
set -eu
case "${1:-fix}" in
  base)
    python3 tools/rd06/baseline.py env LABYRINTH_CEL_LOOK=all python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy --rendering-driver metal --rendering-method mobile --fallback-rendering-driver metal --timeout 300 --startup-timeout 240 --expect-size 1920x1080 --proof-contract tools/rd06/capture_contract.json --result-manifest /private/tmp/labyrinth_codex/rd-06/base-capture.json tools/rd06/stale_occlusion_check.gd --task-id rd-06 -- --capture
    ;;
  fix)
    LABYRINTH_CEL_LOOK=all python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy --rendering-driver metal --rendering-method mobile --fallback-rendering-driver metal --timeout 300 --startup-timeout 240 --expect-size 1920x1080 --proof-contract tools/rd06/capture_contract.json --result-manifest /private/tmp/labyrinth_codex/rd-06/fix-capture.json tools/rd06/stale_occlusion_check.gd --task-id rd-06 -- --capture
    ;;
  *) echo 'Usage: sh tools/rd06/capture_native.sh base|fix' >&2; exit 2 ;;
esac
