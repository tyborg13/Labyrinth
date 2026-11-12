#!/bin/sh
# Native renderer proof only; run by the design owner with window-server access.
set -eu
RD02_PROBE_TIMEOUT_SECONDS=300
RD02_STARTUP_TIMEOUT_SECONDS=30
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-02
python3 tools/rd02/prepare_fixtures.py
RD02_PROOF_FAILED=0
for RD02_CASE in standard warband zekarion_arena vyraketh_arena hero zekarion vyraketh; do
  LABYRINTH_CEL_LOOK=all python3 tools/visual_probe_runner.py \
    --task-id rd-02 --no-headless --display-driver macos --audio-driver Dummy \
    --rendering-method mobile --rendering-driver metal \
    --timeout "$RD02_PROBE_TIMEOUT_SECONDS" --startup-timeout "$RD02_STARTUP_TIMEOUT_SECONDS" --expect-size 1920x1080 \
    --proof-contract tools/rd02/capture_contract.json \
    --overwrite-result-manifest --result-manifest "/private/tmp/labyrinth_codex/rd-02/native-$RD02_CASE.json" \
    tools/rd02/capture.gd -- --case "$RD02_CASE" || RD02_PROOF_FAILED=1
done
# Persist and print all three A/B pairs before the movie or optional comparisons.
LABYRINTH_CEL_LOOK=all python3 tools/visual_probe_runner.py \
  --task-id rd-02 --no-headless --display-driver macos --audio-driver Dummy \
  --rendering-method mobile --rendering-driver metal \
  --timeout "$RD02_PROBE_TIMEOUT_SECONDS" --startup-timeout "$RD02_STARTUP_TIMEOUT_SECONDS" --expect-size 1920x1080 \
  --proof-contract tools/rd02/performance_contract.json \
  --overwrite-result-manifest --result-manifest /private/tmp/labyrinth_codex/rd-02/native-performance.json \
  tools/rd02/performance.gd || RD02_PROOF_FAILED=1
# performance.gd prints each pair as it completes, even before capture validation.
# Its JSON contains the same per-pair results for a second, durable report.
if [ -f /private/tmp/labyrinth_codex/rd-02/performance_native.json ]; then
  python3 tools/rd02/performance_report.py /private/tmp/labyrinth_codex/rd-02/performance_native.json || RD02_PROOF_FAILED=1
fi
if LABYRINTH_CEL_LOOK=all python3 tools/visual_probe_runner.py \
  --task-id rd-02 --no-headless --display-driver macos --audio-driver Dummy \
  --rendering-method mobile --rendering-driver metal \
  --timeout "$RD02_PROBE_TIMEOUT_SECONDS" --startup-timeout "$RD02_STARTUP_TIMEOUT_SECONDS" --expect-size 1920x1080 \
  --godot tools/rd02/movie_capture.sh --proof-contract tools/rd02/movie_contract.json \
  --overwrite-result-manifest --result-manifest /private/tmp/labyrinth_codex/rd-02/native-movie.json \
  tools/rd02/capture.gd -- --case walk --clip; then
  python3 tools/rd02/finalize_movie.py || RD02_PROOF_FAILED=1
else
  RD02_PROOF_FAILED=1
fi
# Cel off regression comparison, same captured source frame and proof layout.
LABYRINTH_CEL_LOOK=off python3 tools/visual_probe_runner.py \
  --task-id rd-02 --no-headless --display-driver macos --audio-driver Dummy \
  --rendering-method mobile --rendering-driver metal \
  --timeout "$RD02_PROBE_TIMEOUT_SECONDS" --startup-timeout "$RD02_STARTUP_TIMEOUT_SECONDS" --expect-size 1920x1080 \
  --proof-contract tools/rd02/capture_contract.json \
  --overwrite-result-manifest --result-manifest /private/tmp/labyrinth_codex/rd-02/native-cel-off.json \
  tools/rd02/capture.gd -- --case zekarion_arena --output-dir /private/tmp/labyrinth_codex/rd-02/stills/cel-off
LABYRINTH_CEL_LOOK=all python3 tools/visual_probe_runner.py \
  --task-id rd-02 --no-headless --display-driver macos --audio-driver Dummy \
  --rendering-method mobile --rendering-driver metal \
  --timeout "$RD02_PROBE_TIMEOUT_SECONDS" --startup-timeout "$RD02_STARTUP_TIMEOUT_SECONDS" --expect-size 1280x800 \
  --proof-contract tools/rd02/compact_contract.json \
  --overwrite-result-manifest --result-manifest /private/tmp/labyrinth_codex/rd-02/native-compact.json \
  tools/rd02/capture.gd -- --case zekarion_arena --compact --output-dir /private/tmp/labyrinth_codex/rd-02/stills/compact

exit "$RD02_PROOF_FAILED"
