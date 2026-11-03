# rr-49 feedback 2 — production root-transform guard

Base: `bab5b0aff79d3ee5db77ad8c64a3b01c4f413805`. The director confirmed
native gates (0 errors), sheets (16 frames), density, rest, idle and review
(957 frames) at that commit. This round addresses only the surviving production
vertical-flip mutation. All implementation changes remain uncommitted.

## Root cause and correction

The mutation changes the rig root **after** pose sampling. `ExactSourcePaint`
quads are top-level children: their vertices already contain the bone pose, so
they intentionally bypass bone inheritance. However, their global transform
was copied from the rig only when sampling. A later flip inverted the ordinary
mesh caps but left the dominant rigid paint upright. The native image oracle
was reading the rendered texture correctly; the mutation had not flipped all
the submitted geometry. This also affected later root translations and changes
inherited from an ancestor. The existing orientation/placement predicates and
mutation transforms are unchanged.

`stable_paint.gd` now enables global-transform notifications only for opted-in
rigs. `rig.gd` forwards those notifications to `follow_root`, which copies the
root transform directly onto each existing top-level paint polygon. It never
changes source vertices, UVs, textures, pose timing or bone matrices. Direct
matrix copying preserves round 1's deterministic raster path without composing
inverse bone transforms. Other rigs do not enable these notifications and retain
their original paths. No art, motion, clamps or gate tolerances changed.

## Focused proof

`tests/rr44/root_transform.gd`, called by the existing registered
`tests/test_rr49_native.py`, exercises the real production renderer in all four
facings. It applies the exact production vertical-flip and off-tile mutations
without resampling, checks every submitted polygon's world transform and
byte-identical vertex buffer, restores the original submission, and tests
reparenting/ancestor movement. Disabling transform notification independently
recreates and rejects the original stale-quad defect in every facing.

Before the runtime correction: **192 stale-transform failures** — 16 quads in
each facing for each of flip, translation and ancestor movement. After it:

```text
Ran 5 tests in 57.792s
OK
RR49 SUBMITTED GEOMETRY: PASS (892 fresh frames; 100 idle frames; buffer, skin, texture, duplicate-transform and missing-policy mutations rejected)
RR49 ROOT TRANSFORM: {"checks":1184,"detached_mutation_quads":{"NE":16,"NW":16,"SE":16,"SW":16},"errors":[],"facings":4,"native":false,"quad_checks":256}
Ran 7 tests in 3.143s
OK
ISOLATION AUDIT: 230 modules
```

The seven proof-dependency checks include dependency-mutation rejection. The
new assertion lives in an existing Python module already registered with the
`gaoler` shared resource; no new Python module or dependency was added.

Commands and logs are recorded in `proof/feedback2/results.json`. Both full
suites completed after the final implementation change. Headless geometry
checks do not claim a native pixel pass.

The production-stage probe also completed through the task runner, headless:

```text
V2 BOARD SPRITE GEOMETRY: {"cases":88,"errors":[],"native":false,"orientation_mutations_rejected":0,"placement_mutations_rejected":0}
PREPARED UNIT CANVAS RESULT: {"cases":64,"checks":4864,"errors":[],"native":false,"orphans":0,"pixel_differences":[]}
```

Those zero native mutation counts indicate checks unavailable headless. The
separate root-transform regression above checks the actual submitted geometry
and rejects the stale-quad mutation in all four facings.

## Final full suites and preservation

```text
Ran 2142 tests in 1809.783s
OK (skipped=66)

MAIN BODY RUNTIME: 255.240 seconds
MAIN BODY ASSERTIONS: 495687
FULL SUITE RUNTIME: 698.312 seconds (budget 900 seconds)
TEST RESULT: FAIL (3 failure(s))
```

Full Python exited **0**, with all 230 planned modules and four completed
shards. This round has a normal coordinator result, with no recovered summary.
The optional timing-cache update was blocked by the expected read-only Git
metadata; it did not affect the suite result.

Full Godot exited **1**. Its three failures are the same existing
`enemy_no_action_test` (180s child timeout after compile failure), `fix_11_test`
and `fix_11_probe`: undeclared `GameData` in
`tests/suites/enemy_no_action_suite.gd:36,128`. The other **227 child suites
passed**. All four relevant helper/test files match both HEAD and the prior
failure hashes; `master_failure_bindings.json`, `godot_programs.json` and the
three copied `godot_failures/` logs preserve that evidence. No assertion or
deadline changed.

`preservation.json` verifies **53,413 locked existing files**: only the two
intended runtime files and the owned defaults record changed in that inventory.
Every other rig's files, the protected paint/motion, both native orientation
oracle scripts, and every director incoming change remain byte-identical to
the starting worktree. The six implementation/data locks also survived both
full suites unchanged. There are no unexpected status paths; `git diff --check`
passes. HEAD remains `bab5b0aff`; the seven files for this round are uncommitted.

Focused commands:

```sh
python3 -m unittest discover -s tests -p test_rr49_native.py -v
python3 -m unittest discover -s tests -p test_proof_runtime_paths.py -v
python3 tools/run_python_suite.py --shards 4 --audit-only --output-dir /private/tmp/labyrinth_codex/rr49-feedback2-audit
python3 tools/godot_task_runner.py --task-id rr-49 --stream -- godot --headless --path . --script tests/prepared_unit_canvas_equivalence_test.gd
```

Full-suite commands:

```sh
python3 tools/godot_task_runner.py --task-id rr-49 --timeout 1800 --stream -- godot --headless --path . --script tests/run_tests.gd
python3 tools/run_python_suite.py --shards 4 --output-dir /private/tmp/labyrinth_codex/rr49-feedback2-full-python
```

Logs, original shard result records, the Python summary, failing Godot children,
the preserved director failure and the before-fix regression are all under
`proof/feedback2/`. No new renderer captures were produced.

## Files changed in this round

- `scripts/maquette_cutout_runtime/{rig,stable_paint}.gd`: optional root following.
- `tests/rr44/root_transform.gd` and its Godot-generated `.uid`:
  source-preserving transform regression.
- `tests/test_rr49_native.py`: execute that regression in the focused/full suite.
- `rr49/chosen_defaults.json` and this record: chosen internal fixture value and
  rationale/proof.

The director's pre-existing regenerated proof, density, rest and shadow-cache
changes are preserved. `proof/feedback2/initial_status.txt` records the starting
dirty state; `initial_hashes.json` locks 53,413 existing files for preservation.

No `TODO_DESIGN_*` placeholders. Chosen default: debug-only
`ANCESTOR_TRANSLATION = Vector2(7, 11)`; the flip, source size, facings, phase and
settle-frame count reuse the production probe's existing values.

## Proof for the design owner

No windowed command was attempted. The production contract remains
1920×1080, 100% UI scale. Run:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-49 && LABYRINTH_TASK_ID=rr-49 sh experiments/cutouts/chainbound_gaoler/rr44_proof.sh production
```

Outputs remain under `rr44/proof/production_native/{front,rear}/` and
`rr44/proof/logs/sprite-geometry-result.json`; the probe also writes its images
and `prepared_sprite_geometry/geometry.json` under the runner's isolated
`user://`. Expected native guard counts: **44 orientation** and **44 placement**
mutation rejections, **88 geometry cases**, and **64 prepared canvas cases**,
with zero errors. There is no inspection-fixture command in this feedback.

Open issues: the director must confirm the windowed production image guards at
the final committed HEAD; the three pre-existing full-Godot failures remain.
