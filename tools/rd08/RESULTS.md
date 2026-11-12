# rd-08 observed results

Latest round: [feedback 2 results](FEEDBACK2.md), following
[feedback 1 results and commands](FEEDBACK1.md). The results below
record the initial integration before the owner requested enemy tooltip removal.

Implementation is complete and uncommitted. No windowed/native renderer run,
peer review, commit, push, merge, branch change or queue mutation was performed.
The source integration is a read-only three-way merge of `7ec60afc5` into the
provided `c5c868043` tree, with the brief's reconciliation rules applied.

All logs and generated evidence below are under
`/private/tmp/labyrinth_codex/rd-08/`. No headless result claims rendered pixels.

| Required proof | Exact observed result | Log |
|---|---|---|
| Certified overlap + real dragon saves | `RD08 REAL-GAME FIXTURES: PASS (Section I + two real-depth boss arenas)` | `fixtures-corrected.log`; three stock verification manifests |
| Integration, both settings, rail union, disc input/reverse lookup, aim outlines, dragon footprints, body ownership | `RD08 INTEGRATION: PASS (3286 checks, 0 failures)` | `integration-verified.log`; `integration.json` |
| rd-02, cel all | `RD02 SILHOUETTE PROOF: PASS (2246 checks, 0 failures)` | `rd02-cel-all.log` |
| rd-02, cel off | `RD02 SILHOUETTE PROOF: PASS (2246 checks, 0 failures)` | `rd02-cel-off.log` |
| rd-03 | `RD03 AIM FOCUS: PASS (702 checks, 0 failures)` | `rd03-corrected.log` |
| rd-04 overlap | `RD04 THREAT ISOLATION: PASS (2147 checks, 0 failures)` | `rd04-overlap.log` |
| rd-04 Zekarion | `RD04 THREAT ISOLATION: PASS (236 checks, 0 failures)` | `rd04-zekarion.log` |
| rd-04 Vyraketh | `RD04 THREAT ISOLATION: PASS (238 checks, 0 failures)` | `rd04-vyraketh.log` |
| rd-06 resume / fresh / briefing | Each: `RD06 STALE OCCLUSION: PASS (0 failures)` | `rd06-resume.log`, `rd06-fresh.log`, `rd06-briefing.log` |
| rd-07 | `RD07 BOARD UI: PASS (153 checks, 0 failures)` | `rd07-verified.log` |
| rd-05 adapter | `RD05 RD07 REGRESSION: PASS (103 checks, 0 failures)` | `rd05-adapter.log` |
| Focused existing suites | `RD08 FOCUSED: FAIL (75377 checks, 2 failures)` | `focused-corrected.log` |
| Turn-order rail lifetime | `RD04 FOCUSED: PASS (810 checks, 0 failures)` | `rail.log` |
| Tooltip consistency | `RD07 TOOLTIP CONSISTENCY: PASS (72 checks, 0 failures)` | `tooltips.log` |
| Board tooltips | `BOARD TILE TOOLTIPS: PASS checks=217 failures=0` | `board-tooltips.log` |
| Settings | `TEST RESULT: PASS` | `settings.log` |
| Default Python group only | `Ran 189 tests in 121.465s`; `FAILED (failures=3)` | `python-default.log`; 20 selected modules |
| Retry only those three failed Python tests | `Ran 3 tests in 55.679s`; `OK` | `python-retries.log` |
| UI identity lint | `Ran 25 tests`; `OK` | `ui-lint-verified.log` |
| Stable Godot sidecars | `Ran 19 tests`; `OK` | `sidecar-tests.log` |
| Python resource audit | `ISOLATION AUDIT: 56 modules` | `python-audit-final.log` |
| Owner tools, contracts, profile copy | `RD08 OWNER TOOLS: PASS (syntax, contracts, profile seeds once; Steam source unchanged)` | `tools-check-verified.log` |
| Native still setup, headless only | `RD08 CAPTURE SETUP: PASS (overlap, 9 samples, headless; no images)`; same PASS for Zekarion (2) and Vyraketh (1) | `capture-overlap.log`, `capture-zekarion.log`, `capture-vyraketh.log` |
| Four-second movie setup, headless only | `RD08 MOVIE CHECK-ONLY: PASS (120 frames; 30 fps; 4 seconds)` | `movie-check.log`; `clip/proof.json` |
| Frame-cost harness setup, headless only | `RD08 PERFORMANCE SAMPLE: PASS (check, 180 frames, headless setup only)` | `performance-check.log`; `performance/check.json` |
| Actual release-template headless boot | `RD02 RELEASE TEMPLATE: PASS (0 failures)` | `release-final.log`; `release/RD02.app` |
| Exact staged runtime match | `RD08 RELEASE SOURCE MATCH: PASS (8 integrated runtime files match exported staging)` | `verified-runtime-sha256.json` |
| Exact A/B baseline preparation | `RD08 EXACT BASELINE: PASS` | `baseline-prepare.log`; `base-14a369b61/.rd08-baseline` |

No full Python or Godot suite was run. No new `tests/test*.py` module was added;
the resource audit accepts all existing modules. Sidecar and UI baselines were
not raised. Approved cel assets were used unchanged; the release adapter skips
art refresh while retaining the stock inventory/currentness, copy hashes, pack
verification and release-template assertions.

## Preserved existing failures

The focused suite's two failures are both
`Umbra keeps the still Unknown Presence texture`, already documented with a
read-only HEAD reproduction in `tools/rd07/README.md`. No assertion or expected
texture was changed. The separate real-scene rail lifetime suite passes all 810
checks, including its still-portrait checks. The focused suite is still reported
as failed.

The initial default Python group failed these tests during the cold bootstrap:

- `test_program_suite_runner.ProgramSuiteRunnerTests.test_real_parent_prints_whole_logs_in_manifest_order`: headless child timed out, return 124.
- `test_approved_content_manifest.ApprovedContentManifestTests.test_approved_content`: headless child timed out, return 124.
- `test_godot_task_runner.GodotTaskRunnerTests.test_killing_runner_mid_godot_test_leaves_no_godot_child`: `AssertionError: False is not true : Child did not start`.

All three passed unchanged in the focused retry after import. The original
189-test group remains recorded as failed; it was not rerun wholesale. Its
optional timing-cache write reports the expected read-only Git metadata error.

## Integration failures found and fixed

- Kept the original living Health crate and complete terrain in the natural
  overlap save. The first tool adapter mistakenly replaced terrain and therefore
  removed its overlapping plans; corrected fixtures retain the real fight.
- Unified rail inspection and isolation through one animator, keeping diagnostic
  metadata compatible with both upstream proofs.
- Prevented broad enemy sprite hit bounds from stealing crate inspection or
  bypassing rd-03's terrain/trap tooltip gate while choosing a target.
- Kept precise fixed-status tooltip content before broad footprint inspection.
- Unfurled contextual discs only for actual isolation, inspection or Details;
  legacy expanded-plan metadata remains independent. The predicate retires
  stale deferred isolation when its input owner has already left.
- Kept scene-tile slices before the original team/body canvases and removed the
  duplicate body path. The integration proof checks both ownership and order.
- Restored the upstream Always-setting reset before the frozen hover oracle in
  the new focused runner; no oracle assertion was altered.

Earlier failed logs remain for traceability. The final passing logs in the
table supersede the corresponding implementation/harness failures.

## Owner-only work and open issues

No new TODO_DESIGN placeholder was needed and no player-visible default was
chosen. The two existing Unknown Presence failures remain open. Native stills,
movie viewing, native A/B median/p99, UI judging and owner play remain unrun,
as required by the sandbox split. Exact commands, expected capture paths,
profile seeding behavior and chosen proof-only defaults are in `README.md`.

The owner still commits, performs peer review and prepares the final inspection
handoff. This worker is not claiming those owner phases are complete.
