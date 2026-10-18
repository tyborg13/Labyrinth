# bug-01 feedback 6 — moss opacity invalidation

Based on owner-merged integration HEAD `6e9791666`; all changes remain
uncommitted. No quarantine, registration, task queue, Git lifecycle or peer
review action was performed. The owner's re-review and exact repro were read.

## Requirements and implementation

1. Moss is a separate obstruction candidate for both pillars and outer walls.
   `board_prop_moss_geometry.gd` now resolves its texture, rectangle and actual
   drawing tile id. Both `_draw_prop_moss_overlay()` and candidate collection
   consume that resolver. The original texture selection, wall orientation,
   horizontal flip and rectangle formulas are preserved. Candidate snapshots now
   include moss input. Existing body candidates and effective old/new alpha
   comparison are unchanged, including unchanged actors and objects.

   Tint-input audit: pillar bodies and torch fixtures use the same
   `_prop_draw_rect(pillar_texture, _prop_rect_for_tile(tile))` rectangle. Torch
   lights and embers inherit that tint with the existing torch alpha floor;
   neither evaluates obstruction against its smaller flame/fixture rectangle.
   Therefore body candidates already cover those overlays. Wall body segments
   use `_boundary_prop_segments()` in drawing and candidates. Door openings and
   icons inherit the door body's tint, also already covered. Moss has its own
   tint rectangle and is now covered independently, using `pillar` or `wall`
   exactly as drawing does. No authored alpha, visual timing, asset, input,
   analytics, save or gameplay value changed.

   Player impact: adding the brazier could leave pillar moss opaque over the
   new prop despite the correct stone-body transparency; removing it could
   leave the moss faded until a later redraw. This is the regression introduced
   by the body-only candidate comparison in feedback-5 commit `561e9ee4f`,
   present at the reviewed HEAD. The original selective-prop-redraw defect and
   its historical root commit remain recorded in `bug_01_findings.md`.

2. The real-board regression uses the review's moss pillar (6,6), hero (6,5),
   brazier (5,5), width 0.60 and baseline 0.36. It verifies a real moss texture,
   unchanged actor-obstructed body alpha on onset/removal, moss changing from
   white to the existing object-obstruction alpha and back, and a queued pillar
   on both changes. It also rejects queuing the unaffected pillar and verifies
   no full dynamic redraw occurred. Independent fixtures preserve the numbered
   native cases and their retained histories. Existing positive and negative
   assertions remain intact.

3. The new checks failed before production changes, passed with the shared moss
   candidates, then failed when only `candidates.append(moss)` was replaced by a
   no-op. Drawing still used its real moss geometry during that mutation. The
   coordinator restored the original source in `finally` and checked its bytes.

## Focused reproduction and mutation

Before fix: qa-07 runner and child exit **1**, no timeout or script errors,
`qa-07-floor-feedback-6-before.json`, 12.858 s. Exactly two failures:

```text
Scene prop onset must redraw a pillar whose moss alpha changes
Scene prop removal must redraw a pillar whose moss alpha changes
```

Fixed: runner/child exit **0**, `qa-07-floor-feedback-6-fixed.json`, 13.688 s.
Mutation: runner/child exit **1**, `qa-07-floor-feedback-6-mutation.json`,
11.757 s; the same two failures only, zero orphans, no script errors or timeout:

```text
STATIC FLOOR CACHE RESULT: {"cases":106,"checks":163253,"errors":["Scene prop onset must redraw a pillar whose moss alpha changes","Scene prop removal must redraw a pillar whose moss alpha changes"],"native":false,"orphans":0,"pixel_differences":[]}
```

Restored `combat_board_view.gd` SHA-256:
`bb7eb7124539fb8500594dd6d158b1d2ffc6418847a8774440e6bda1ba3bbb02`.
Logs/results are under `output/bug-01/`; each JSON points to its complete child
and engine logs.

## Verification

All four focused programs passed, qa-07 runner/children exit **0**, no timeouts:
`output/bug-01/qa-07-feedback-6.json`, `complete: true`, `failed: false`, 71.639 s.
The existing sliced preparation checks use real 4 ms boundaries, so their
observed case/check counts legitimately vary between runs. Exact result lines:

```text
PREPARED OTHER CHARACTER VIEW RESULT: {"boundaries":{"equipment":14,"magic":30},"cancellation_boundaries":13,"cases":46,"checks":1051,"differences":0,"errors":[],"orphans":0}
CHARACTER RETENTION RESULT: {"cases":117,"differences":0,"errors":[],"orphan_nodes":0,"preparation_frames":3732}
SHOP RETAINED CONTENT TEST RESULT: PASS
STATIC FLOOR CACHE RESULT: {"cases":106,"checks":163253,"errors":[],"native":false,"orphans":0,"pixel_differences":[]}
```

Dump-enabled headless floor after mutation restoration: runner/child exit **0**,
`qa-07-floor-feedback-6-final.json`, 12.195 s:

```text
BUG_01 DIFF DUMP: native captures unavailable headlessly; diagnostic fixture checks only
BUG_01 CAPTURE END_TO_END SMOKE: PASS (ClockedBoard + ClockedReference; GPU readback/fences mocked)
BUG_01 DIFF DUMP CHECKS: PASS (strict RGBA metrics, masks, crops, JSON, fresh fixture, isolated mutation)
RESTORED EMPTY BOARD LOGIC: PASS (native pixel proof requires window server)
STATIC FLOOR CACHE RESULT: {"cases":106,"checks":163253,"errors":[],"native":false,"orphans":0,"pixel_differences":[]}
```

UI identity lint: exit **0**, `Ran 25 tests in 3.469s` / `OK`,
`ui-identity-feedback-6.log`. Prescribed sound-lab environment: exit **0**,
`Ran 39 tests in 27.366s` / `OK`, `python-sfx-feedback-6.log`.

Full Godot: task runner exit **0**, `output/bug-01/godot-full-feedback-6.log`.
All 34 parallel programs passed, along with the main body. Exact summary:

```text
Section map fast performance: PASS (21 seeds x 6 sections; max section 180.464ms; max run 310.641ms; fallback 0)
MAIN BODY RUNTIME: 239.236 seconds
MAIN BODY ASSERTIONS: 385082
FULL SUITE RUNTIME: 331.208 seconds (budget 900 seconds)
TEST RESULT: PASS
```

Existing ObjectDB leak warnings, deliberate save-failure/migration fixture
messages and the sandbox macOS certificate error remain in the log; no script
errors or failing program summaries were reported. Focused bug-01 programs
report zero orphans.

Full Python discovery ran after Godot completed: exit **0**,
`output/bug-01/python-feedback-6.log`:

```text
Ran 702 tests in 702.598s
OK (skipped=63)
```

The existing skips cover optional audio/Blender environments; the prescribed
sound-lab environment was checked separately above. No dependencies were added.
Godot and Python ran sequentially, so Python headless fixtures did not add load
to Godot's wall-time map benchmark. Existing asset numeric warnings remain in
the Python log.

Final hygiene: `OUTPUT GDIGNORE: PASS (14 folders; 3 referenced roots)`;
`git diff --check` passed. Restored source hash matches the pre-mutation hash,
no new typed-array initializers were introduced, and quarantine, program
registrations and parallel scheduler are unchanged.

Headless commands (all executed from this worktree):

```sh
python3 tools/program_suite_runner.py --task-id bug-01 --result-file output/bug-01/qa-07-feedback-6.json --suite prepared_other_character_view_test --suite retained_character_inventory_equivalence_test --suite shop_retained_content_test --suite static_floor_cache_equivalence_test
LABYRINTH_BUG_01_DIFF_DUMP=1 python3 tools/program_suite_runner.py --task-id bug-01 --result-file output/bug-01/qa-07-floor-feedback-6-final.json --suite static_floor_cache_equivalence_test
python3 tools/godot_task_runner.py --task-id bug-01 --timeout 900 --stream -- godot --headless --path . --script tests/run_tests.gd
python3 -m unittest discover -s tests -p 'test_*.py' -v
/Users/borgerding/.cache/umbra-sfx/venv/bin/python -m unittest discover -s tests -p 'test_sfx_lab.py' -v
python3 tests/test_ui_identity_lint.py
python3 tools/output_gdignore.py
```

## Proof for the design owner

No native/windowed run was attempted: this sandbox has no window-server access.
Strict pixel equality, actor inclusion, dump metrics and the isolated magenta
floor-pixel mutation are unchanged. The execution cap is the runner's actual
CLI **`--timeout 600`**, not a GDScript constant. Native commands:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/bug-01 && LABYRINTH_BUG_01_DIFF_DUMP=1 python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy --attempts 1 --timeout 600 tests/static_floor_cache_equivalence_test.gd --task-id bug-01 --expect-size 1920x1080 --proof-contract tests/proof_contracts/bug_01_floor_restore.json --result-manifest output/bug-01/floor-native-feedback-6.manifest.json
cd /Users/borgerding/workspace/Labyrinth.worktrees/bug-01 && LABYRINTH_BUG_01_MUTATE_FLOOR=1 python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy --attempts 1 --timeout 600 tests/static_floor_cache_equivalence_test.gd --task-id bug-01 --expect-size 1920x1080 --proof-contract tests/proof_contracts/bug_01_floor_restore.json --result-manifest output/bug-01/floor-mutation-feedback-6.manifest.json
```

The proof prints absolute `user://bug_01_diff/` report/image paths and writes
`bug_01_floor_{restored,fresh,reference,mutated}.png` in its task-local user root;
the manifests identify captured output. The intentional mutation must exit 1
with the distinct `BUG_01_DELIBERATE_FLOOR_PIXEL_MUTATION` error for its single
pixel; it is separate from the temporary moss-candidate source mutation above.

## Files / TODO_DESIGN / chosen defaults / open issues

- `scripts/board_prop_moss_geometry.gd`: shared pillar/wall overlay geometry.
- `scripts/combat_board_view.gd`: consume it for drawing and candidate collection.
- `tests/fixtures/static_floor_scene_prop_checks.gd`: moss onset/removal regression.
- `tests/static_floor_cache_equivalence_test.gd`: wire the independent fixture.
- `tests/bug_01_findings.md`, this handoff: current implementation/proof record.
- `output/bug-01/feedback-6-contract.md` and observed local logs/results.

No `TODO_DESIGN` placeholders or new production defaults. Test-only named fields
`MOSS_HERO_TILE` and `MOSS_BRAZIER_TILE` use the owner's exact repro; all other
fixture values reuse existing fields. Expected alpha comes from production
constants rather than a parallel numeric rule. No new typed arrays are needed.
Native renderer verification remains with the design owner.
