# map-02 implementation result

Branch `codex/map-02`; base `340026ecbdf1f6e98992dc24fff1b492c611a9f1` (`codex/peer-benchmark`). All implementation changes remain uncommitted. No publication, task-queue edits, peer review or reviewer agents were run.

## Root cause measured before rule changes

Godot 4.6.1, seeds 1–200 × 6 sections, revision 4. The instrumented adapter was checked against production walks and room types on all 1,200 sections before changing the generator. Hashes were recorded before changes for 200 complete revision-4 graphs and 200 revision-3 graphs.

| Rejection reason | Count |
| --- | ---: |
| Crossing moves | 726,020 |
| Door compatibility | 2,800 |
| Fork-type distinctness | 297,232 |
| Per-route service | 0 |
| Per-route Guardian count | 829,153 |
| Per-route fight count | 4,205,801 |
| Section-level counts / bypass | 294,091 |
| Fork into fixed-type row | 75,492 |
| Opening count | 33,171 |
| Interior row count | 7,445 |
| Guardian row eligibility | 945,403 |
| Scavenger row eligibility | 917 |
| Graftwright preceding fights | 33,621 |
| Consecutive matching special rooms | 282,401 |

Counts are non-exclusive: one rejected assignment can violate multiple rules. Crossing counts are rejected delta choices. Door counts follow production short-circuit evaluation, after earlier structural checks pass.

The topology stage sampled **81,192** candidates, exhausted its 50-sample limit **1,533** times, and delivered the canned topology in **1,082/1,200 accepted sections (90.17%)**. The type stage failed **519** searches, all on its **12,000-assignment budget**. The outer section fallback ran **0** times. The dominant structural rejection was a fork into a fixed-type row; revision 5 reuses its already-required onward edge while generating walks. It also enforces the outer entry thresholds during construction. Room assignment now uses exhaustive seeded backtracking with route bounds, section-cardinality witnesses and fight-membership partitions, with no arbitrary assignment cutoff. Only proved-unsatisfiable assignments consume the 50 topology rerolls.

## Before / after

Both columns use seeds 1–200 × 6 sections. The required frequency comparison is against the brief's triage targets, not this larger revision-4 sample; every revision-5 frequency is within ±3 percentage points of those targets.

| Metric | Revision 4 | Revision 5 |
| --- | ---: | ---: |
| Accepted canned topology | 1082/1200 (90.17%) | 0/1200 (0%) |
| Distinct signatures I–VI | 39 / 13 / 22 / 23 / 15 / 12 | 200 / 200 / 200 / 200 / 200 / 200 |
| Median routes | 10 | 17 |
| Sections with ≥4-node row | 1177/1200 (98.08%) | 1200/1200 (100%) |
| Long divergence | 1200/1200 (100%) | 1200/1200 (100%) |
| Route and section constraints | 1200/1200 | 1200/1200 |
| Combat | 44.98% | 44.65% |
| Mystery | 17.75% | 17.11% |
| Treasure | 9.01% | 8.69% |
| Campfire | 8.96% | 8.49% |
| Guardian | 6.43% | 6.84% |
| Scavenger | 6.19% | 6.79% |
| Event | 4.57% | 4.99% |
| Graftwright | 2.11% | 2.44% |

Observed result: `Section map variety metrics: PASS (200 seeds x 6 sections)`. The final tool uses the arithmetic mean of the two middle route counts for even samples; the median remains 17.0. Log: `/private/tmp/map-02-variety-final.log`.

## Numbered requirements

1. **Revision preservation:** new runs use revision 5; explicit revisions 3 and 4 retain their generators. Pre-change graph hashes match for all 200 seeds for each revision. Production revision-4 save/load/repair retains every map value and the recorded revision. Legacy revision-3/4 tests remain explicit legacy tests.
2. **Lanes / walks:** five lanes, six weighted walks, three distinct opening Combat nodes, first three walks cover those openings, additional walks choose an opening, clamped 30/40/30 adjacent movement, crossing-free edges.
3. **Structure then types:** topology is validated before seeded CSP assignment. All existing room, route, physical-door, Mystery-roll and depth-weighting rules remain. Fallback occurs only after 50 proved-unsatisfiable topologies and prints seed/section on every use. No fallback occurred in the measured 1,200 sections.
4. **Variety:** every measured section has a ≥4-node row and ≥4-row divergence; repeated identical lane sets are capped at three rows. Signatures are the ordered lane strings per generating walk, as in triage.
5. **Layout:** revision 5 divides lane placement by 4. Per feedback 1, the boss stays at its original last-step centre; entry through the last interior column are evenly spaced from x=80 to boss x−175. Only revision-5 jitter is clamped; final-interior x jitter cannot move toward the boss. Earlier layouts and all node dimensions are unchanged. Actual 1920×1080 / 100% panel field is 1864×823; section VI interior spacing is exactly 135px in this field.
6. **Fog / Scout:** knowledge, fog, Scout and analytics implementations are unchanged. The existing complete knowledge/Scout assertions now also run against revision 5; the direct headless check reports `Section map v5 suite: 0 failures`. Legacy revision-4 coverage remains.

## Feedback 1 implementation and current verification

1. **Spacing:** revision 5 reserves 175px before the fixed boss centre and evenly spaces every earlier column. Final-interior x jitter cannot move toward the boss. Revisions 3 and 4 retain their layouts. The generator is unchanged: SHA-256 `29f3022da47f9c661600bd13ec6a1e95eee34f8c293e3c0c2734ae5137ad7b74`. The rerun's metrics JSON exactly matches the previous fixture.
2. **Probe readiness:** startup is deferred until the scene tree is active, then awaits panel ready and two layout frames before selecting sections. Pre-ready `select_section` retains reached history without accessing unbuilt tabs. Synchronous and actual-tree regressions pass. Explicit errors and nonzero exits replace assertions for setup, missing nodes, capture size and write failures. `--setup-only` checks all nine cases headlessly without capturing; a headless capture request fails immediately.
3. **Integration:** `git merge --ff-only codex/peer-benchmark` failed because the sandbox cannot create the parent repository's `ORIG_HEAD.lock`. No files or refs changed. The upstream art fix and merged maquette builder are therefore absent. The unrelated `_event_panel` snapshot issue and the director's first-run log are unchanged.
4. **Runtime:** the 200-seed proof remains separate. All main-suite assertions and seed counts remain. The 50 revision-4 hash checks reuse pristine outputs already generated by the legacy suite. The revision-3 fixture loop creates engine states without a current map, then generates revision 3 directly, avoiding 64 immediately-discarded revision-5 maps. No generator, timeout or budget was changed.

All feedback-1 runs use HEAD `340026ecbdf1f6e98992dc24fff1b492c611a9f1` plus the uncommitted implementation because the merge remains blocked.

| Check | Observed result |
| --- | --- |
| Variety, 200 seeds × 6 | `Section map variety metrics: PASS (200 seeds x 6 sections)`; metrics unchanged |
| Final focused v5 | `Map 02 metrics: PASS (50 seeds x 6 sections)`; `Map 02 legacy hashes: checked 200 seeds each for revisions 3 and 4`; `Section map v5 suite: 0 failures`; exit 0 |
| Pre-ready selection | `Map 02 pre-ready history selection: PASS` |
| Ordinary gaps | `Map 02 ordinary button gaps: 0 violations (200 seeds x 6 sections)` |
| Boss gaps | `Map 02 boss button gaps: 0 violations (200 seeds x 6 sections)` |
| Layout suite | `Section map v5 no-overlap suite: PASS`; exit 0 |
| Probe setup | `Map 02 probe setup: PASS (9 full-visibility sections; no captures)`; exit 0 |
| Probe fail-fast | Headless capture rejected with an explicit windowed-renderer message; expected exit 2 |
| UI identity | `Ran 25 tests in 2.936s`; `OK` |
| Final full Godot | `FULL SUITE RUNTIME: 818.289 seconds (budget 900 seconds)`; `TEST RESULT: PASS`; wall time 823.800s; exit 0 |
| Full Python | `Ran 617 tests in 507.440s`; `FAILED (failures=1, skipped=61)`; wall time 507.916s; exit 1 |
| Ancillary checks | Headless parser checks, shell syntax and `git diff --check`: exit 0; `OUTPUT GDIGNORE: PASS (13 folders; 3 referenced roots)` |

The first feedback-1 Godot attempt timed out at 900s (wall 900.092s, exit 124), after `SFX SYNC HARNESS RESULT: PASS (4010 observations, 0 failures)`. It did not pass the full suite. After eliminating the unused fixture generation above, the final run completed at 818.289s, below both the 900s budget and the previously observed 831.901s run. It confirms `Map 02 legacy hashes: reused 50 pristine revision-4 outputs from the legacy suite`; coverage was not reduced.

The sole Python failure remains `test_committed_jobs_replay_approved_pixels_without_external_inputs`, job `frostglass_lancer/mq4_rear`: rebuilt `7879c813af25b39f68fd4084275d1e239dd873e09bc551145a285c00948031e7`, approved `a74bc9cdd606bc813de6535235524f89ec5cc488bfd8d51ab9d0119b5fe47288`. The owner-fixed upstream commit cannot be integrated until the merge runs outside the sandbox. No art data or assertions were rewritten.

Evidence logs in `/private/tmp/`:

- `map-02-feedback-variety.log`, `map-02-feedback-focused-final.log`, `map-02-feedback-layout.log`.
- `map-02-feedback-probe-setup.log`, `map-02-feedback-probe-headless-rejection.log`, `map-02-feedback-suite-parser.log`.
- `map-02-feedback-ui-lint.log`, `map-02-feedback-gdignore.log`.
- `map-02-feedback-godot-full.log` (timeout), `map-02-feedback-godot-final.log` (PASS), `map-02-feedback-python-full.log` (known failure).

## Initial validation (before feedback 1)

The following are historical results. The feedback-1 results above supersede them.

- 200-seed tool: `Section map variety metrics: PASS (200 seeds x 6 sections)`.
- Focused suite: `Map 02 metrics: PASS (50 seeds x 6 sections)`; `Map 02 legacy hashes: checked 200 seeds each for revisions 3 and 4`; `Section map v5 suite: 0 failures`.
- Final layout run: `Map 02 ordinary button gaps: 0 violations (200 seeds x 6 sections)`; `Map 02 boss button gaps: 1862 violations (200 seeds x 6 sections)`; `Section map v5 no-overlap suite: FAIL`.
- First gap failure: `seed=1 section=1 Room_0_3 / Room_4_0 gap=0.000px`.
- UI identity lint: `Ran 25 tests in 2.622s` / `OK`.
- Probe parser check (mandatory runner, headless `--check-only`): exit 0. Capture wrapper `sh -n`: exit 0. `git diff --check`: exit 0.
- Revision-5 fog/Scout check: `Section map v5 suite: 0 failures` with `tests/section_map_v5_test.gd -- --knowledge-only`; exit 0.
- Legacy panel-equivalence fixture is now explicitly revision 4. Its unchanged snapshot still accesses missing `_event_panel` fields (also present in the base-HEAD test); the runner reports `SCRIPT ERROR: Invalid access to property or key '_event_panel'` and exits 1. The printed `RETAINED SECTION MAP EQUIVALENCE RESULT: {"cases":42,"errors":[]}` is **not** a pass because those script errors abort snapshots. No assertions were rewritten. Log: `/private/tmp/map-02-retained.log`.
- Both new and legacy map capture probes pass headless parser checks; no windowed probe was run.
- Deep-route fixture regression: `Ran 1 test in 3.505s` / `OK` with the final solver.
- Full Godot suite: `FULL SUITE RUNTIME: 831.901 seconds (budget 900 seconds)`; `TEST RESULT: PASS`; exit 0. Log: `/private/tmp/map-02-godot-final.log`. Integrated compatibility samples use 50 seeds per legacy revision; the dedicated focused proof retains all 200. The existing 64-seed revision-4 suite remains unchanged in breadth. No timeout or budget assertion was relaxed. The earlier concurrent run hit the 900-second cap before the final two suites; redundant legacy sampling was reduced for the successful run.
- Final full Python suite: `Ran 617 tests in 570.922s`; `FAILED (failures=1, skipped=61)`; exit 1. Sole failure: `test_committed_jobs_replay_approved_pixels_without_external_inputs`, job `spec/art_identity/jobs/frostglass_lancer/mq4_rear`. Rebuilt pixel hash `7879c813af25b39f68fd4084275d1e239dd873e09bc551145a285c00948031e7` differs from approved `a74bc9cdd606bc813de6535235524f89ec5cc488bfd8d51ab9d0119b5fe47288`. Its test, tooling and art inputs are unchanged from HEAD (`git diff --exit-code HEAD -- tools/art_identity_gate.py tests/test_art_identity_gate.py spec/art_identity`: exit 0). No assertion or approved asset was rewritten. The deep-route fixture passes in this final full run. Log: `/private/tmp/map-02-python-final.log`.

Reproduce headless checks from this worktree:

```sh
python3 tools/godot_task_runner.py --task-id map-02 --timeout 900 --stream -- godot --headless --path . --script tools/section_map_variety.gd -- --seeds 200 --output /private/tmp/map-02-v5.json
python3 tools/godot_task_runner.py --task-id map-02 --timeout 900 --stream -- godot --headless --path . --script tests/section_map_v5_test.gd
python3 tools/godot_task_runner.py --task-id map-02 --timeout 900 --stream -- godot --headless --path . --script tests/section_map_v5_layout_test.gd
python3 tools/godot_task_runner.py --task-id map-02 --timeout 900 --stream -- godot --headless --path . --script tests/run_tests.gd
python3 -m unittest discover -s tests -p 'test_*.py' -v
python3 tests/test_ui_identity_lint.py
python3 tools/godot_task_runner.py --task-id map-02 --timeout 900 --stream -- godot --headless --path . --script tests/section_map_variety_probe.gd -- --debug-reveal-section --setup-only
```

Revision-4 diagnostics can be reproduced with `tools/section_map_variety.gd -- --revision4 --seeds 200` through the same Godot runner. This does not rewrite frozen fixtures unless `--record-baseline` is explicitly supplied.

## Proof for the design owner

Windowed rendering is unavailable in the implementation sandbox. The director’s first run hit the pre-ready `select_section` error recorded in `tests/map_02_director_run1.log`; that log is preserved. The corrected probe passed its nine-case headless setup regression, but has not been rerun windowed by the worker and no new captures are claimed. Use a fresh manifest for the corrected probe:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/map-02 && MAP_02_PROOF_MANIFEST=/private/tmp/labyrinth-inspection-manifests/map-02-variety-run2.json sh tests/map_02_proof.sh
```

The exact expanded renderer command is:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/map-02 && python3 tools/visual_probe_runner.py tests/section_map_variety_probe.gd --task-id map-02 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --proof-contract tests/section_map_variety_visual_contract.json --result-manifest /private/tmp/labyrinth-inspection-manifests/map-02-variety-run2.json -- --debug-reveal-section
```

The runner will print the isolated absolute capture directory. Expected paths within its isolated user namespace are `map_02_variety/seed_001_section_{1,3,5}.png`, `seed_083_section_{1,3,5}.png`, and `seed_200_section_{1,3,5}.png`. All nine images are 1920×1080 at 100% UI scale. The debug reveal exists only in the proof script; it never changes production fog or persisted saves. Override `MAP_02_PROOF_MANIFEST` for a fresh manifest on repeated capture runs. No inspection-fixture command was requested in this unit brief; the owner retains fixture, review, commit and publication responsibilities.

## TODO_DESIGN placeholders

None. `TODO_DESIGN_BOSS_BUTTON_GAP` is resolved by the director’s feedback-1 spacing decision and removed from the code.

## Chosen defaults

Only proof/test choices: integrated legacy compatibility samples use seeds 1–50 (`FULL_SUITE_LEGACY_SEED_COUNT`), with all 200 retained in the dedicated proof; deterministic full-graph samples use seeds 1–5 (`DETERMINISM_SEED_COUNT`); proof seeds are 1, 83 and 200 (`PROOF_SEEDS`), all with distinct lane signatures; the layout formula fixture uses coordinate (3,4), step 2 and lane 4 (named `node` fields); geometric comparison tolerance is 0.001px (`FLOAT_TOLERANCE`); the capture manifest defaults to `/private/tmp/labyrinth-inspection-manifests/map-02-variety.json`. Feedback-1 headless setup uses the measured 1864×823 field, the existing nine proof cases and two layout frames; its `setup_only` flag never captures. Pre-ready regression reuses deterministic seed 1 and the reached section-III entry (`history["current_room"]`), selecting history section I. The final-interior jitter check samples coordinates `(offset, 0)` for offsets 0–32 (`FINAL_JITTER_SAMPLE_COUNT=33`). All gameplay numbers come from the brief, director feedback or existing code. The 1864×1024 panel / (28,28) placement match the existing 1920×1080 map probe; the 1864×823 field was measured headlessly.

## Files changed

- Runtime: `scripts/section_map_graph.gd`, layout and pre-ready section-selection guard in `scripts/section_map_panel.gd`.
- Tools: `tools/section_map_revision4_audit.gd`, `tools/section_map_variety.gd`.
- Tests: `tests/suites/section_map_v5_suite.gd`, `tests/section_map_v5_test.gd`, `tests/section_map_v5_layout_test.gd`, legacy dispatch in `tests/suites/section_map_v2_suite.gd`, explicit revision-4 fixtures in `tests/retained_section_map_equivalence_test.gd` and `tests/section_map_probe.gd`, and full-suite integration in `tests/suites/section_map_suite.gd`. Feedback 1 also reuses pristine legacy hashes and skips immediately-discarded revision-5 maps in the revision-3 fixture loop, preserving every assertion and seed count.
- Evidence/proof: the three `tests/fixtures/map_02_*.json` files, `tests/section_map_variety_probe.gd`, `tests/section_map_variety_visual_contract.json`, `tests/map_02_proof.sh`, and this report.

## Open issues

- The base-branch standalone retained-panel test has stale `_event_panel` snapshot access; its fixture version is corrected, but the unrelated snapshot error remains reported.
- Windowed captures and inspection remain with the owner, as requested.
- `parallel_task.py status` reports an empty acceptance/proof contract despite the brief stating that it was recorded. Owner-managed metadata was not edited.
- The requested peer-benchmark merge remains blocked: the sandbox cannot create `/Users/borgerding/workspace/Labyrinth/.git/worktrees/map-02/ORIG_HEAD.lock`. No Git state was changed by that attempt. The owner must run `git -C /Users/borgerding/workspace/Labyrinth.worktrees/map-02 merge --ff-only codex/peer-benchmark` outside this sandbox. Until then the merged maquette builder and art fix are absent; the full Python suite still has the one known Lancer replay failure. No assertion or protected art file was rewritten.
