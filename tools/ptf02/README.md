# ptf-02 implementation and proof

Base: `7cf181c7e`; all changes are left uncommitted for the design owner.

1. New runs call `RunEngine.create_new_run` → `SectionMapGraph.initialize`,
   whose default remains revision 7. Every lane at step 4 is a reserved non-fight
   Ember Hearth. All routes advance one step per edge, so each passes exactly
   one midpoint Hearth, in local depth band 2. Step ceil(S/2) still grants the
   guaranteed Relic; S−1 still contains the pre-boss Hearth. The topology gathers
   into all three fixed rows. The type solver assigns the remaining slots;
   there is no post-generation conversion of fights, Guardians or specials.
   Fight counts/slack, Guardian placement/bypass, Scavenger availability,
   Graftwright gating, service adjacency, choice cadence and physical doors
   retain their rules. Section I's adjacent Hearth and Relic rows reject any
   topology that would permit a fourth consecutive single exit.
2. `CAMPFIRE_LINGER_HEAL` is 6. The existing UI description, capped benefit chip
   and presentation read the runtime value. `spec/ember_hearth.md` states 6.
   The Umbra-depth delta still applies once (5 HP at depth 5 and above).
3. No hearth options, assets, icons, input handling, reveal/scouting code,
   analytics event schema or save schema changed. The existing
   `campfire_linger` persistence boundary remains in place.

All six revision-7 fallback layouts were regenerated through the existing
`tools/section_map_v7_fallbacks.gd` generator. Revisions 3–6 are explicitly
selected compatibility paths; new runs never select them. They remain
unchanged. No saved map is initialized again during resume.

`prechange_run.save` is a production-serialized run (seed 83) recorded from the
unmodified base before changing generation or healing. The single permanent
save test is invoked by the existing revision-7 map suite and can also run
standalone. It loads through `ProgressionStore.load_saved_run`, resumes through
`RunEngine.repair_loaded_run_state`, and checks all stored rooms and section
metadata through another save/load. Do not regenerate this fixture with the
new generator; its recording mode rejects midpoint Hearths.
Fixture SHA-256: `161f480b898021037f9c0920dd4e5be108f2a6898bdb14af04e243e5ae8dbd2f`.

## Headless proof commands

Run from this worktree. The explicit 600-second audit cap accommodates 500
complete runs; it is a proof timeout, not a gameplay value.

```sh
python3 tools/ptf02/prepare_baseline.py
python3 tools/godot_task_runner.py --task-id ptf-02 --timeout 600 --stream -- godot --headless --path . --script tools/ptf02/map_audit.gd -- --phase=before --baseline-source=/private/tmp/labyrinth_codex/ptf-02/baseline/section_map_graph.gd
python3 tools/godot_task_runner.py --task-id ptf-02 --timeout 600 --stream -- godot --headless --path . --script tools/ptf02/map_audit.gd -- --phase=after
python3 tools/ptf02/report.py
python3 tools/godot_task_runner.py --task-id ptf-02 --timeout 600 --stream -- godot --headless --path . --script tools/ptf02/focused.gd
python3 tools/godot_task_runner.py --task-id ptf-02 --stream -- godot --headless --path . --script tests/ptf02_saved_map_test.gd
python3 tools/godot_task_runner.py --task-id ptf-02 --stream -- godot --headless --path . --script tools/ptf02/hearth_checks.gd
python3 tools/godot_task_runner.py --task-id ptf-02 --stream -- godot --headless --path . --script tests/suites/section_map_v5_program.gd
python3 tools/godot_task_runner.py --task-id ptf-02 --stream -- godot --headless --path . --script tools/ptf02/map_probe.gd -- --logic-only
python3 tools/run_python_suite.py --shards 4 --changed-since HEAD --output-dir /private/tmp/labyrinth_codex/ptf-02/python-default
python3 tools/run_python_suite.py --shards 4 --audit-only --output-dir /private/tmp/labyrinth_codex/ptf-02/python-audit
python3 tests/test_ui_identity_lint.py
git diff --check
```

The Python selection is the default group only (all other pass groups have no
matching triggers). No new Python test module or dependency was added.
The baseline extractor reads Git without changing it. It removes the duplicate
global class registration, redirects the unchanged base fallback data into
scratch, and adds only a diagnostic fallback counter for special-placement
failure. It does not change generation decisions or random draws.

## Proof for the design owner

No windowed/native run was attempted. The probe extends the existing
`tests/map_03_probe.gd`, reusing its viewport, map panel, capture implementation
and 1920×1080 geometry. It fixes UI scale at 100%. It captures Section I's
threshold, band-2 Hearth and pre-boss row for seeds 83, 307 and 90429 (nine PNGs).
It rejects a missing cel manifest, and uses only the existing approved assets.

This fresh worktree has no `cel_look_variants/manifest.json` (`CEL_STATUS`
reported the missing path). Before renderer proof, refresh the existing cache
with `python3 tools/cel_look.py build --if-stale`, then check it with
`python3 tools/cel_look.py status`. No art was generated by this unit.
Then run this exact windowed command:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/ptf-02 && LABYRINTH_CEL_LOOK=all python3 tools/visual_probe_runner.py --task-id ptf-02 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --min-images 9 --proof-contract tools/ptf02/proof_contract.json --result-manifest /private/tmp/labyrinth_codex/ptf-02/map-proof.json tools/ptf02/map_probe.gd
```

Copies of the nine PNGs go to `/private/tmp/labyrinth_codex/ptf-02/captures/`;
the inherited probe also retains originals in its isolated `user://map-03-proof`
directory. No inspection-fixture command was requested by this unit brief.
The design owner owns visual inspection, review, commit and publication.

## TODO_DESIGN and chosen defaults

No missing design decision required a `TODO_DESIGN_` placeholder.
Proof-only defaults: seeds 83/307/90429; seed 83 for the pre-change save and
focused fixtures; scratch/save/capture paths named in the tools; 600-second
audit/focused and 1,800-second import caps. The 500-seed inventory and six
sections come from the brief. Viewport geometry and settling frames are inherited
from the existing map probe. No new player-visible tuning was chosen.

## Observed focused results

- `PTF02 FOCUSED RESULT: PASS (120006 checks, 0 failures)`
- `Section map revision 7: 240 sections checked`
- `SECTION MAP V5 PROGRAM RESULT: PASS (10302 checks, 0 failures)`
- `PTF02 SAVED MAP RESULT: PASS (7 checks, 0 failures)`
- `PTF02 HEARTH CHECKS RESULT: PASS (279 checks, 0 failures)`
- `PTF02 MAP PROBE: PASS` (headless `--logic-only`; no screenshots)
- Python default group: `Ran 189 tests in 45.195s`, `OK` (20 modules).
- UI identity lint: `Ran 25 tests in 7.536s`, `OK`.
- Isolation audit: `ISOLATION AUDIT: 56 modules` (no new Python test modules).
- Python helper compilation and `git diff --check` passed.

Final audit: 500 seeds × six sections, 145,515 after-change routes; zero routes
without a midpoint Hearth, zero with multiple midpoint Hearths, zero rule
violations. Both before and after had zero generation failures and zero fallback
sections. The forced-fallback focused test independently verifies all six
stored layouts and special placement.

Generation time (before → after, milliseconds): per-section p50
88.238 → 61.819, p99 381.789 → 303.202; complete-run p50
610.504 → 441.822, p99 1250.977 → 968.318. Host load was uncontrolled;
these are observed timings, not a performance qualification. Full per-section
room counts and timing/fallback details are in
`/private/tmp/labyrinth_codex/ptf-02/map_audit_before.json`,
`map_audit_after.json` and `map_audit_comparison.md`.

Logs are under `/private/tmp/labyrinth_codex/ptf-02/`. Full suites were not run.
Initial cadence and Section VI landmark failures were fixed; the result lines
above are the subsequent passing runs. Intermediate audit logs are superseded
by `audit_before_verified.log` and `audit_after_complete.log`.

Headless Godot logs contain the sandbox's system-CA lookup error. The intentional
asset import reported an existing duplicate placeholder-image UID. Neither
caused a test failure. The Python suite passed but could not update its optional
Git-metadata timing cache because Git metadata is read-only. Python helper
compilation was rerun successfully with its bytecode cache under task scratch.
Renderer captures and visual inspection remain open for the design owner.
