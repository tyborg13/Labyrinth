# rr-49 feedback 3 — exact, bounded deterministic submission

Base: `2bd5ea39a0a42eff5f768016406d02ac3510fc54`. The director reports native
ALL GATES (0 errors), sheets and production (88/64) passing at that commit.
This round changes no paint, motion, tuning, time sampling, UV or submitted
vertex. Every change remains uncommitted; the director owns Git, review and
publication. No windowed command was attempted.

## 1. Speed and cache ownership

`stable_skin.gd` compiles nonzero influences into packed float64 arrays once at
registration. Unit-weight vertices use a single-bone loop; two-influence vertices
use grouped bone pairs with the original accumulation order. A generic ordered
fallback remains for other influence counts. The snap expression is inlined
unchanged on the existing 1/256-pixel lattice. There is no intermediate float32
bulk transform. `stable_paint.gd` computes each body/cap bone pose once per rig
frame. Motion and idle buffers each use a bounded 128-entry LRU **per rig mesh**;
one actor cannot evict another actor's entries. No whole-cache clearing remains
in playback. Root following, node paths and source textures are unchanged.

The reviewer harness and log were copied first to `proof/feedback3/`. Its
reported whole front-move median was 24.319–24.328ms, with deterministic
submission off at 0.470–0.472ms. The extended harness measures every joint mesh
and exact-source quad in all seven non-idle clips in both views (51 poses each).
Caches start empty for each clip sequence; repeated identical mesh transforms
can reuse their buffers. Idle/rest are measured after one complete cycle.
Whole authoring/presentation call costs are also retained in the JSON.

The final isolated run uses **headroom 1.0**, and passes the binding limits:

- Highest motion clip median: **1.490ms** (limit 2.0ms).
- Highest motion submission: **2.394ms** (limit 3.0ms).
- Held idle/rest maximum after the first cycle: **0.163ms** (limit 0.5ms).
- Three interleaved rigs on move/reel/death: first-pass maxima **2.470ms front**,
  **2.209ms rear**; repeat maxima **0.122ms / 0.115ms**.
- Every front rig records **1,071 repeat mesh hits and 0 misses**; every rear
  rig records **1,020 hits and 0 misses**. Each view interleaves 51 poses for all
  three rigs, then repeats the complete sequence in the same interleaved order.

Measured stable-submission costs in milliseconds (original scalar path versus
final code, same preparation and source poses):

| View/clip | Before median | Before max | After median | After max |
|---|---:|---:|---:|---:|
| front/idle | 0.130 | 0.173 | 0.132 | 0.162 |
| front/move | 23.107 | 26.206 | 1.422 | 2.230 |
| front/reel | 17.026 | 26.120 | 1.283 | 2.356 |
| front/pin | 9.665 | 24.524 | 0.632 | 2.208 |
| front/press | 18.277 | 24.393 | 1.421 | 2.394 |
| front/guard | 15.631 | 24.615 | 0.092 | 2.364 |
| front/hit | 13.053 | 24.431 | 0.998 | 2.170 |
| front/death | 17.235 | 24.647 | 1.490 | 2.352 |
| front/rest | 0.129 | 0.139 | 0.129 | 0.163 |
| rear/idle | 0.125 | 0.155 | 0.127 | 0.138 |
| rear/move | 19.485 | 20.866 | 1.065 | 2.261 |
| rear/reel | 12.271 | 20.975 | 1.019 | 2.054 |
| rear/pin | 9.337 | 20.525 | 0.797 | 2.016 |
| rear/press | 13.454 | 20.933 | 1.146 | 2.158 |
| rear/guard | 1.891 | 20.830 | 0.089 | 2.059 |
| rear/hit | 4.750 | 20.851 | 0.433 | 2.093 |
| rear/death | 13.444 | 21.253 | 1.169 | 2.087 |
| rear/rest | 0.124 | 0.144 | 0.126 | 0.137 |

The focused/full timing test explicitly uses **headroom factor 2.0** for host
load: 4ms median / 6ms max motion and 1ms held. It preserves the raw binding
budgets in the report and independently requires every repeated mesh pose to
hit its cache. The isolated result above uses the unmodified binding limits.
Disabling the caches fails the required repeat-hit/no-thrash check. The frozen
legacy per-mesh dictionary/scalar path fails the measured time budgets. No
performance claim depends on that headroom factor or on presenting fewer poses.

## 2. Every submitted buffer remains identical

The sealed `fixtures/submission_2bd5ea39a/` contains the original scalar paint
and rig implementation, with relative preloads expanded to their original
absolute paths and the frozen adapter pointing at the frozen paint module.
`source_bindings.json` pins their original Git blobs. A 120-pose / 4,379-buffer
spot comparison against the actual unmodified 2bd5 runtime passed before the
implementation changed.

The golden corpus covers **8,364 poses / 304,685 Polygon2D buffers**, including
hidden paint: all 892 native/gate frames at the native origin, every presented
CPU frame, all 2,878 recorded production frames with their original root
reflection, screen scale and travel distance, the reviewer's 51 move phases in
both views, and **200 seeded random phases per clip per view**, including rest.
The seed is 4903. Each individual polygon buffer is SHA256-compared; nothing is
accepted through aggregate bounds or a pixel tolerance. A one-vertex mutation
changes an actual submitted polygon and fails that comparison.

The native prepared case and production runtime differ only in asset filenames:
114 part/mesh records and their PNG bytes, plus joints and idle groups, were
verified identical (`native_production_aliases.json`). Thus the corpus exercises
the same source vertices and quad sizes without requiring ignored capture
folders on a fresh checkout. The frozen corpus manifest SHA256 is
`de38d3fb2145f0a0b81d249f202bb25305d6218c96a5fe08818d250d932ce7e7`.

All **664 submissions across twelve other shared-runtime rigs** match the
frozen base: raw polygons, UVs, indices, skin weights, node/bone transforms,
visibility and modulation. The comparison uses raw typed buffers and explicit
text/length framing. Its first mixed-Variant serializer was rejected because
repeating the legacy baseline against itself changed 92 signatures; that was a
proof-harness defect, not a runtime exemption. No other rig source changed.

Only idle already uses `Pixels.phase_for`'s 10Hz loop grid. Non-loop action
phases remain continuous. **No baking or new time quantization was introduced.**

## 3. Reload

The inherited loader returns immediately for the same facing. `rig.gd` now
preserves `cap_bones` on that no-op path and clears it on the rebuild path.
Loading twice then applying move at phase **0.26** retains **5 helpers** and
identical submissions in both views. A real facing rebuild and return to the
original view also restores identical buffers. The frozen baseline reproduces
**0 helpers**, with **6 changed front meshes / 5 changed rear meshes**; that
regression is explicitly required to fail by the new test.

## Focused validation

```text
Ran 5 tests in 27.579s
OK
RR49 SUBMISSION COST: PASS (18 clip/views; 2 interleaved views; headroom=2.0)
RR49 COST MUTATIONS: PASS (disabled cache loses repeat hits; legacy per-mesh scalar path exceeds timing budget)
RR49 EXACT IDENTITY: PASS (8364 poses; 304685 polygon buffers; actual one-vertex mutation caught)
RR49 RELOAD: PASS (5 helpers; identical front/rear buffers; legacy double-load mutation caught)
Ran 5 tests in 49.252s
OK
Ran 7 tests in 3.981s
OK
```

The existing native regression includes 52/52 archived findings, 892 fresh
submissions, 100 idle frames and 1,184 root-transform checks. The seven
proof-dependency tests include mutations; both runtime dependency inventories
now include `stable_skin.gd`. The new Python module declares the `gaoler` shared
resource; its subprocess outputs are per-test temporary files. The parallel
resource audit checks 231 modules. The production-stage headless probe passes
88 geometry cases and 64 prepared cases / 4,864 checks / 0 errors / 0 orphans.
Its native mutation counts remain zero because no native image check can run
in this sandbox.

Both full suites ran once after the last implementation change, sequentially:

```text
MAIN BODY RUNTIME: 238.257 seconds
MAIN BODY ASSERTIONS: 495687
FULL SUITE RUNTIME: 715.174 seconds (budget 900 seconds)
TEST RESULT: FAIL (3 failure(s))

Ran 2147 tests in 1798.172s
OK (skipped=66)
```

The full Python coordinator exited **0** normally: 231 modules, 2,147 tests,
zero failures/errors, 66 skips. The new submission module also passed in the
full run (28.357s). The optional learning-cache write was denied by the expected
read-only Git metadata; it did not affect test results.

Full Godot exited **1**, with **227 passing child suites** and only the three
expected `GameData` compile failures at `enemy_no_action_suite.gd:36,128`:

| Failure | This worktree | Peer-benchmark snapshot |
|---|---|---|
| `enemy_no_action_test` | exit 124 after compile failure and its unchanged 180s deadline | PASS, 1,041 assertions |
| `fix_11_test` | exit 1, GameData compile failure | PASS, 162 checks |
| `fix_11_probe --check-only` | exit 1, GameData compile failure | PASS, 128 checks |

There were no other full-suite failures and no missing peer comparisons.
`failure_comparison.json`, `godot_programs.json`, `godot_failures/`, the original
Python shard results and `python_summary.json` preserve the exact evidence.

Final preservation locks cover **53,414 existing files**. The only changed
files in that inventory are the two intended runtime scripts and the owned
defaults record. Every other rig, protected paint/motion and both native
orientation-oracle scripts remain byte-identical. The director's incoming
`rr44/proof/sweep_summary.json` is byte-identical to the starting worktree.
All implementation/fixture locks survived both suites unchanged, no unexpected
status path appeared, and `git diff --check` passes. HEAD remains `2bd5ea39a`;
**39 owned files** are changed/new and remain uncommitted.

`proof/feedback3/results.json`, `preservation.json` and `changed_files.txt`
contain the complete handoff, commands, exact result lines and file inventory.

Focused commands (all engine subprocesses use the task runner):

```sh
python3 -m unittest discover -s tests -p test_rr49_submission.py -v
python3 -m unittest discover -s tests -p test_rr49_native.py -v
python3 -m unittest discover -s tests -p test_proof_runtime_paths.py -v
python3 tools/run_python_suite.py --shards 4 --audit-only --output-dir /private/tmp/labyrinth_codex/rr49-feedback3-audit
python3 tools/godot_task_runner.py --task-id rr-49 --stream -- godot --headless --path . --script tests/rr49/submission_cost.gd -- --output /private/tmp/labyrinth_codex/rr49-feedback3-cost-final.json
python3 tools/godot_task_runner.py --task-id rr-49 --stream -- godot --headless --path . --script tests/prepared_unit_canvas_equivalence_test.gd
```

Full-suite commands:

```sh
python3 tools/godot_task_runner.py --task-id rr-49 --timeout 1800 --stream -- godot --headless --path . --script tests/run_tests.gd
python3 tools/run_python_suite.py --shards 4 --output-dir /private/tmp/labyrinth_codex/rr49-feedback3-full-python
```

## Failure comparison with codex/peer-benchmark

A source snapshot of `codex/peer-benchmark` at
`ff77c892c1f6cc84b9aa6dcf6de694ed04cc7922` was extracted inside this unit's
ignored proof folder. It uses read-only links to that worktree's approved
assets and copies its existing class/UID cache; no import/editor scan ran and
no other worktree was written. Standard child bootstraps and the rr-49 task
runner exercised the three expected failure cases headless:

- `enemy_no_action_test`: exit 0, 23.341s.
- `fix_11_test`: exit 0, 15.407s.
- `fix_11_probe --check-only`: exit 0, 4.459s.

All five relevant helper/test/GameData files match this worktree byte for byte.
The peer cache declares GameData; this worktree has no such class-cache entry.
The known GameData compile failures are expected in the current worktree's full
suite, but **they do not fail on peer-benchmark with its existing cache**.
`peer_failures.json`, `peer_failure_bindings.json`, and `peer_runs/` retain the
commands and logs. No assertions or test setup values were rewritten to hide a
failure.

## Files, defaults and remaining proof

Runtime: `stable_paint.gd`, new `stable_skin.gd` plus its UID, and `rig.gd`.
Proof: new `tests/rr49/{submission_hashes,submission_cost,reload,other_submissions}.gd`
plus UIDs; `tests/test_rr49_submission.py`; the sealed baseline fixture; both
runtime-dependency inventories; Python resource registration; chosen defaults
and this report. An exact file inventory is saved with the final results.

Chosen internal defaults: per-mesh LRU capacity 128 (the inherited bound, now
isolated), random seed 4903, timing-test headroom 2.0, fixture runner timeout
120s, and the other-rig phases [0, 0.26, 0.5, 1]. The 200 random samples, 51
reviewer poses, 1/256 lattice and all timing targets come from the brief or the
existing code. No new player-facing values or TODO_DESIGN placeholders.

The director re-runs these windowed commands at final committed HEAD (existing
1920×1080 / UI scale 100% contracts):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-49 && LABYRINTH_TASK_ID=rr-49 sh experiments/cutouts/chainbound_gaoler/rr44_proof.sh native
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-49 && LABYRINTH_TASK_ID=rr-49 sh experiments/cutouts/chainbound_gaoler/rr44_proof.sh sheets
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-49 && LABYRINTH_TASK_ID=rr-49 sh experiments/cutouts/chainbound_gaoler/rr44_proof.sh production
```

Capture/report paths remain `rr44/proof/native/`, `contact_sheets/`,
`production_native/{front,rear}/`, `rr44_native_gates.json` and
`logs/sprite-geometry-result.json`. This round produced headless geometry/hashes
and timing records, with no new native captures. Fresh native, sheets and
production acceptance is the remaining director proof obligation.
