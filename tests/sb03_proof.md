# sb-03 implementation proof

## Feedback 1 — prewarm bounds during board loading

Round 0's 4× sheets were approved visually by the director. The fitting math,
texture source, filter and all player-facing geometry remain identical.

`CombatBoardView._load_keyword_icon_asset` now calls
`StatusPlates.prewarm_icon` for the 25 known board status, keyword-status,
illusion and defense icons. It prepares both the >10% visible bounds and the
existing source-crop bounds. These jobs are shared by synchronous board loading
and staged loading, so the work completes before combat presentation and stays
inside the existing staged-loading budget. Subsequent boards share the cached
texture results. Unanticipated/replacement textures retain the same per-texture
fallback. The computation counter increments only on cache misses.

The focused test clears the caches, executes actual board asset loading, checks
every icon is prepared, draws all 25 icons in all three presentations, and
asserts no bounds computations occur. It also checks repeated/staged icon jobs
are cache hits and that unknown textures still compute bounds exactly once.
Omitting the loading hook is detected by 78 behavioral assertions.

### Matched measurements

Apple M5 Pro, macOS, Godot 4.6.1, headless/dummy renderer, 1920×1080, UI scale 1.
Four serial base/candidate pairs, 20 cold-status trials per process: 80 samples
per version. Base is `30b566add9c867ad085f8e1a4097712f430b2522`; historical
Board/Plates sources run from temporary test fixtures without modifying Git or
production files. The fixture is the existing 12-unit HUD workload: healthy
units first, then fresh unit dictionaries adding all 72 authored fixture badge
entries (six icon identities). Icon textures are decoded before timing;
visible/source bounds alone are cleared before each board load. Other caches
stay warm across trials. Initial full-board asset decode is included in the
separately reported board-load samples.

These are **draw CPU-submission times**, not measured native frame intervals.
The first status-bearing `_draw` callback runs the real board health/status
painting methods. No screenshot readback or serialization occurs in the timed
samples. Native frame intervals are omitted from headless reports.

| Metric | Before median / p95 / max | After median / p95 / max |
| --- | --- | --- |
| First status-bearing draw CPU | 3.220 / 7.403 / 8.250 ms | 2.464 / 5.130 / 8.623 ms |
| Status-icon loading jobs | 0.039 / 0.096 / 0.224 ms | 2.714 / 4.301 / 8.814 ms |
| Entire board asset load | 6.064 / 543.771 / 973.832 ms | 8.795 / 545.238 / 881.691 ms |

The measured added median prewarm job cost is **2.675 ms**, covering all 25
icons. First-application draw computations are **6 → 0** in every sample;
candidate boards have all 25 cached at load. No CPU draw sample exceeds
16.67 ms. Node/object counts remain constant within each process's trials.
Base copies carry extra script resources, so cross-version object counts are
not treated as a memory saving.

Absolute CPU timing varies with machine state: pair medians were
3.116/3.224/3.041/5.420 ms before and 2.435/2.491/2.338/4.237 ms after.
The final pair's p95 was 8.250 → 8.623 ms; the pooled p95 improves, but the
worst observed sample is 4.5% higher. The invariant is elimination of draw-time
bounds work; native frame-pacing benefit still needs renderer measurement.

Raw reports:

- `/private/tmp/sb03-f1-comparison/comparison.json` (three pairs);
- `/private/tmp/sb03-f1-comparison-final-check/comparison.json` (one additional pair);
- `/private/tmp/sb03-f1-combined-summary.json` (all four pairs);
- matching `base-N.json`, `candidate-N.json` and logs in those directories.

### Feedback 1 focused results

```text
BOARD STATUS PLATES TEST RESULT: PASS (33858 assertions; 0 failures)
STATUS ICON FIRST-APPLICATION COMPARISON RESULT: PASS
STATUS ICON APPLICATION BENCHMARK RESULT: PASS (20 trials; 12 units)
STATUS CAPTURE PROBE RESULT: PASS
STATUS MOCK GEOMETRY RESULT: PASS (6 nameplates; 3 px tolerance)
STATUS PERFORMANCE PROBE RESULT: PASS
STATUS MOVEMENT PROBE RESULT: PASS
STATUS ICON PREWARM MUTATION RESULT: PASS
BOARD STATUS PLATES TEST RESULT: FAIL (33858 assertions; 78 failures) [intentional omitted-prewarm mutation; no parser errors]
STATUS ICON CANVAS-CENTRING MUTATION RESULT: PASS
BOARD STATUS PLATES TEST RESULT: FAIL (33858 assertions; 267 failures) [intentional canvas-centring mutation; no parser errors]
Ran 25 tests in 4.444s
OK
Ran 32 tests in 6.683s
OK
```

The 25 Python checks are UI identity lint; 32 are test-registration guard checks.
The initial parallel performance invocation exceeded the unchanged cold-plan
cap: `mixed cold/warm plan exceeds 4000 us: 4991/2033/1866`. The isolated serial
rerun passed with maximum cold mixed-plan time 3887 µs. No limits or assertions
were changed. Feedback 1 uses focused checks only; the older full-suite results
below belong to round 0.

An auxiliary `py_compile` check could not create Python's default bytecode
cache beneath `/Users/borgerding/Library/Caches/com.apple.python/Users/borgerding/workspace/Labyrinth.worktrees/sb-03`:
`PermissionError: [Errno 1] Operation not permitted`. In-memory `ast.parse`
validated the comparator's syntax successfully without filesystem writes.

Logs: `/private/tmp/sb03-f1-focused.log`, `sb03-f1-capture.log`,
`sb03-f1-geometry.log`, `sb03-f1-ui-lint.log`, `sb03-f1-registration.log`,
`sb03-f1-steady-performance.log`, `sb03-f1-steady-performance-serial.log`,
`sb03-f1-prewarm-mutation.log`/`.json`, and
`/private/tmp/sb03-f1-canvas-mutation/`.

### Feedback 1 commands and proof for the design owner

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/sb-03 && python3 tools/godot_task_runner.py --task-id sb-03 --stream -- godot --headless --path . --script tests/board_status_plates_test.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/sb-03 && python3 tests/status_icon_application_compare.py --repeats 4 --output /private/tmp/sb03-f1-new-cpu-comparison
```

No windowed run was attempted in this sandbox. For native before/after timing,
run this block in one shell. The comparator invokes `visual_probe_runner.py`
serially for each version, with fresh manifests, no screenshot readback, and no
retry on failure. Each valid run measures 20 first-application frames. The
windowed helper fixes the viewport/UI scale, disables the idle governor, checks
foreground focus, and brackets redraw completion on `frame_post_draw`.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/sb-03 && SB03_F1_PROOF_ROOT="$(mktemp -d /private/tmp/sb03-f1-owner.XXXXXX)"
cd /Users/borgerding/workspace/Labyrinth.worktrees/sb-03 && python3 tests/status_icon_application_compare.py --native --repeats 1 --output "$SB03_F1_PROOF_ROOT/measurements"
```

`measurements/comparison.json` contains CPU, loading and native frame interval
summaries. `base-0-manifest.json` and `candidate-0-manifest.json` retain actual
renderer metadata. No new image capture is required for this approved visual
surface; the round-0 capture commands remain below if needed.

New chosen defaults are proof-only: 20 trials/process; three matched pairs by
default (the recorded final run adds one pair); a 5 s draw-readiness deadline;
native frame cap 0, idle governor disabled, fallback sleep 0 µs, and the visual
project's mobile/MSAA renderer using Metal, pinned with one attempt and no
backend fallback. The 12-unit
grid, unit fields and badge amounts are reused unchanged from the existing
performance fixture. No new `TODO_DESIGN_*` placeholders.

## Round 0 implementation and verification

Only icon drawing changes. The fit box is the existing 18 px pill / 20 px
plate icon slot intersected with the unchanged frame inset by its 2 px border
plus 1 px clearance. Alpha strictly above 0.1 defines visible bounds, cached
by texture. The old source crop and scale remain the ceiling. Bounds are fit
and centred before their visible origin is snapped to whole pixels; inward
pixel limits prevent snapping overruns during subpixel HUD movement. No
texture filtering, tooltip drawing, frame geometry, words or counts change.

`board_status_plates_suite.gd` calls `board_status_icon_fit_suite.gd`, so the
existing focused entrypoint and full suite both exercise the new coverage.
The independent oracle scans all pixels into a binary alpha mask and checks
the actual recorded draw call, not just the production geometry helper.
The 25-icon inventory traverses live board badge producers, all self-flag
icons, keyword statuses, illusion ranged/retaliation icons and both defenses.
Each icon is tested in all three presentations at three HUD positions.
Synthetic asymmetric art checks thresholding, unchanged scale for already
fitting art, prediction opacity, empty textures and cache reuse.

## Headless commands

Run mutations alone, never concurrently with tests or captures:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/sb-03 && python3 tools/godot_task_runner.py --task-id sb-03 --stream -- godot --headless --path . --script tests/board_status_plates_test.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/sb-03 && python3 tools/godot_task_runner.py --task-id sb-03 --stream -- godot --headless --path . --script tests/status_capture_probe.gd -- --check-only
cd /Users/borgerding/workspace/Labyrinth.worktrees/sb-03 && python3 tools/godot_task_runner.py --task-id sb-03 --stream -- godot --headless --path . --script tests/status_icon_fit_probe.gd -- --check-only
cd /Users/borgerding/workspace/Labyrinth.worktrees/sb-03 && python3 tests/status_icon_fit_mutation.py --output-dir /private/tmp/sb03-mutation
cd /Users/borgerding/workspace/Labyrinth.worktrees/sb-03 && python3 tests/test_ui_identity_lint.py
cd /Users/borgerding/workspace/Labyrinth.worktrees/sb-03 && python3 tools/godot_task_runner.py --task-id sb-03 --stream -- godot --headless --path . --script tests/status_plates_performance_probe.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/sb-03 && python3 tools/godot_task_runner.py --task-id sb-03 --timeout 900 --stream -- godot --headless --path . --script tests/run_tests.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/sb-03 && python3 -m unittest discover -s tests -p 'test_*.py' -v
```

For headless mock geometry comparison, pass the `STATUS captures:` directory
printed by the check-only probe to `python3 tests/status_capture_compare.py
<directory> --geometry-only`. This is semantic geometry proof only.

## Proof for the design owner

The implementation sandbox cannot access the macOS window server. No windowed
run was attempted. Run these commands in one shell; `mktemp` supplies fresh
manifest paths on every invocation:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/sb-03 && SB03_PROOF_DIR="$(mktemp -d /private/tmp/sb03-windowed.XXXXXX)"
cd /Users/borgerding/workspace/Labyrinth.worktrees/sb-03 && python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy --task-id sb-03 --expect-size 1920x1080 --proof-contract tests/status_capture_probe_contract.json --result-manifest "$SB03_PROOF_DIR/status-capture.json" tests/status_capture_probe.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/sb-03 && python3 tests/status_capture_compare.py --manifest "$SB03_PROOF_DIR/status-capture.json"
cd /Users/borgerding/workspace/Labyrinth.worktrees/sb-03 && python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy --task-id sb-03 --expect-size 1920x1080 --proof-contract tests/status_icon_fit_probe_contract.json --result-manifest "$SB03_PROOF_DIR/icon-sheets.json" tests/status_icon_fit_probe.gd
```

The capture manifest points to `status-captures/` (the existing five board and
hover captures). The sheet manifest points to `status-icon-fit/`:

- `status_icons_before_page_01_4x_1920x1080.png` through page `04`;
- `status_icons_after_page_01_4x_1920x1080.png` through page `04`;
- `semantic-proof.json`, including inventory, pagination and baseline method.

Each native 1920×1080 sheet uses 100% UI scale and a proof-only 4× drawing
transform. Eight icons per page leave room for all three presentations without
resizing the native screenshot. “Before” uses the exact pre-sb-03 icon crop,
size and placement from `status_icon_fixture.legacy_rect`; both phases call
production frame and label painting. This recreates the baseline without
switching branches or mutating production code. Inspect all four page pairs,
especially Immobilized, compact Chilled and asymmetric vertical padding.
Renderer proof and the director's visual judgment are still required.

The brief requests no `inspection_fixture.py` command. The design owner owns
the playable inspection fixture, commit, peer review and publication.

## Chosen defaults

All are test/proof-only named constants or fixture dictionary fields:

- Fixture frame `(100,100,140,24)`, sample count `3`; existing approved words
  and icon names come from the production library. The inventory carrier uses
  `hp=24`, active restriction counters `1`, counted status/charge values `2`
  and enabled boolean mechanic flags, solely to expose every badge producer.
- HUD offsets `(0,0)`, `(0.25,-0.5)`, `(-140.75,22.75)`; comparison epsilon
  `0.0001`; synthetic 40×40 canvas with visible rects `(23,5,7,29)` and
  `(23,3,7,34)`, a fitting-art offset `(0,0.5)` and alpha `0.09` / `0.11`;
  preview alpha `0.7` matches production predictions.
- Sheet rows `8`, row origin `(32,112)`, row step `118`, column x positions
  `320/1020/1400`, header/column baselines `38/80`, proof label font `18`,
  settle frames `3`. Resolution `1920×1080`, UI scale `1` and proof scale `4`
  are required by the brief.
- Mutation timeout `90 s`; existing runner and suite timeouts remain in use.

No `TODO_DESIGN_*` placeholders are needed.

## Observed verification (2026-10-26)

```text
BOARD STATUS PLATES TEST RESULT: PASS (33777 assertions; 0 failures)
STATUS ICON FIT COVERAGE: 25 icons x 3 presentations x 3 positions = 225 draws
STATUS CAPTURE PROBE RESULT: PASS
STATUS MOCK GEOMETRY RESULT: PASS (6 nameplates; 3 px tolerance)
STATUS ICON FIT PROBE RESULT: PASS (25 icons; 8 sheets; 0 failures)
STATUS ICON CANVAS-CENTRING MUTATION RESULT: PASS
BOARD STATUS PLATES TEST RESULT: FAIL (33777 assertions; 267 failures) [intentional mutation; no parser errors]
STATUS PERFORMANCE PROBE RESULT: PASS
STATUS MOVEMENT PROBE RESULT: PASS
Ran 25 tests in 3.399s
OK
TEST REGISTRATION AUDIT: PASS (856 scripts; full suite=501, quarantined=29, windowed probe=326)
FULL SUITE RUNTIME: 755.243 seconds (budget 900 seconds)
TEST RESULT: FAIL (4 failure(s))
Ran 1991 tests in 6987.413s
FAILED (errors=2, skipped=66)
```

The eight sheet paths in check-only output describe contracts, not rendered
captures. No PNG captures were created in this sandbox.

Full Godot failures outside sb-03:

- `special_encounter_test` (exit 1): imported `.ctex` files for approved map
  emblems and director sidecars are absent in this clean worktree.
- `enemy_no_action_test` (exit 124 after 180 s): `GameData` is undeclared in
  `tests/suites/enemy_no_action_suite.gd:36` and `:128`, followed by an invalid
  suite call and timeout.
- `fix_11_test` and `fix_11_probe` (exit 1): the same `GameData` parser errors
  appear in their dependency closure. The test's own `FIX-11 TEST RESULT: PASS
  (36 checks, 0 failures)` is insufficient: the runner correctly fails it on
  script errors.

All four causes reproduce in an isolated, temporary project using the original
`HEAD:scripts/board_status_plates.gd`: the special encounter runs and fails its
two import assertions; Godot `--check-only` reports the identical parser errors
for the other three entrypoints. No existing assertions were changed. Baseline
logs and summary are in `/private/tmp/sb03-baseline-failures/`.

Full Python discovery completed with two unrelated fixture setup errors in the
unchanged `tests/test_rr21_review.py`:

- `test_native_preflight_requires_current_capture_and_never_rebinds_it`;
- `test_review_from_clean_proof_state_regenerates_real_direction_evidence`.

Both raise `FileNotFoundError` while creating a `TemporaryDirectory` beneath
`experiments/cutouts/briar_weaver/mq9/proof/logs`, before invoking their checks.
That parent directory is absent in this clean worktree and has no tracked
contents at `HEAD`. No RR21 files or assertions were changed. The 66 skips are
6 requiring pinned Python 3.12 audio, 41 missing optional sound modules,
16 missing optional classical music modules, 2 disabled director-bridge Blender
proofs, and 1 unadopted Tether study.

After discovery finished, the sb-03 canvas-centring mutation was run alone again:
it produced the same 267 behavioral assertion failures, no parser errors, and
restored the production file byte-for-byte.

Retained logs:

- `/private/tmp/sb03-full-godot.log`
- `/private/tmp/sb03-full-python.log`
- `/private/tmp/sb03-focused-final.log`
- `/private/tmp/sb03-capture-check-final.log`
- `/private/tmp/sb03-geometry-final.log`
- `/private/tmp/sb03-sheet-check-final.log`
- `/private/tmp/sb03-ui-lint-final.log`
- `/private/tmp/sb03-performance.log`
- `/private/tmp/sb03-mutation-final/results.json` and `canvas-centring.log`

Final headless semantic directories (no PNGs):

- `/private/tmp/labyrinth-godot-home/sb-03-1793022951888644000-92408/Library/Application Support/Escape the Umbra Parallel sb-03-1793022951888644000-92408/status-captures/`
- `/private/tmp/labyrinth-godot-home/sb-03-1793022277572880000-85029/Library/Application Support/Escape the Umbra Parallel sb-03-1793022277572880000-85029/status-icon-fit/`
