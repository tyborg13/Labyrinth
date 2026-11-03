# pt15-01 feedback 3 — cache and whitespace review fixes

The accepted behavior from `7bd049ec2` is preserved. Changes remain uncommitted.
No new chip positions, art, tuning, review, publication or windowed run.

## Cache fix

`intent_chip_placement.gd` now keeps a board-owned entry per unit containing
its projected rest silhouette and derived sole rectangle. Each lookup first
obtains the board's existing cached alpha data. The entry is reusable only
while that source dictionary is the same object and texture size, draw rect,
bounds, mirroring, hero mode and role match. Source-cache replacement/clear or
projection changes therefore rebuild silhouette and sole together. Entries for
removed units are evicted. The shared source resources remain unmodified.
Only enemies need sole clipping; hero/NPC coverage does not perform unused
sole work. The clipping arithmetic and placement code are unchanged.

The focused cache suite proves 20 identical warm layouts do **zero sole clips,
zero projection rebuilds and zero source rescans**. It also tests source-cache
clear, movement, facing/reflection, two owners sharing a texture and eviction.
The reviewer's surviving board-silhouette-cache bypass now fails both the sole
clip and raw-alpha-rescan guards, without script errors.

## Accepted-position proof

The sweep ran once with the accepted commit's placement helper in a private
overlay, and once with the candidate. Across all **172** type/view/reflection
cases: **0 changed rectangles, 0 changed complete serialized layouts, 0 changed
silhouette geometries**. Only the new derived cache field is excluded from the
silhouette-geometry comparison; complete chip layout bytes are compared as-is.
Evidence: `/private/tmp/pt15-01-feedback3/accepted-equivalence/comparison.json`,
`accepted.json`, `cached.json`, and their runner logs.

## Six-enemy matched performance

`warband_air_3_crowd`, 1920x1080 logical board, 100% scale, Godot 4.6.1,
Darwin arm64, headless CPU layout timing. Frozen **pt14-04** and candidate run
in one process with alternating order, 12 warmup and 120 measured samples each.
Both use the same current assets, registration and geometry helper. This is
layout CPU time, not a renderer frame-time or FPS claim.

| Implementation | Median | p95 |
| --- | ---: | ---: |
| Frozen pt14-04 | 4.249 ms | 4.346 ms |
| Cached sole candidate | 4.291 ms | 4.421 ms |
| Difference | +0.042 ms (+0.99%) | +0.075 ms (+1.73%) |

Cold rest geometry was measured separately at 6.103ms; warm rest-silhouette
queries measured median/p95 0.120/0.128ms. The comparison and test gate now use
pt14-04 instead of pt13-02. `MAX_LAYOUT_COST_RATIO=1.05` follows the repository
performance metric contract's 5% directly-affected-cost regression threshold;
it is test-only, not a gameplay value. The guard passed.
Evidence: `/private/tmp/pt15-01-feedback3/performance-final.log`.

## Files changed in this round

- `scripts/intent_chip_placement.gd`: projected silhouette/sole cache and cold
  proof counters; no placement-order, geometry-value or registration change.
- `tests/suites/pt15_01_sole_cache_suite.gd`: new focused reuse/invalidation proof.
- `tests/suites/pt15_01_owner_feet_suite.gd`: calls the cache suite.
- `tests/test_pt15_01_owner_feet.py`: private-overlay board-cache-bypass mutation.
- `tests/suites/intent_chip_placement_suite.gd`: matched pt14-04 benchmark.
- `tests/fixtures/pt15_01_before_sole_badges.gd`: one extra EOF blank line removed.
- This proof report. No other code or assets changed in the fix round.

## Focused verification

Logs are under `/private/tmp/pt15-01-feedback3/`:

- `PT15 SOLE CACHE: 20 warm layouts; clips=0 projections=0 source_scans=0`.
- `PT15 OWNER FEET RESULT: PASS (55 assertions; 0 failures)`.
- Existing four mutations killed; board silhouette-cache bypass also killed.
  Combined Python run: `Ran 2 tests in 31.865s` / `OK` (`mutations.log`).
- Final cache guard/invalidation rerun: `PT15 OWNER FEET RESULT: PASS (55 assertions; 0 failures)`; bypass mutation killed; `Ran 1 test in 10.361s` / `OK` (`cache-final.log`).
- `INTENT CHIP PLACEMENT RESULT: PASS (306 assertions; 0 failures)`
  (`intent-focused.log`, `--mutation-only`; includes live source/hero checks).
- `PT15 ACCEPTED EQUIVALENCE: 172 cases; 0 changed rectangles; 0 changed complete
  layouts; 0 changed silhouette geometries` (artifact comparison).
- Six-enemy benchmark `INTENT CHIP PLACEMENT RESULT: PASS (1 assertions; 0 failures)`.
- Python isolation audit: 228 modules, exit 0 (`python-audit.log`). The existing
  module declaration remains temporary-only; no new Python module was added.
- `git diff --check` and `git diff --check 230731f2ec41795dbfbac68fd0abeab18f84a1dd`
  both clean. The latter checks the complete base-to-working-tree patch.
  The review's `base...HEAD` command still describes the old committed tree
  until the design owner commits this fix; no commit was made here.

No full suite or peer review was run. The previously documented unrelated HUD
badge failures are untouched and were not rerun for this cache-only change.
No unresolved design placeholders. New test-only fields: `WARM_LAYOUTS=20`,
`MOVED_TILE=(3,3)`, `SECOND_TILE=(3,2)`, and the documented 1.05 performance guard.

Reproduce the final matched measurement:

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/pt15-01 && python3 tools/godot_task_runner.py --task-id pt15-01 --stream -- godot --headless --path . --script tests/intent_chip_placement_check.gd -- --benchmark-only
```

Earlier behavior proof and the director's windowed commands follow unchanged.

---

# pt15-01 feedback 2 — search the preferred side first

All changes remain uncommitted on `codex/pt15-01`. No review, commit,
publication, task-queue or windowed operation was performed. Approved assets,
rig data, Mirror registration and enc-03's `is_attack` hunk are unchanged.

## Implemented order

Using the same HUD obstacles plus the owner's 6% sole rectangle grown 4px:

1. Coverage-preferred home, with the unchanged pt14-04 scoring and side margin.
2. Nearest clear placement within 24px of **that home only**.
3. Other side's home.
4. Nearest clear placement within 24px of the other home only.
5. Existing fallback at the original preferred home.

The existing solver gains `only_preferred=false`; existing callers retain
its original two-home behavior. `place_chip` requests one-home searches. Solver
edges, Euclidean radius, vertical tie-break, bounds and obstacle handling are
unchanged. Clear preferred homes remain byte-identical.

## Sweep

All 43 enemy types, front/rear and both reflections, use real production-board
layout at 1920x1080 and 100% UI scale. The comparison uses frozen pt14-04
placement with current rig sources and Mirror registration. The table records
moved / flipped / slid with distance / unchanged / fallback for every case,
old/new rectangles and sole overlaps. Side means the coverage-preferred home;
vertical slides retain that home identity.

- **107 preferred-side slides**, maximum **23.1229858398438px**.
- **6 flips**, each after its preferred one-home search is exhausted.
- **56 complete unchanged layouts**, including every clear preferred home.
- **3 existing fallbacks**: Vaeloryx front/mirrored, rear/normal, rear/mirrored.
- Total **113 moved rectangles**; three additional fallback-state changes keep
  the original rectangle.
- Feedback 1 had 85 flips. **79 of those now become preferred-side slides**.
- Both actual Mirror sole contacts have zero chip overlap in all four views,
  checked independently from each approved foot part's bottom three opaque rows
  and layout offset. The padded sole obstacle is also clear in all four views.

Remaining flips (all are blocked by the owner sole rectangle itself; the
nearest escape even before considering other obstacles exceeds 24px):

| Case | Smallest sole-only escape |
| --- | ---: |
| Warden front/normal | 24.770px |
| Vaeloryx front/normal | 24.116px |
| Storm Cantor front/normal | 25.829px |
| Storm Cantor front/mirrored | 25.829px |
| Last Lamplighter front/normal | 25.470px |
| Last Lamplighter front/mirrored | 25.470px |

Complete table and exact geometry/reasons:
`/private/tmp/pt15-01-feedback2/sweep/sweep.md` and `sweep.json`.
The JSON records each preferred home, region obstacles, viewport bounds and
both search-exhaustion results. No nonfallback chip intersects its own sole
obstacle. Every actual displacement is at most the unchanged 24px limit.

## Files and expectation changes

- Runtime changes this round: `scripts/intent_badges.gd` and
  `scripts/intent_chip_placement.gd`.
- Existing affected tests: `tests/suites/intent_chip_placement_suite.gd` and
  `tests/pt14_01_coverage_suite.gd`. Four exact-home/setup expectations now allow
  the newly specified same-side search; their premises and hard constraints
  remain explicit. The shared reference changes from feedback-1 order to the
  director's new order. Every changed expectation is listed in
  [the expectation ledger](pt15_01_expectation_changes.md), with **272 changed
  chip/fixture positions across 126 fixtures** relative to feedback 1.
- New focused reference/diagnostics: `tests/fixtures/pt15_01_preferred_side_placement.gd`,
  `tests/pt15_01_slide_diagnostics.gd`. The frozen
  `tests/fixtures/pt15_01_before_sole_badges.gd` retains its old default policy
  and gains optional test-only placement/diagnostic hooks.
- Updated checks/reporting: `tests/pt15_01_sole_layout_assertions.gd`,
  `tests/suites/pt15_01_owner_feet_suite.gd`, `tests/pt15_01_foot_sweep.gd`,
  `tests/test_pt15_01_owner_feet.py`, this report and the expectation ledger.
- Retained from earlier implementation: Mirror-only
  `scripts/actor_presentation.gd` edit, `tests/test_glacial_mirror_registration.py`,
  `tests/pt15_01_owner_feet_check.gd`,
  `tests/pt15_01_hud_foot_reentry_check.gd`,
  `tests/pt15_01_mirror_sole_contacts.gd`, both strict capture contracts and
  the temporary-only module entry in `tools/python_suite_resources.json`.

Frozen pt14 soft-coverage checks still run before the hard sole obstacle.
Every unchanged fixture retains its original current-coverage assertion.
The new full-layout reference check proves the only extra policy is searching
one home before trying the next. Bounds, collision, distance, fallback-anchor,
animation, facing, order-disc, input and privacy checks are retained. HUD-only
preferred slides are now legitimate too. No unrelated assertion was changed.

## Observed focused results

All Godot launches use the mandatory task runner with `--task-id pt15-01` and
`--headless`. Logs are in `/private/tmp/pt15-01-feedback2/`.

| Check | Exact result | Evidence |
| --- | --- | --- |
| Sole/order/source control | `PT15 OWNER FEET RESULT: PASS (23 assertions; 0 failures)` | `mutations.log` |
| Mutations | `PT15 MUTATION RESULT: PASS (4/4 killed; control passes; production untouched)` / `Ran 1 test in 22.515s` / `OK` | `mutations.log` |
| All-enemy sweep | `PT15 SOLE SWEEP RESULT: PASS (43 types; 172 facings; 113 moved; 6 flipped; 107 slid; 56 unchanged; 3 fallbacks; 808 assertions; 0 failures)` | `sweep/sweep.log`, `sweep.json`, `sweep.md` |
| Intent | `INTENT CHIP PLACEMENT RESULT: PASS (16358 assertions; 0 failures)` | `intent.log` |
| Threats | `THREATS AT REST TEST RESULT: PASS (17280 assertions; includes compass suite)` | `threats.log` |
| HUD sole re-entry | `PT15 HUD FOOT REENTRY RESULT: PASS` | `hud-foot-reentry.log` |
| Mirror and Mortar normal Continue, headless validation | `REAL FIGHT CAPTURE VALIDATION: PASS` for both | `mirror-validation.log`, `mortar-validation.log`; JSON in corresponding directories |
| UI identity lint | `Ran 25 tests in 3.628s` / `OK` | `ui-identity.log` |
| Python isolation audit | `ISOLATION AUDIT: 228 modules; /private/tmp/pt15-01-feedback2/python-audit/isolation-audit.md` | `python-audit.log`, exit 0 |
| HUD badges | `COMBAT HUD BADGES TEST: FAIL` (same three unrelated failures) | `hud-badges.log` |
| Whitespace | `git diff --check` emits nothing | exit 0 |

Four mutations remove the owner obstacle, remove sole padding, zero the sole
band, or accidentally search both sides before finishing the preferred side.
Private overlays and unique runner HOME directories isolate all engine state.

The prior three unrelated HUD badges failures remain outside this change:
“Intents starts off with its semantic label intact”, “ON retains semantic text
and brightens the plate”, “Controller focus must expose the complete inspection
tooltip”. Those assertions and their behavior remain untouched.

Engine logs retain the existing macOS system-CA `ret != noErr` diagnostic.
The Mirror validation also reports ObjectDB instances leaked at exit. No full
Python/Godot suite, peer review or fresh screenshot was run. Windowed proof is
for the director.

## Chosen defaults and open issues

No new player-facing values or unresolved design placeholders. Existing test
geometry defaults remain: sweep tiles `(4,3)` / `(4,6)`, area tolerance 0.01px²;
synthetic anchor `(500,500)`, owner bounds `(400,400,200,120)`, foot width 4,
torso height 90, gap query `(490,514,4,4)`, epsilon 0.001. New test-only fields
are `EXHAUSTED_FOOT_WIDTH=90` and diagnostics `DISTANCE_EPSILON=0.001`.
Sole top/height, expected padding and shift remain derived contract values
512.8 / 7.2 / 4 / 8. Optional fixture callables and diagnostic dictionaries
carry proof data only. The Mirror/rig values are unchanged from the brief.
The only outstanding observations are the unrelated HUD badges failures and
the director's windowed inspection.

## Proof for the design owner

Run in a fresh output directory at 1920x1080, 100% UI scale. Both commands use
the existing fix18 probe and the game's normal Continue, camera and HUD.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/pt15-01 && LABYRINTH_REAL_FIGHT_CAPTURE_OUTPUT=/private/tmp/pt15-01-feedback2-mirror-1080 python3 tools/visual_probe_runner.py --task-id pt15-01 --no-headless --display-driver macos --audio-driver Dummy --min-images 3 --expect-size 1920x1080 --proof-contract tests/pt15_01_real_fight_capture_contract.json --result-manifest /private/tmp/pt15-01-feedback2-mirror-1080/runner.json tests/fix18/real_fight_capture_probe.gd -- --label mirror-separated --player-position 4:4 --biome iskaldra --seed 7262026 --enemy-types glacial_mirror,glacial_mirror --enemy-positions 4:2,4:6 --crop enemy_1:3 --crop enemy_2:3
```

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/pt15-01 && LABYRINTH_REAL_FIGHT_CAPTURE_OUTPUT=/private/tmp/pt15-01-feedback2-mortar-1080 python3 tools/visual_probe_runner.py --task-id pt15-01 --no-headless --display-driver macos --audio-driver Dummy --min-images 3 --expect-size 1920x1080 --proof-contract tests/pt15_01_slag_mortar_capture_contract.json --result-manifest /private/tmp/pt15-01-feedback2-mortar-1080/runner.json tests/fix18/real_fight_capture_probe.gd -- --label slag-mortar-fire --player-position 4:4 --biome vyraketh --seed 7262026 --enemy-types slag_mortar,slag_mortar --enemy-positions 4:2,4:6 --crop enemy_1:3 --crop enemy_2:3
```
