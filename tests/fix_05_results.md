# fix-05 implementation and evidence

Worktree: `codex/fix-05`. Changes remain uncommitted. No Git mutation, queue edit, peer review, signoff request, publication or windowed run was performed by this worker.

## Numbered requirements

1. **Root cause measured.** The review's unchanged production call times out at 300 seconds for seed `1792271957`, after more than 671,000 nodes in Section II. A temporary diagnostic copy of the original graph (`245dc60b1`) capped that first topology at 4,096 nodes to inspect the failure without repeating the hang. Section I needed 29 nodes. In Section II, 2,032 of 2,037 propagation failures emptied row 2, lane 3; 6,118 fork-candidate rejections repeatedly rediscovered the same conflict. The opening at lane 2 forks to row-2 lanes 1/2/3. On the failing branch those destinations have only Mystery/Event available, so three distinct non-Combat types cannot fit into two colours. The first observed leaf assigned Mystery/Event to the first two and emptied the third. Geometry, widths, fixed rows, physical-door legality and divergence all pass: structural checks do not inspect the rolled type domains. The old witness-first search and row-order fight partitions decide unrelated rooms before discovering this local contradiction. Its singleton-only fork checks miss the insufficient domain union. No duplicate raw domain state was observed in this 4,096-node prefix; this is a delayed-contradiction explosion, not evidence of identical state repetition. The next topology solved in 36 nodes. Structured evidence: `tests/fixtures/fix_05_search_trace.json`; original diagnostic source and logs remain in `/private/tmp/fix_05_original_graph.gd`, `/private/tmp/fix_05_trace.gd`, `/private/tmp/fix-05-before-trace-final.log`.
2. **Bounded deterministic search.** Each topology has a 40-node budget. Exhaustion stops sibling exploration immediately and advances the existing outer 50-attempt loop, separately counted from proved unsatisfiability. Fallback retains the existing seed/section log. Variable selection uses smallest domain, then greatest constraint degree, then stable layout order. Seeded candidate preference remains; MRV now branches directly on types, avoiding a redundant fight-membership decision on each successful room. Forward checking covers every route's fights, Guardian limit, service availability and Guardian-free bypass; section counts force needed Guardian/Scavenger slots. Fork domain unions now satisfy Hall's condition before branching, including the three-way Combat repeat exception. Canonical domain-bit signatures memoise proved failed partial states; a cutoff never enters the cache. Diagnostics are optional, kept outside the run state, and do not affect RNG or saved data.
3. **Compatibility and map-02 metrics.** Revisions 3/4 retain their generator paths and fixtures. The new performance regression runs through the existing v5 suite, which the full section-map suite already invokes. Existing knowledge, layout-gap, public dispatch, serialized-save compatibility, frequency targets, weights, Mystery rolls, analytics and input assertions remain. The original revision-5 metrics were copied unchanged to `tests/fixtures/fix_05_revision5_before_metrics.json`; the normal metrics fixture is regenerated from seeds 1–200.
4. **Performance regression.** `tools/section_map_performance.gd` measures public `Graph.initialize()` wall time and each complete section (topology, assignment and room wiring). `tests/fixtures/fix_05_performance_seeds.json` is a fixed list of 2,000 distinct unsigned 32-bit seeds, including `1792271957`. The fast fixture is that seed plus the 20 slowest full runs, deduplicated. The focused and full suites run those seeds, enforce 250ms per section / 1,000ms per full map / ≤1% fallback, check exact graph determinism with/without diagnostics, and verify all route/section rules. Logic regressions cover insufficient fork colours, both Combat-repeat cases, overlapping forced section counts, per-route Guardian bounds, memo reuse and cutoff semantics. A separate child proves all 50 exhausted attempts and exactly one logged fallback within its unchanged 10s test deadline.

## Chosen defaults

Implementation only: `V5_TYPE_NODE_BUDGET=40`; `V5_TYPE_BITS` byte encoding; MRV ties use constraint degree then layout order. Benchmark/test only: committed seeds drawn with Python `Random(0xF105).getrandbits(32)` after prepending the reported seed; slow seeds ranked by full-run milliseconds with seed as tie breaker; nearest-rank p99; 100-seed progress interval; default report `user://fix_05_performance.json`; rejection fixture seed 1 / Section I / zero-node budget / 10s deadline; original diagnostic prefix cap 4,096 nodes; sweep runner deadline 900s for 12,000 sections. Limits of 250ms, 1,000ms, 1%, 2,000 seeds and 20 slow cases come from the brief. No player-facing values were chosen. No `TODO_DESIGN_*` placeholders are needed.

## Proof for the design owner

No renderer capture or inspection-fixture change is required by this backend performance brief, and the worker has no window-server access. If the owner wants fresh captures of the existing map-02 visual cases, the existing probe and proof contract remain available:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fix-05 && python3 tools/visual_probe_runner.py tests/section_map_variety_probe.gd --task-id fix-05 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --proof-contract tests/section_map_variety_visual_contract.json --result-manifest /private/tmp/labyrinth-inspection-manifests/fix-05-variety.json -- --debug-reveal-section
```

That probe fixes UI scale at 100% and emits `user://map_02_variety/seed_{001,083,200}_section_{1,3,5}.png` under the runner's isolated user directory. No capture paths or visual approval are claimed from this worker. Commit, separate peer review, inspection fixture and publication remain assigned to the design owner.

## Final performance sweep

Godot `4.6.1-stable (official)` on `Apple M5 Pro`. All 2,000 fixed seeds × 6 sections pass. The full JSON contains all 12,000 section samples and diagnostics: `/private/tmp/fix-05-performance.json`; console log: `/private/tmp/fix-05-performance.log`. A compact, checked-in-ready summary with the 20 slowest runs and the known hang case is `tests/fixtures/fix_05_performance_summary.json`. No wall-time cutoff influences generation.

| Section | Max ms | p99 ms | Mean ms | Fallback |
| --- | ---: | ---: | ---: | ---: |
| 1 | 53.616 | 34.255 | 13.744 | 0/2000 |
| 2 | 85.491 | 46.485 | 19.497 | 0/2000 |
| 3 | 63.118 | 46.998 | 18.857 | 0/2000 |
| 4 | 88.842 | 43.843 | 18.303 | 0/2000 |
| 5 | 85.206 | 48.453 | 18.655 | 0/2000 |
| 6 | 126.045 | 67.632 | 26.674 | 0/2000 |
| All sections | 126.045 | 51.788 | 19.288 | 0 |
| Full runs | 225.317 | 177.673 | 115.893 | 0 |

Observed result:

```text
SECTION MAP PERFORMANCE: PASS (2000 seeds x 6 sections; max section 126.045ms; max run 225.317ms; fallback 0/12000; max attempt 36.150ms / 40 nodes)
```

Seed `1792271957`: Section II completes its first topology in **31 search nodes / 23.046ms**, and the complete six-section public initialization takes **120.326ms**. No fallback or budget exhaustion occurs for this seed.

Calibration: a preliminary 64-node version passed the outer performance limits but recorded a 70.524ms assignment attempt, so it was rejected as final evidence. Direct type branching, a 40-node budget, cheaper two-child fork checks, and a single global route check after the propagation fixed point produced the final result above. The final command additionally fails if any assignment attempt reaches 50ms. The fast integrated suite checks the deterministic node bound and the brief's section/run limits; the tighter per-attempt timing is calibrated by the separate sweep.

Reproduce:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fix-05 && python3 tools/godot_task_runner.py --task-id fix-05 --timeout 900 --stream -- godot --headless --path . --script tools/section_map_performance.gd -- --output /private/tmp/fix-05-performance.json
```

Use `--record-fast` only when deliberately regenerating the fast fixture after a complete sweep. `--fast` measures the fixed fast fixture. Refresh the compact proof summary together with the fast list; the fixture test deliberately rejects mismatched snapshots. After the full sweep above with `--record-fast`, the exact summary regeneration is:

```sh
python3 - <<'PY_SUMMARY'
import hashlib, json
from pathlib import Path
report = json.loads(Path('/private/tmp/fix-05-performance.json').read_text())
assert report['seed_count'] == 2000 and not report['failures']
summary = {key: value for key, value in report.items() if key != 'samples'}
summary['slowest_runs'] = [{key: value for key, value in sample.items() if key != 'diagnostics'} for sample in report['slowest_runs']]
summary['known_hang_seed'] = next(sample for sample in report['samples'] if sample['seed'] == 1792271957)
summary['list_generation_seed'] = 0xF105
summary['seed_list_sha256'] = hashlib.sha256(Path('tests/fixtures/fix_05_performance_seeds.json').read_bytes()).hexdigest()
summary['type_node_budget'] = 40
summary['sweep_runner_timeout_seconds'] = 900
Path('tests/fixtures/fix_05_performance_summary.json').write_text(json.dumps(summary, indent=2) + '\n')
PY_SUMMARY
```

## Map-02 before / after, seeds 1–200 × 6

| Metric | Before fix (revision 5) | After fix (revision 5) |
| --- | ---: | ---: |
| Fallback | 0/1200 | 0/1200 |
| Distinct topologies, each section | 200/200 (100%) | 200/200 (100%) |
| Median routes | 17.0 | 17.0 |
| ≥4-node row | 1200/1200 | 1200/1200 |
| Long divergence | 1200/1200 | 1200/1200 |
| Route/section rules | 1200/1200 | 1200/1200 |
| Search nodes | 87295 | 31591 |
| combat | 44.65% | 45.92% |
| mystery | 17.11% | 16.96% |
| treasure | 8.69% | 8.72% |
| campfire | 8.49% | 8.49% |
| guardian | 6.84% | 6.47% |
| scavenger | 6.79% | 6.31% |
| event | 4.99% | 4.84% |
| graftwright | 2.44% | 2.29% |

Every frequency is within ±3 percentage points of the map-02 targets. The tool also prints the original revision-4 column for comparison. Final metrics log: `/private/tmp/fix-05-metrics.log`.

## Focused checks completed

All commands were run from this worktree through the required runners. Logs:

| Check | Exact observed result lines | Log |
| --- | --- | --- |
| Final 2,000-seed sweep | `SECTION MAP PERFORMANCE: PASS (2000 seeds x 6 sections; max section 126.045ms; max run 225.317ms; fallback 0/12000; max attempt 36.150ms / 40 nodes)` | `/private/tmp/fix-05-performance.log` |
| Map-02 metrics | `Section map variety metrics: PASS (200 seeds x 6 sections)` | `/private/tmp/fix-05-metrics.log` |
| Focused v5 / compatibility | `Map 02 legacy hashes: checked 200 seeds each for revisions 3 and 4`; `Section map v5 suite: 0 failures` | `/private/tmp/fix-05-focused.log` |
| Fast performance regression | `Section map fast performance: PASS (21 seeds x 6 sections; max section 165.636ms; max run 279.491ms; fallback 0)` | `/private/tmp/fix-05-focused.log` |
| Type budget / fallback | `Section map type rejection: PASS (49 budget-exhausted, 1 structural-exhausted, 1 fallback)` | `/private/tmp/fix-05-budget-rejection.log` and focused log |
| Structural budget | `Section map structural rejection: PASS (2500 proposals, 50 exhausted batches, 418ms)` | `/private/tmp/fix-05-focused.log` |
| Probe lifecycle, headless only | `Map 02 probe setup: PASS (9 full-visibility sections; no captures)` | `/private/tmp/fix-05-focused.log` |
| Layout sweep, headless | `Map 02 ordinary button gaps: 0 violations (200 seeds x 6 sections)`; `Map 02 boss button gaps: 0 violations (200 seeds x 6 sections)`; `Section map v5 no-overlap suite: PASS` | `/private/tmp/fix-05-layout.log` |
| Solver logic | `Section map performance suite: 0 failures` | `/private/tmp/fix-05-logic.log` |
| Output bootstrap | `OUTPUT GDIGNORE: PASS (12 folders; 3 referenced roots)` | tool output |

Focused reproduction commands:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fix-05 && python3 tools/godot_task_runner.py --task-id fix-05 --stream -- godot --headless --path . --script tests/section_map_v5_test.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/fix-05 && python3 tools/godot_task_runner.py --task-id fix-05 --stream -- godot --headless --path . --script tools/section_map_variety.gd -- --seeds 200 --output /private/tmp/fix-05-metrics.json
cd /Users/borgerding/workspace/Labyrinth.worktrees/fix-05 && python3 tools/godot_task_runner.py --task-id fix-05 --stream -- godot --headless --path . --script tests/section_map_v5_layout_test.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/fix-05 && python3 tools/godot_task_runner.py --task-id fix-05 --stream -- godot --headless --path . --script tests/section_map_performance_test.gd
```

## Files changed

- `scripts/section_map_graph.gd`: bounded v5 search, forward checking, MRV, failed-state memo and optional non-persistent timings.
- `tools/section_map_variety.gd`: revision-4 / pre-fix v5 / post-fix v5 comparison.
- `tools/section_map_performance.gd`: fixed sweep, timing reports, slow-fixture regeneration and calibration gate.
- `tests/suites/section_map_v5_suite.gd`: integrates the new regression with the existing focused/full suite.
- `tests/suites/section_map_performance_suite.gd`: seed, pruning, cache, cutoff, timing, determinism and rules checks.
- `tests/section_map_performance_test.gd`: standalone focused runner.
- `tests/section_map_type_rejection_test.gd`: isolated forced-exhaustion child.
- `tests/fixtures/fix_05_performance_seeds.json`: fixed 2,000-seed list.
- `tests/fixtures/fix_05_slow_seeds.json`: hang seed plus the final sweep's 20 slowest runs.
- `tests/fixtures/fix_05_performance_summary.json`: final sweep summary and provenance.
- `tests/fixtures/fix_05_search_trace.json`: structured pre-fix search diagnosis.
- `tests/fixtures/fix_05_revision5_before_metrics.json`: unchanged snapshot of the prior metrics.
- `tests/fixtures/map_02_revision5_metrics.json`: regenerated 200-seed results.
- `tests/fix_05_results.md`: this handoff and reproduction commands.

## Full Godot suite

The required parallel runner completed with exit 0 while full Python discovery ran concurrently. Every program child passed. Exact final lines:

```text
MAIN BODY RUNTIME: 256.841 seconds
MAIN BODY ASSERTIONS: 385082
FULL SUITE RUNTIME: 304.093 seconds (budget 900 seconds)
TEST RESULT: PASS
```

The new regression under this load reported:

```text
Section map fast performance: PASS (21 seeds x 6 sections; max section 167.923ms; max run 294.721ms; fallback 0)
```

Log: `/private/tmp/fix-05-full-godot.log`.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fix-05 && python3 tools/godot_task_runner.py --task-id fix-05 --timeout 900 --stream -- godot --headless --path . --script tests/run_tests.gd
```

## Full Python suite and final state

Exit 0. Exact observed result:

```text
Ran 698 tests in 589.047s
OK (skipped=63)
```

Log: `/private/tmp/fix-05-full-python.log`. The discovery command was:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fix-05 && python3 -m unittest discover -s tests -p 'test_*.py' -v
```

Final `git diff --check` and JSON/provenance checks pass. Only the 14 listed files changed. No existing failure assertions, approved assets, art values, legacy hash fixtures or unrelated checkout changes were modified. No `TODO_DESIGN_*` placeholders and no open implementation issues remain. No windowed capture is claimed. The design owner retains commit, peer review, inspection fixture and publication, as assigned in the task.
