# bug-01 — implementation and proof handoff

All four reproduced failures were stale test inputs/references. No production
behavior, player-visible values, assets, analytics, or save format changed.
Existing assertions remain, including complete authoritative-state equality.
Changes are uncommitted on `codex/bug-01`, HEAD `060e3e7dc`.

## Root-cause table

| Test | Verdict | Player impact | Root-cause commit | Fix | Regression / proof |
| --- | --- | --- | --- | --- | --- |
| `prepared_other_character_view_test.gd` | Stale fixture | None demonstrated. Reversing the migrated empty reserve changes nothing. | `5b766ff7e` (deck-01; integrated by `3f8a19b15`). Timing-dependent boundary counting dates to `809d5b9ce`. | Reverse the active deck and assert that the input key really changes. Stop cancellation enumeration at an actually absent boundary, assert uninterrupted completion and fail on safety-limit exhaustion. Trigger owner termination when both future columns are attached and assert it occurred. | Existing input-capture/cancellation/ownership assertions; new source-mutation, scan-completion and complete-column termination preconditions. |
| `retained_character_inventory_equivalence_test.gd` | Stale time input | None demonstrated. Opening an unread tab legitimately commits elapsed run time; the two scenes sample different wall times. | `13ffa4a8a` (fix-02; integrated by `0d54a5970`). | Freeze the external clock before either scene is ready. Keep real sampling/commit/save logic and the entire dictionary comparison. | Existing `Presentation must not mutate authoritative state` and `Boundary open must preserve original authoritative state`. |
| `shop_retained_content_test.gd` | Stale paging fixture | None demonstrated. Its seven entries fit one nine-slot page; the page never advanced. | `b6d717756` changed page size from 2 to 9. This predates requested baseline `816f5e68a`. | Add spare gear locally until the fixture actually spans multiple pages. Shared flow data and production are unchanged. | Existing unchanged-page/control-identity assertions; new multi-page fixture precondition. |
| `static_floor_cache_equivalence_test.gd` | Stale renderer-reference inputs | None demonstrated headlessly; native comparison awaits the owner. | `5923db9da` (en-05; integrated by `062c3d40a`); `6b4927d2f` later adds `static_enemy_facings`. | Feed current presentation adapters into the independent frozen renderer. Preserve its original floor/layer implementation and every field/pixel assertion. | Existing full layer/pixel equivalence; new restored-empty versus fresh-production state, lighting and native-pixel comparisons. |

The intended contracts already exist in production: deck-01 migrates reserve
spells into the active deck; fix-02 commits scene-owned time at save boundaries;
the shop clamps pages to available entries and retains unchanged pages; current
enemy adapters publish explicit derived collections. No new design choice was made.
The inventory diagnostic found only `run_stats.run_seconds` differing, for example
4.745594 versus 4.679938 seconds.

## Requirements

1. Reproduced all four unchanged programs. Before-change logs are
   `output/bug-01/{prepared,inventory,shop,floor}-before.log`.
   `history-bisection.log` records read-only binary searches through source history
   and adjacent feature-parent/feature predicates. No historical engine checkout
   was made or historical full suite claimed. The baseline-version shop test was
   also executed against current production and reproduced the failure.
2. No production bug was demonstrated; no speculative production fix was made.
3. Updated stale fixture/reference inputs without removing assertions or excluding
   fields. Case/check counts vary with the existing 4 ms row-job slices; actual
   unfinished boundaries and actual owner invalidations are checked.
4. All four execute as programs from the full runner. All 27 child programs passed
   in the final full run, whose runner exit was 0.

## Files changed

- `tests/prepared_other_character_view_test.gd`: real deck mutation, actual
  cancellation/termination boundaries, frozen clock.
- `tests/retained_character_inventory_equivalence_test.gd`: frozen external clock.
- `tests/shop_retained_content_test.gd`: genuine multi-page local fixture.
- `tests/static_floor_cache_equivalence_test.gd`: enforced UI scale and new
  restored/fresh/reference proof, also runnable headlessly.
- `tests/fixtures/retention_play_clock.gd`: fixed external time input.
- `tests/fixtures/static_floor_cache_reference.gd`: current presentation adapters
  before the independent frozen renderer.
- `tests/helpers/program_sub_suites.gd`: register the four programs; copy names
  through an explicitly typed temporary for Windows compatibility.
- `tests/helpers/program_sub_suite_batch.gd`: bounded execution of independent
  task-runner processes. Assertions, per-child caps, total budget and log order
  are preserved; in-process tests remain serial.
- `tools/bug_01_programs.gd`: focused command using that same execution helper.
  It lives under tools so it does not introduce another orphaned test program.
- `tests/proof_contracts/bug_01_floor_restore.json`: mandatory three-image contract.
- `tests/bug_01_findings.md`: this handoff.
- `output/bug-01/`: local contract, investigation artifacts and observed logs.
  Its `.gdignore` is local-only per the output helper.

## Observed verification

Focused direct programs and the focused batch all returned exit 0. Current unit
result lines from the final full run (`output/bug-01/godot-full-final.log`):

```text
TEST RESULT: PASS
PREPARED OTHER CHARACTER VIEW RESULT: {"boundaries":{"equipment":14,"magic":28},"cancellation_boundaries":13,"cases":46,"checks":1045,"differences":0,"errors":[],"orphans":0}
PROGRAM SUITE prepared_other_character_view_test: PASS
CHARACTER RETENTION RESULT: {"cases":113,"differences":0,"errors":[],"orphan_nodes":0,"preparation_frames":3437}
PROGRAM SUITE retained_character_inventory_equivalence_test: PASS
SHOP RETAINED CONTENT TEST RESULT: PASS
PROGRAM SUITE shop_retained_content_test: PASS
STATIC FLOOR CACHE RESULT: {"cases":103,"checks":158583,"errors":[],"native":false,"orphans":0,"pixel_differences":[]}
PROGRAM SUITE static_floor_cache_equivalence_test: PASS
FULL SUITE RUNTIME: 718.780 seconds (budget 900 seconds)
TEST RESULT: PASS
```

Other observed results:

| Check | Exact result lines | Log under `output/bug-01/` |
| --- | --- | --- |
| Full Python discovery, exit 0 | `Ran 670 tests in 612.842s` / `OK (skipped=63)` | `python-full.log` |
| Prescribed SFX venv, exit 0 | `Ran 39 tests in 26.268s` / `OK` | `python-sfx.log` |
| UI identity lint tests, exit 0 | `Ran 25 tests in 3.553s` / `OK` | `ui-identity.log` |
| Task-runner regression tests, exit 0 | `Ran 11 tests in 5.061s` / `OK` | `python-runner-final.log` |
| Registry parser check, exit 0 | No parse/script errors; `--check-only` | `program-registry-parse.log` |
| Output import hygiene | `OUTPUT GDIGNORE: PASS (13 folders; 3 referenced roots)` | `output-gdignore.log` |

Python skips comprise 6 pinned classical-audio environment tests, 16 arrangement
tests without mido/music21, 2 opt-in native Blender tests, and 39 sound-lab tests
without optional modules. The 39 sound-lab tests passed separately in their
installed prescribed venv. No dependencies were installed.

Two serial full-suite attempts hit the unchanged 900-second outer limit before
reaching bug-01 (exit 124; `error: command timed out after 900 seconds.`), retained
in `godot-full.log` and `godot-full-serial.log`. Bounded independent execution
lets the final full registry complete within that same limit. Full output contains
ObjectDB leak warnings; the three instrumented equivalence programs explicitly report zero orphan nodes.

Commands executed from the task worktree:

```sh
python3 tools/output_gdignore.py
python3 tools/godot_task_runner.py --task-id bug-01 --stream -- godot --headless --path . --script tests/prepared_other_character_view_test.gd
python3 tools/godot_task_runner.py --task-id bug-01 --stream -- godot --headless --path . --script tests/retained_character_inventory_equivalence_test.gd
python3 tools/godot_task_runner.py --task-id bug-01 --stream -- godot --headless --path . --script tests/shop_retained_content_test.gd
python3 tools/godot_task_runner.py --task-id bug-01 --stream -- godot --headless --path . --script tests/static_floor_cache_equivalence_test.gd
python3 tools/godot_task_runner.py --task-id bug-01 --stream -- godot --headless --path . --script tools/bug_01_programs.gd
python3 tools/godot_task_runner.py --task-id bug-01 --timeout 900 --stream -- godot --headless --path . --script tests/run_tests.gd
python3 -m unittest discover -s tests -p 'test_*.py' -v
/Users/borgerding/.cache/umbra-sfx/venv/bin/python -m unittest discover -s tests -p 'test_sfx_lab.py' -v
python3 tests/test_ui_identity_lint.py
python3 -m unittest discover -s tests -p 'test_godot_task_runner.py' -v
python3 tools/godot_task_runner.py --task-id bug-01 --stream -- godot --headless --path . --check-only --script tests/helpers/program_sub_suites.gd
```

## Proof for the design owner

Native proof is pending: this sandbox has no window-server access. No windowed
run was attempted. Run:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/bug-01 && python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy tests/static_floor_cache_equivalence_test.gd --task-id bug-01 --expect-size 1920x1080 --proof-contract tests/proof_contracts/bug_01_floor_restore.json --result-manifest output/bug-01/floor-native.manifest.json
```

Expected capture paths, not yet generated:

- `user://bug_01_floor_restored.png`
- `user://bug_01_floor_fresh.png`
- `user://bug_01_floor_reference.png`

The program enforces 1920x1080 and UI scale 1.0, prints absolute paths, and asserts
byte-for-byte equality of all three images. The manifest records validated image
paths. Inspect the native captures before concluding visual equivalence.
No playable inspection fixture is needed for this test-only change; the required
manual inspection is the native three-image comparison. The owner handles Git,
review, inspection and publication.

## TODO_DESIGN placeholders

None.

## Chosen defaults

Only test/proof/execution inputs were chosen:

- `MAX_PARALLEL_PROGRAMS = 4`, `POLL_INTERVAL_MSEC = 10`; existing 180-second
  child caps and 900-second total budget remain intact.
- `RETENTION_CLOCK_USEC = 1000000`: identical fixed clock input in both scenes.
- `MAX_CANCELLATION_BOUNDARIES = 64`: safety limit with a completion assertion.
- `PROOF_AMBIENT_SECONDS = 12.0`, `PROOF_IDLE_SECONDS = 2.0`: existing frozen
  samples reused for the fresh comparison board.
- `RESTORE_PROOF_SETTLE_FRAMES = 3`: settle the fresh nested native viewport.
- `PAGING_FIXTURE_SPARE_GEAR_ID = "iron_cleaver"`: local spare entries until
  inventory exceeds the production page size.
- Contract `min_luma_range = 8`, `min_luma_stdev = 2`: reject blank proof images.
- `PROOF_SIZE = 1920x1080`, `PROOF_UI_SCALE = 1.0`: mandated proof settings.

## Open issues / scope limits

- Native captures still require the owner's windowed run and inspection.
- The full suite prints ObjectDB leak warnings despite passing; the three instrumented equivalence
  programs report zero orphan nodes.
- Initial task-helper status reported an empty contract despite the supplied
  bootstrap statement. `output/bug-01/contract.md` records acceptance, proof, risk
  and inspection expectations without changing owner-managed metadata.
- Stopping the obsolete serial run was denied by the sandbox:
  `PermissionError: [Errno 1] Operation not permitted`. It ended naturally at its
  timeout. No alternate signaling or elevated permission was attempted.

No commit, push, merge, rebase, stash, branch switch, peer review, signoff, queue
edit, or `tests/quarantine.json` edit was performed.
