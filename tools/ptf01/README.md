# ptf-01 proof

All artifacts go to `/private/tmp/labyrinth_codex/ptf-01/`. Run from this worktree:

```sh
python3 tools/godot_task_runner.py --task-id ptf-01 --stream -- godot --headless --path . --script tools/ptf01/check.gd
python3 tools/godot_task_runner.py --task-id ptf-01 --timeout 1800 --stream -- godot --headless --path . --script tools/ptf01/encounter_curve.gd
python3 tools/ptf01/verify_baseline.py
python3 tools/ptf01/shape.py
python3 tools/ptf01/report.py
python3 tools/run_python_suite.py --shards 4 --audit-only --output-dir /private/tmp/labyrinth_codex/ptf-01/python-audit
python3 tools/run_python_suite.py --shards 4 --output-dir /private/tmp/labyrinth_codex/ptf-01/python-default
```

`check.gd` exercises the existing encounter-table validation, weights, history,
legacy room differential, one permanent save/resume contract, tier/cap/determinism
sweep, a forced token-fit re-roll, invalid caps, tutorial counting, section reset
and additive analytics snapshot fields. `--write-sidecars` creates missing UIDs
only for this directory's new GDScript sources, using the engine UID allocator.
It does not scan the editor or rewrite existing UIDs.

`encounter_curve.gd` samples 300 seeds, Sections I–III, choosing uniformly among
legal exits. Completion is synthetic, preserving the same route for old/new and
maintaining separate no-repeat histories. No combat outcomes or noncombat rewards
are simulated in this roster measurement. Regular fights use the same production
layout factory as gameplay, including depth-scaled HP. Specials and Guardians are
unchanged but advance k. Twenty seeds per tester shape force k/depth on the first
generated node at the relevant step, retaining its coordinate and element. These
are controlled shape fixtures, not a replay of an unavailable tester save.

`verify_baseline.py` reconstructs the unmodified encounter table and generator
from the brief’s base `7cf181c7e` in the proof output directory and compares 1,080 complete layouts
with the baseline helper (ignoring only the new analytics tier field). It reads
Git objects without writing Git metadata.

`baseline_generator.gd` selects the original depth tier and old expansion through
the saved-room compatibility path; original composition weights, token weights,
no-repeat behavior, RNG call order and global cap 7 are retained. It is used by
both proofs and the save contract; no protected rosters are copied or changed.

`shape.py` imports the existing `tools/run_curve.py` score generation and frozen
policy verifier. `shape.gd` extends its unchanged `tools/run_curve.gd` simulation,
changes the room generator only for the baseline, and terminates after Section
I's dragon reward. There are no health resets or forced victories. It flushes
completed records after each old/new run (seeds 1–30, policy `best`) in three
workers, each with a ten-seed range. All share a 2,400-second wall deadline; a
partial run at timeout is excluded. `--continue-existing` adds seeds 11–30 to an
already-running original worker while retaining that original wall deadline.
`report.py` de-duplicates identical (seed, variant) records and rejects conflicts.
Do not poll the long job. Generate the report once both measurements finish or
the shape job reaches its cap. `report.py` reads flushed records even after a cap.

Chosen defaults (proof only): seed prefix 1–300/1–20/1–30; route RNG salt 5101;
uniform legal-exit sampling; no tutorial in simulations (the existing run_curve
default); policy `best`; tester fixture entrance `Vector2i.ZERO`, no prior table
history and first node at the requested step; curve timeout 1,800 seconds; three shape
workers with contiguous ten-seed ranges (the existing run_curve worker limit). Shape
N=30 and 2,400-second limit come from the brief. Output paths and UID allocation
are tooling details. No player-visible design defaults or TODOs were added.

No windowed proof is required by this unit. The design owner play-tests it.

## Feedback 1

The tier ceilings are now `3/5/6`; fight-number caps are `3/3/4/5/5/6`,
with later fights retaining the final cap. Runtime supplies the persisted k to
`EncounterTables.pick`; a context-free table query (k=0) retains the tier ceiling.
Validation checks each reachable tier/effective-cap pair for every biome and
supported element, including neutral rooms. Fight-cap keys must be consecutive
positive integers starting at 1, so no in-range lookup can be missing.

Keep this round's measurements separate from the original proof:

```sh
python3 tools/godot_task_runner.py --task-id ptf-01 --stream -- godot --headless --path . --script tools/ptf01/check.gd
python3 tools/godot_task_runner.py --task-id ptf-01 --timeout 1800 --stream -- godot --headless --path . --script tools/ptf01/encounter_curve.gd -- --output /private/tmp/labyrinth_codex/ptf-01/feedback1/encounter_curve.json
python3 tools/ptf01/report.py --output-dir /private/tmp/labyrinth_codex/ptf-01/feedback1 --skip-shape
python3 tools/ptf01/analytics_compile_check.py
python3 tools/run_python_suite.py --shards 4 --audit-only --output-dir /private/tmp/labyrinth_codex/ptf-01/feedback1/python-audit
python3 tools/run_python_suite.py --shards 4 --output-dir /private/tmp/labyrinth_codex/ptf-01/feedback1/python-default
```

No run_curve shape simulation is requested this round. The earlier shape results
remain in the original output directory and are not incorporated into this report.
The route/tester fixture defaults are unchanged.

### Analytics integration compile failure

`analytics_compile_check.py` obtains `deferred_choice_surface.gd` from the supplied
base `7cf181c7e`, verifies the current helper is identical, and reloads that source
in an isolated headless script that never imports `analytics_snapshots.gd` or
`run_scene.gd`. The base helper declares:

```gdscript
const SkinLibrary = preload("res://scripts/ui_skin.gd")
func configure(panel: PanelContainer, title: Label, reward_title: Label, skin: UiSkin, enabled: bool) -> void:
```

The direct failure is `Could not find type "UiSkin" in the current scope`
(`ERR_PARSE_ERROR`, 43). This checkout has no `.godot/global_script_class_cache.cfg`;
the helper's parameter uses a global class name rather than its local preload
alias. Reloading a diagnostic copy with **only** `skin: SkinLibrary` instead
returns `OK` (0). The production UI file is not modified.

That unresolved signature makes `run_scene.gd:4598` unable to resolve the external
`configure` member during compilation. The analytics diff consists only of two
integer dictionary entries inside `combat_started`; it changes no preloads,
classes, signatures, or static initialization. This diagnostic reproduces the
base helper failure without analytics, so the payload additions cannot cause it.

Expected diagnostic lines:

```text
PTF01 BASE UI SIGNATURE: error=43 analytics_imported=false
PTF01 BOUND UI SIGNATURE: error=0 analytics_imported=false
PTF01 ANALYTICS CAUSE: PASS
```

The task runner exits 1 because it correctly detects the intentionally reproduced
parser-error marker. This is an isolation experiment, not a passing analytics
integration test. No stash, branch changes, or edits to the shared UI helper are
needed. The direct combat-start payload checks remain in `check.gd`.

## Combined-suite regression pass

The task branch is checked independently of `codex/ptf-combined`. Run only the
reported program subset through isolated task-runner children:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/ptf-01 && python3 tools/ptf01/combined_programs.py --round before
cd /Users/borgerding/workspace/Labyrinth.worktrees/ptf-01 && python3 tools/ptf01/combined_programs.py --round after --programs warband_test snare_test save_resume_boundary_test departed_run_cleanup_test suites/full_scene_choices_program suites/full_scene_clock_program
cd /Users/borgerding/workspace/Labyrinth.worktrees/ptf-01 && python3 tools/godot_task_runner.py --task-id ptf-01 --stream -- godot --headless --path . --script tools/ptf01/check.gd -- --write-sidecars
```

`combined_programs.py` creates the same namespace bootstrap as the existing
program scheduler and runs only the named programs, with three workers. Its
`enemy_intent_continuity` entry invokes the exact suite used by the main Godot
body, without invoking the full main suite. Logs and before/after results live in
`/private/tmp/labyrinth_codex/ptf-01/combined-feedback/`.

A missing room `fight_number` now always selects the original depth-tier picker,
including its original expansion, RNG calls, global bound and layout dictionary
keys. Explicit k opts into the approved fight/tier caps. Legacy rooms omit the new
`encounter_tier` key, so `_record_encounter_pick` accepts its absence. The focused
legacy differential also checks the existing 128 revision-4/5 full-layout goldens
shared with Warband/Snare. The golden data is not rewritten.

The `missing_enemy` validation error is deliberate: `_test_invalid_fallback`
installs one invalid table and verifies populated legacy fallback, then clears the
table cache. Both authored production and frozen fixture tables validate; this
message does not indicate either table is malformed. The combined log reports
`PROGRAM SUITE suites/encounter_rules_program: PASS` after that diagnostic.

Fresh standalone runs require the normal script-class registry bootstrap. The
clock program additionally pins `Texture2D.resource_path` for Unknown Presence;
a source-file fallback has no imported resource path. This pass imported only
that unchanged approved PNG in an isolated minimal Godot project, retaining its
resource-relative path and authored import options, then copied the generated
artifact into the local `.godot/imported` cache. No production asset or UI code
was changed. This distinguishes cache setup from a branch behavior regression.
The combined branch's Defiance/copy clock failures are checked separately by the
same clock program on this branch.

Observed results on task HEAD `b773e29b5` before the correction: Warband and Snare
failed 128 legacy layout goldens each. All other reported behavior failures did
not reproduce. The clock program initially failed only the two Unknown Presence
resource-path checks described above; those passed after the cache import.

After the correction: Warband, Snare, save/resume boundary, departed cleanup,
scene choices and scene clock all exited 0. Event feedback, Flurry retirement,
glossary, board tile tooltip and the exact isolated enemy-intent continuity suite
had already exited 0 before the correction. The focused check passed 5,936
assertions, including the existing 128 modern missing-k goldens. No assertion or
golden pin was relaxed. `combined-feedback/results.json` contains the complete
cause/fix matrix and exact log paths. No full suite or curve simulation was run
in this regression pass. No player-facing defaults, assets, tuning or copy changed.
