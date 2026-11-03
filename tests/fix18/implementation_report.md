# fix-18 implementation and proof

Historical initial handoff for `ebcb74843`. The current feedback-1 changes,
results and replacement native commands are in [feedback1_report.md](feedback1_report.md).

Worktree `codex/fix-18`; base `d1da1c19ad3c17ecf2380d341795ae3eb250cd9d`.
Changes remain uncommitted. No review, publication, queue edit or windowed run
is part of this worker handoff.

## 1. Root cause and affected paths

The first bad write is **not** a pre-battle canvas transform. The board's
initial, empty-state cached layout has origin `(960, 540)` at 1920×1080.
On the first resumed combat submission, `set_combat_state` assigns the new
combat/presentation, then calls `MaquettePresentation.sync` at baseline
`scripts/combat_board_view.gd:2978`. The layout signature is still empty and
the old geometry is still valid. Baseline
`scripts/maquette_cutout_runtime/presentation.gd:73` calls
`pixel_presentation.gd:69–80` (`align_on_board`). Its `_unit_center` read
returns `(1143.999, 815.999)` for tile `(4,2)` and `(776.0007, 999.9982)` for
tile `(4,6)`. It writes the rounded correction into `unit_texture_origins`
at line 77 and `unit_world_positions` at line 80, mutating the caller's
presentation snapshot. Later actors see those already inserted entries.

Only **after** roster sync does baseline `combat_board_view.gd:3057`
invalidate/rebuild the board layout. The retained layers receive correct
floor geometry **and** the stale absolute overrides. `_unit_center` at
baseline line 15656 and `_unit_texture_draw_rect` at line 15624 prefer these
overrides indefinitely. The draw dictionary and layer transform are correct;
the overrides bypass their current geometry. Resize invalidates layout but
does not clear/rederive the overrides. Subsequent rig sync can also read its
own previous override, so merely moving sync later is insufficient.

The hero and dedicated old-style cutouts do not call `align_on_board`.
Their idle centre continues to resolve from the tile. Authored animation
overrides are a separate, intentional path and remain supported.

Observed baseline trace: `/private/tmp/fix18-origin-trace.log` (temporary
instrumentation was restored before implementing). The trace includes the
actual Continue → initial preparation → stage refresh stack, cached origin,
empty layout signature and incoming overrides. The supplied five full frames
and two Mirror crops were inspected, including resize/restore and natural
spawn evidence. The resize log's `REAL FIGHT RESIZE FOOTING` agrees with the
trace.

The hash-bound stale-source negative control also observes fresh Begin,
Warband and Snare, recording affected types separately for each stage:

| Entry/path on baseline sources | Observed at settled rest |
| --- | --- |
| Saved-combat Continue | All four requested rigs off tile; hero correct |
| Fresh pre-battle → Begin | No containment failure in the visible rigs |
| Inspection `--launch` → Continue | Same saved-combat Continue path; affected |
| Warband fixture → Continue | All four requested rig types off tile |
| Snare fixture → Continue | All four requested rig types off tile |
| Resize and restore of resumed combat | All four remain off tile |
| No-animation state move in resumed combat | All four remain off tile |

The fresh Begin case replaces presentation snapshots during opening-hand
processing and settles without the stale overrides; do not describe that path
as a reproduced persistent offset. No-animation movement
uses a direct state submission, covering the common post-resolution route for
push, pull, Blink, Upheaval throw and wind; it does not play those animations.
Inspection `--launch` creates/verifies a save and opens MainMenu; its Continue
transition is the same production path exercised here.

## 2. Fix at the cause

Pixel snapping is now derived geometry at use time. `PixelPresentation`
provides `board_center` and `board_rect`; the board's own centre/texture-rect
helpers use them only for registered maquette actors. They read the current
tile or authored travel override and the existing resolved layout cache.
Roster sync no longer bakes screen coordinates into caller presentation.

Existing layout/viewport invalidation, tile layers, submission-unit caches,
shadow caches and their selective routing remain intact. Tests check tile
layer identity across a state-only move and a changed layout. The same
subpixel correction still applies to body/HUD/shadow registration, and padded
texture origins still snap to integer pixels. Authored root travel keeps its
separate texture origin and body position; no rig, asset, motion, number,
wording, analytics or save data changed.

## 3. Regression and failing-before proof

`real_fight_capture_probe.gd` is copied **unchanged** from
`codex/pt14-03` (`b110566f4cc4ae3a046aa0647973e3572382b0f3`) under the
test-only path `tests/fix18/real_fight_capture_probe.gd`.
SHA-256: `a58d875e4a11ba5ee2822c35fbc1195e984355f364628070e05dba90942e6b8b`.
Its two owner proof contracts are copied unchanged too.

`draw_origin_test.gd` inherits that exact save/MainMenu/Continue reproduction.
It reads the renderer's own retained draw unit, `_unit_center` and
`_unit_texture_draw_rect`, removes only transparent canvas padding, and tests
floor-centre containment in the resulting rest rectangle. Seer, Mirror,
Gaoler, Lancer and hero are checked after Continue, real viewport resize,
restore, no-animation position changes and a changed board fit rectangle.
Additional checks preserve retained tile layers and immutable authored travel.

`stale_path.json` pins the committed base's two runtime sources and original
board draw/centre functions, with independent SHA-256 values. The Python
negative control restores these sources only in a temporary script copy;
other project inputs are read-only links or committed actor snapshots. It must observe all four distinct
Continue containment failures, with no script errors. No production source is
temporarily mutated. Its entry-path observations distinguish settled fresh
Begin from a saved-combat Continue.

`entry_paths_test.gd` uses production fixture builders and MainMenu Continue.
The fresh case presses the real pre-battle Begin handler with a test-only
prepared four-rig roster. Hidden actors remain hidden; its rectangle assertions
cover the visible actors. Warband/Snare retain their production startup and
visibility rules. Test registration and Python shared-resource declarations
include these new checks. The Python module only writes temporary directories
and runner HOME. It stages the current runtime and reads the four protected
actor families from Git objects into that temporary project, so other suites'
temporary production-asset mutations cannot affect its reads. Its audited
resource declaration is therefore `[]`; it does not join unrelated resource
groups or serialize the existing four-shard suite.

## 4. Preservation and verification

Observed focused results:

- `/private/tmp/fix18-before.log`: `FIX18 DRAW ORIGIN: FAIL (20 actor checks; 17 failures)` on unchanged baseline runtime, with all four rig types failing and hero passing.
- `/private/tmp/fix18-final-regression.log`: `Ran 3 tests in 52.203s`; `OK`; `FIX18 STALE SOURCE MUTATION: PASS (all four Continue floor-containment failures observed)`. The final full suites also exercise the subsequently named test constants with identical values.
- `/private/tmp/fix18-final-focused.log`: `FIX18 DRAW ORIGIN: PASS (25 actor checks; 0 failures)`; `REAL FIGHT CAPTURE VALIDATION: PASS`. Continue manifest: `/private/tmp/fix18-final-focused/four-rigs.json`.
- `/private/tmp/fix18-pre-battle-complete.log`: `FIX18 DRAW ORIGIN: PASS (20 actor checks; 0 failures)`.
- `/private/tmp/fix18-warband-final.log`: `FIX18 DRAW ORIGIN: PASS (45 actor checks; 0 failures)`.
- `/private/tmp/fix18-snare-final.log`: `FIX18 DRAW ORIGIN: PASS (25 actor checks; 0 failures)`.
- `/private/tmp/fix18-maquette.log`: `MAQUETTE CUTOUT: PASS (40178 checks, 0 failures; headless logic only)` (old shared Bloomer/Wisp paths, snapping and portraits).
- `/private/tmp/fix18-rr40.log`: `V2 BOARD SPRITE GEOMETRY: {"cases":88,"errors":[],"native":false,"orientation_mutations_rejected":0,"placement_mutations_rejected":0}`; `PREPARED UNIT CANVAS RESULT: {"cases":64,"checks":4864,"errors":[],"native":false,"orphans":0,"pixel_differences":[]}`. Native mutation counts are zero because no native renderer was run.
- `/private/tmp/fix18-references.log`: `Ran 184 tests in 522.807s`; `OK`. This is the existing rr-40 reference set: native storage/crop-plan checks and rr10/12/17/20/21/22/29/32/35/37/40, including protected source, production contacts, portraits and live actor paths. Its production checks report `MAQUETTE PRODUCTION LOGIC: PASS (1634 frames)` twice.
- `/private/tmp/fix18-postimport-registration.log`: `TEST REGISTRATION AUDIT: PASS (869 scripts; full suite=508, quarantined=29, windowed probe=332)`.
- `/private/tmp/fix18-isolated-audit.log`: `ISOLATION AUDIT: 225 modules; /private/tmp/fix18-isolated-audit/isolation-audit.md` (four-shard plan; new module only writes isolated outputs).

All successful commands above exited 0. Initial entry-test attempts exposed
test setup mistakes (direct RunScene boot does not request saved-run Continue;
saved pre-battle layouts are regenerated; hidden actors are not drawn). The
test setup was corrected without changing production behavior or weakening
the four-visible-actor Continue gate. Native pixel checks remain the owner's work.

Complete full Godot run (exit 0), `/private/tmp/fix18-godot-full-final.log`:

```text
MAIN BODY RUNTIME: 335.725 seconds
MAIN BODY ASSERTIONS: 495687
FULL SUITE RUNTIME: 799.189 seconds (budget 900 seconds)
TEST RESULT: PASS
```

The program report is complete: all 232 programs passed, zero script/parse
error markers. Both new registered programs pass (`25` Continue actor checks;
`20` fresh-entry actor checks). Existing deliberate save-failure and shutdown
ObjectDB/RID diagnostics remain in the verbose log; they did not fail assertions.
The sidecar import completed with exit 0 (`/private/tmp/fix18-import.log`);
it produced only the three new script UID files in this unit's folder.
Assets and authoring cases remain byte-unchanged.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fix-18 && python3 tools/godot_task_runner.py --task-id fix-18 --timeout 900 --stream -- godot --headless --path . --script tests/run_tests.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/fix-18 && python3 tools/run_python_suite.py --shards 4 --output-dir /private/tmp/fix18-python-full-final
```

The first full Python attempt exposed one implementation integration omission:
the independent ordered-manifest fixture did not yet include the two appended
fix-18 programs. The committed baseline manifest was checked in memory and
reported `FIX18 BASELINE MANIFEST GUARD: PASS (committed manifest; fix18 programs excluded)`.
Only the two expected data entries were added to
`tests/test_program_suite_runner.py`; no existing assertion was changed.
Focused guard verification (`/private/tmp/fix18-manifest-guard-final.log`)
reports `Ran 28 tests in 37.661s`, `OK`, and rejects all 180 supplemental
mode changes. A complete Python rerun follows the first attempt.

That first attempt completed `Ran 2101 tests in 2323.551s` and
`FAILED (failures=3, skipped=66)`. The other two failures were:

- `test_sb02_movement.Movement.test_incremental_submission`: the existing
  4000 µs maximum-planning assertion observed 5153 µs under four-shard load.
  No assertion or threshold was changed. The quiet focused rerun reports
  `Ran 1 test in 11.498s`, `OK` (`/private/tmp/fix18-movement-quiet.log`);
  the same movement workload also passed in the full Godot run.
- `test_rr41_feedback3.WalkingTests.test_rest_and_density_evidence_reseal_to_identical_bytes`:
  fresh rest pixels and poses were unchanged, but the pose report includes
  SHA-256 bindings for the two changed runtime sources. A pristine committed
  runtime/source snapshot reproduced the exact original pose hash
  `227fdfcb48c690d122f3d04ea2cacef44e15432375af89f304f94ffb893ac6c4`
  (`/private/tmp/fix18-rest-baseline.log`). Current pose JSON, after replacing
  only those two source hashes with their pinned originals, recovers that
  same complete byte hash. Every other input, pose, scale and serialized byte
  is identical. `rest_provenance.py` now permits only that explicit pinned
  provenance delta; canonical art, rest reports and density evidence stay
  untouched. The original exact-byte and evidence assertions remain in place
  after this narrow normalization. Mutated rest data, bad bindings and added
  unapproved inputs are rejected. Focused proof reports `Ran 2 tests in
  19.352s`, `OK` (`/private/tmp/fix18-rest-provenance-final.log`); the added
  unknown-input negative control also reports `Ran 1 test in 0.001s`, `OK`.

The final Python rerun uses the documented `LABYRINTH_SWEEP_WORKERS=4` cap
alongside four suite shards to reduce CPU contention. The per-shard deadline
is 3600 seconds: the first attempt took 2323.551 seconds with eight sweep
workers, already close to the default 2400-second cap. This changes neither
cases nor assertion thresholds; engine launches retain their own deadlines.
The final full Godot round is repeated after these test integration fixes.

Post-integration full Godot attempt, `/private/tmp/fix18-godot-final-round.log`:
the main body completed `495687` assertions in `402.794` seconds, but the
outer 900-second deadline expired (exit 124). The program report records one
assertion failure, `main_menu_input_test`: `A short intentional gap must
separate the tracks`; 36 subsequent/running programs were marked `parent
interrupted`, rather than assertion failures. The other completed children
passed. The same unchanged menu/music test passed in the earlier complete
232-program run and then passed alone (exit 0),
`TEST RESULT: PASS — main menu input and startup transitions`
(`/private/tmp/fix18-menu-quiet.log`). No menu/audio code, assertion or Godot
budget was altered. This timed-out attempt is not reported as a full pass;
the complete 799.189-second run above remains the observed full Godot pass
on the identical runtime/GDScript/manifest sources.

The final Python command is:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fix-18 && LABYRINTH_SWEEP_WORKERS=4 python3 tools/run_python_suite.py --shards 4 --shard-timeout 3600 --output-dir /private/tmp/fix18-python-final-round
```

Final Python result (exit 0), `/private/tmp/fix18-python-final-round.log`:

```text
Ran 2102 tests in 1680.856s
OK (skipped=66)
PYTHON SUITE WALL: 1680.856s; results: /private/tmp/fix18-python-final-round
```

All 225 modules completed, with zero failures/errors. The new four-test
fix-18 module, all 28 ordered-manifest guards, the rest/density byte seal,
the unchanged 4000 µs movement limit and the UI/sidecar identity checks pass
in this complete run. The 66 existing optional/environment skips retain
their reasons in the combined log and `summary.json`. The optional timing
cache again reported the same sandbox denial, with temporary basename
`tmpglczfaxp`; it did not affect test results.

Final repository checks: `git diff --check` exits 0; `git diff --quiet HEAD
-- assets experiments spec/assets` exits 0. The copied probe still has its
original SHA-256. Branch/HEAD remain `codex/fix-18` /
`d1da1c19ad3c17ecf2380d341795ae3eb250cd9d`; every change is uncommitted.

Open proof issues: the requested native captures still need the owner's
window server. The later Godot attempt's music-gap assertion/deadline remain
reported above despite the earlier complete full pass and passing isolated
menu rerun. This worker has not changed those tests or budgets, requested
sign-off, run peer review, committed, pushed, merged or edited the queue.

The required Python runner's optional learned timing-cache write is outside
this sandbox. Its exact nonfatal diagnostic was:

```text
Cannot update untracked timing cache /Users/borgerding/workspace/Labyrinth/.git/labyrinth-test-timings/python-suite.json: [Errno 1] Operation not permitted: '/Users/borgerding/workspace/Labyrinth/.git/labyrinth-test-timings/tmpa6hz3ot0'
```

No alternate Git metadata or permission workaround was used. Test reports and
module durations are retained under the explicit `/private/tmp/` output directory.

Changed files:

- `scripts/combat_board_view.gd`: maquette-only live centre and padded draw-rect alignment.
- `scripts/maquette_cutout_runtime/pixel_presentation.gd`, `presentation.gd`: pure geometry helpers; remove roster-time absolute writes.
- `tests/fix18/`: unchanged owner probe/contracts, regression, entry-path checks, pinned stale-source mutation fixture, narrow rest-provenance fixture/helper, script UID sidecars and this report.
- `tests/test_fix18_draw_origin.py`: isolated fixed/stale runtime checks and copied-probe hash guard.
- `tests/test_program_suite_runner.py`: extend the independent ordered manifest fixture with the two new programs; preserve all assertions.
- `tests/test_rr41_feedback3.py`: adapt only the two pinned board-origin source bindings before the existing exact rest-byte comparison; preserve canonical evidence checks.
- `tests/headless_test_programs.json`, `tests/windowed_test_allowlist.json`, `tools/python_suite_resources.json`: required execution/resource registration.

## Proof for the design owner

No windowed command was attempted: this worker has no macOS window-server
access. These are the requested pt14-03 root-window probes at 1920×1080 and
100% UI scale, using the unchanged test copy. Use fresh output directories;
the probe refuses to overwrite evidence.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fix-18 && LABYRINTH_REAL_FIGHT_CAPTURE_OUTPUT=/private/tmp/fix18-native/mirror-separated python3 tools/visual_probe_runner.py --task-id fix-18 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --min-images 1 --proof-contract tests/fix18/real_fight_capture_probe_contract.json --result-manifest /private/tmp/fix18-native/mirror-separated/runner.json tests/fix18/real_fight_capture_probe.gd -- --label mirror-separated --player-position 4:4 --biome iskaldra --seed 7262026 --enemy-types glacial_mirror,glacial_mirror --enemy-positions 4:2,4:6 --crop enemy_1:3 --crop enemy_2:3

cd /Users/borgerding/workspace/Labyrinth.worktrees/fix-18 && LABYRINTH_REAL_FIGHT_CAPTURE_OUTPUT=/private/tmp/fix18-native/seer-separated python3 tools/visual_probe_runner.py --task-id fix-18 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --min-images 1 --proof-contract tests/fix18/real_fight_capture_probe_contract.json --result-manifest /private/tmp/fix18-native/seer-separated/runner.json tests/fix18/real_fight_capture_probe.gd -- --label seer-separated --player-position 4:4 --biome iskaldra --seed 7262026 --enemy-types hoarfrost_seer,hoarfrost_seer --enemy-positions 4:2,4:6 --crop enemy_1:3 --crop enemy_2:3

cd /Users/borgerding/workspace/Labyrinth.worktrees/fix-18 && LABYRINTH_REAL_FIGHT_CAPTURE_OUTPUT=/private/tmp/fix18-native/seer-natural python3 tools/visual_probe_runner.py --task-id fix-18 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --min-images 1 --proof-contract tests/fix18/real_fight_capture_probe_contract.json --result-manifest /private/tmp/fix18-native/seer-natural/runner.json tests/fix18/real_fight_capture_probe.gd -- --label seer-natural --biome iskaldra --seed 7262026 --enemy-types hoarfrost_seer,hoarfrost_seer

cd /Users/borgerding/workspace/Labyrinth.worktrees/fix-18 && LABYRINTH_REAL_FIGHT_CAPTURE_OUTPUT=/private/tmp/fix18-native/seer-separated-resize-diagnostic python3 tools/visual_probe_runner.py --task-id fix-18 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --min-images 3 --proof-contract tests/fix18/resize_contract.json --result-manifest /private/tmp/fix18-native/seer-separated-resize-diagnostic/runner.json tests/fix18/real_fight_capture_probe.gd -- --label seer-separated-resize-diagnostic --player-position 4:4 --biome iskaldra --seed 7262026 --enemy-types hoarfrost_seer,hoarfrost_seer --enemy-positions 4:2,4:6 --resize-diagnostic
```

The first two commands also save 3× actor crops. Every command saves its
`<label>.json`; resize additionally saves `_resized.png` (1600×900) and
`_restored.png` (1920×1080). The resize diagnostic is report-only by the
unchanged probe's design: inspect its per-stage actor records and pixels.
The probe itself builds, saves and Continues the isolated production fixture.
For a separate interactive check of the wrapper's `--launch` route, run this
and press Continue in the main menu:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fix-18 && python3 tools/inspection_fixture.py --task-id fix-18 --run-id fix18-inspection --scenario combat --seed 7262026 --enemy-types hoarfrost_seer,hoarfrost_seer --player-position 4:4 --enemy-positions 4:2,4:6 --biome iskaldra --launch
```

Committing, review, playable inspection handoff and publication remain assigned
to the owner.

## TODO_DESIGN placeholders

None.

## Chosen defaults

Test-only: 1600×900 regression resize and eight settle frames reuse the probe's
diagnostic values; fit rectangle `(200,150,1300,600)`; synthetic travel offset
`(12.25,6.5)`; one-pixel maximum correction assertion; rotating existing legal
enemy tiles for a no-animation move; 30-second entry deadline; test labels,
temporary output paths and hash-fixture schema. The fresh test's prepared
roster uses the four brief-named actors and the existing fixture builder.
No player-visible defaults were chosen.

Final-suite execution defaults: four sweep workers within the four Python
shards and a 3600-second shard deadline for the observed large CPU sweeps.
The provenance mutation fixture uses a boolean rest sample, a zero SHA-256
sentinel and an unapproved synthetic input name; none is production data.
