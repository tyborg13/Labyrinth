# area-01 implementation and proof

Implementation only, 2026-11-16. Changes remain uncommitted on `codex/area-01`.
No peer review, publication, queue edits or inspection-fixture installation was
performed. Native renderer inspection belongs to the design owner.

## Numbered requirements

1. **Kind 1:** `scripts/boss_area_rules.gd` enumerates only the approved moves.
   Each selected area action retains `area_fixed_tiles` at declaration. Guardian
   geometry, dragon fields, helper connectors and Thornwall use those absolute
   tiles, independent of later hero/source movement, route interruption, LOS,
   armor range or live fuel. Only newly impassable marks become inert. Existing
   terrain victims are retained by identity; new terrain does not prune tiles
   farther down a lane. The original movement resolver, victims, damage,
   statuses, surfaces, pushes and assets are retained.
2. **Detonations:** Crownfire, Faultline, Groundsplit and Last Eclipse hold the
   announced union. Clearing original fuel does not cancel its blast. Later fuel
   does not enlarge it. Crownfire consumes only its original surviving Fire;
   Faultline consumes only its original surviving owned rock. New fuel remains.
3. **Marked landing:** Erupt damages its saved `erupt_tile` even if its surfacing
   body relocates. Its existing adjacent push, surfacing and surface placement
   remain tied to the landing. The controlled blocked-landing rule test covers
   both damage at the mark and the original adjacent push.
4. **Kind 2:** the data already supplied separate actions/rows for Meteorfall's
   shot, Faultline's shot, Cinder Maw's bite, Crownfire's bite and Eye of the
   Storm's melee. These are preserved, with live ordinary target selection at
   each action rather than the compound plan's old primary-target context.
   Their actual and hovered-destination forecast receipts are compared
   separately from the generic source-owned red matrix.
5. **Showing:** existing danger diamonds hold announced areas at rest, including
   before the source is due, through hovering, sight changes and delayed
   Thornwall marks. They reveal no units or terrain. The same palette, sizes,
   timing, fonts, input paths and row builders are used. No tooltip text changed.
6. **Saves:** the production load path freezes legacy `declared_tiles` verbatim,
   including empty arrays, before resumed input. It never translates those
   stored tiles. Legacy detonations without a stored footprint snapshot the
   saved fuel/refuges once; a pending Thornwall keeps its saved marks. Current
   saves are idempotent through migration. Analytics adds only `area_targeting`
   and `area_shown_tiles`; existing fields/events/JSONL semantics remain intact.

No `data/`, assets, rule-beat implementation (`scripts/battlefield_rules/`),
card tuning, icon registry, audio or font was changed. No card heuristic score
changes apply: this changes boss targeting geometry, not a card or its scoring
assumptions. Difficulty is measured without adjusting any authored number.

## Files

- Production: `boss_area_rules.gd`; adapters in `guardian_combat_rules.gd`,
  `combat_engine.gd`, `enemy_mechanics/bramble.gd`, `enemy_mechanics/burrow.gd`;
  `progression_store.gd`; `enemy_action_analytics.gd` and `spec/analytics.md`.
- Existing danger paint: `intent_badges.gd`, `pass_forecast_red_tiles.gd`,
  `threat_tiles.gd`, `board_layer_slices.gd`.
- Rules: new `tests/suites/boss_area_rules_suite.gd`; existing expectations in
  `tests/dragon_committed_patterns_test.gd`, `dragon_area_presentation_suite.gd`,
  `dragon_pressure_mechanics_suite.gd` and `guardian_suite.gd` now express the
  approved fixed-area rule. Their original baseline checks passed before the
  implementation; no pre-existing failing assertion was rewritten. The existing
  Guardian rules entry point also runs the new coherent rules suite, so the
  design owner's full-suite merge checks include it without growing run_tests.gd.
- Proof: this directory and its `.gd.uid` sidecars. `tools/run_curve_dragons.py`
  exposes the opt-in `--area01` adapter. Its ordinary/zek-01 defaults are unchanged.

## Truth audit

`audit.gd` extends atk-13's actual production scene for PASS, red at rest and every movement destination; `observed_engine.gd` wraps real resolver/effect receipts and
mutes planning copies. `followup_audit.gd` adds the same forecast cursor's
per-action receipts. No enemy intent, roster, rule, damage or actor position is
substituted in these natural fights. Ordinary-helper sampling uses a fresh run,
production mystery resolution/room-entry metadata and the existing sweep's
prior-cleared-combat convention to avoid substituting the guided first fight.
The inherited 9999-Health walk preserves observation time; it is not difficulty
proof of a progressed build. Vyraketh can naturally die to its own ground.

Completed output is `/private/tmp/labyrinth_codex/area-01/audit-final/`; follow-up
output is `/private/tmp/labyrinth_codex/area-01/followups/`. Every decision has
`run.save`, `progression.json`, and `combat_state.txt` under its `repro/` directory.
`results.md` records exact denominators, per-move counts, matrices and results.
Alternative choices are not independent played encounters. `walked_executions`
counts only the continued walks; every listed move has evidence in two seeds.
Later declarations within a choice window are not mislabeled as the intent
already shown at that window's start.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/area-01 && python3 tools/atk13/area01/audit.py report --output-dir /private/tmp/labyrinth_codex/area-01/audit-final
cd /Users/borgerding/workspace/Labyrinth.worktrees/area-01 && python3 tools/atk13/area01/audit.py report --output-dir /private/tmp/labyrinth_codex/area-01/followups
```

To reproduce into fresh directories: run the eleven boss targets with seeds
1301/1302 and `--turns 36`, then `burrow_grub briar_weaver` with seeds 1302/1310.
The exact original commands/environments are retained in each `completed.json`.
Use `--followups --targets vyraketh tharokh vaeloryx` for the separate per-action
forecast matrix. The single disclosed Faultline disagreement is retained;
there are no undisclosed per-action disagreements. Generic red-owner matrices
also retain warnings attributable to the area half of a compound move.

The remaining case is seed 1302, point `1302-16`, hover `(1,4)`, save
`/private/tmp/labyrinth_codex/area-01/followups/tharokh-1302/repro/1302-16`.
The existing unseen-ground filter predicts Tharokh at `(6,3)`; production has
him at `(5,3)`, and his live shot deals 4 Health. The hover is already red for
`enemy_1` and shows uncertainty; the omniscient forecast matches production.
Thus strict per-action equality over every alternative is not established.
Preserving the existing information filter avoids changing ordinary forecast
behaviour or revealing hidden terrain as part of this targeting unit.

## Difficulty

`measure.py` reuses `run_curve.gd`, `run_curve_ladder.gd` and the byte-unchanged
`run_curve_combat.gd`/policy-v2 fight loop. Before source is snapshotted under
`/private/tmp/labyrinth_codex/area-01/difficulty/baseline-project/` before editing.
The baseline ladder recovers actual constructor inputs at natural Guardian and
Dragon entry points, with the existing full-Health ladder convention. Exactly
64 matched constructor/RNG cells per boss are replayed before/after. The first
nine ladders supply the entry loadouts; `capture_cantor.py` recovers additional
natural routes because those nine did not take a Storm Cantor node. Extra
routes supply only the missing Cantor group, not the other eleven groups. In
this run, seeds 10–24 were recovered; seed 24 supplied the one Cantor entry.
No meas-07 tool is present in this checkout. This opt-in extension avoids the
older driver's historical-archive equality assertion after an intentional
mechanic change while retaining its actual ladder, draft and policy.

Raw files, exact Godot-runner commands, source hashes and constructor inputs are
under `/private/tmp/labyrinth_codex/area-01/difficulty/`. The final Tharokh suffix
rerun preserves the original blocked-Grub adjacent push as well as fixing its
marked damage. All other boss cohorts have no Burrow Grub in their authored
rosters. Matched metadata is asserted before reporting win-rate changes.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/area-01 && python3 tools/run_curve_dragons.py --area01 report --output-dir /private/tmp/labyrinth_codex/area-01/difficulty
```

## Tests

The brief's focused suites and probes are dispatched by `run_checks.py`. It does
not run `tests/run_tests.gd` or the full Python suite. Exact result lines and log
paths are in `results.md`; raw logs are under
`/private/tmp/labyrinth_codex/area-01/checks/`.

The existing Python Guardian measurement fixture fails on both baseline and
this branch in `test_production_contains_only_the_chosen_cumulative_rungs`
(`tests/test_guardian_rules_measurement.py:186`): the fixture expects
older enemy definitions, including `art_scale: 1.15` where unchanged master data
contains `1.03`. Neither this
assertion nor the protected data is changed. No new Python `tests/test*.py`
module was added; the resource audit still inventories 56 modules.

## Proof for the design owner

No windowed run was attempted. Three headless component cases pass; those prove
save loading, displacement, red membership and production playback receipts,
not pixels, taste, actual pointer handling or native rendering.

Run these exact native cel commands at 1920×1080 and 100% UI scale:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/area-01 && sh tools/atk13/area01/native_capture.sh /private/tmp/labyrinth_codex/area-01/audit-final/tharokh-1301/repro/1301-3 tharokh bedrock_breath
cd /Users/borgerding/workspace/Labyrinth.worktrees/area-01 && sh tools/atk13/area01/native_capture.sh /private/tmp/labyrinth_codex/area-01/audit-final/tharokh-1301/repro/1301-2 tharokh worldspine_claw
cd /Users/borgerding/workspace/Labyrinth.worktrees/area-01 && sh tools/atk13/area01/native_capture.sh /private/tmp/labyrinth_codex/area-01/audit-final/gallows_roc-1301/repro/1301-1 gallows_roc hookwind
```

The wrapper invokes `visual_probe_runner.py`, the existing native Metal launcher,
`LABYRINTH_CEL_LOOK=all`, exact-size checks, `capture_contract.json` and separate
result manifests. Each case emits `<enemy>-<intent>_rest.png`, `_strike.png` and
its semantic `.json` under `/private/tmp/labyrinth_codex/area-01/captures/`.
No `inspection_fixture.py` installation is needed: audited saves load directly
in the runner's isolated HOME. Fixture preparation remains with the design owner.

Gallows Roc is authored **Anchored**. A genuine production push cannot move it.
The Hookwind case records that immunity and labels its closest available proof
as `synthetic_anchored_displacement: true`, using debug force placement without
changing the production immunity. Both Tharokh cases use actual forced movement.
Worldspine's case also retains the impassable-mark exception: Upheaval raises
Outcrops after announcement, so those marks are inert when the strike fires.
Its pushed body can remain at `(3,3)` while a held claw reaches `(2,6)`; this is a
concrete reproduction to inspect for detached-looking strikes, not a redesign
or a claim to have judged native pixels.

## TODO_DESIGN placeholders and chosen defaults

No TODO_DESIGN placeholder or new player-facing value was needed.

The named rules fixtures use source `(5,3)`, hero `(2,4)`, displacement `(0,1)`
and 2000 Health on the inherited arena. Fire/rock witnesses use `(3,4)` and
`(6,5)`, plus one-tile hover offsets; save compatibility uses the private
`user://area01-null-combat.save` path. These are test-only fields.

Chosen proof defaults are plain fields/constants in the tools: seeds 1301/1302
for boss walks and 1302/1310 for ordinary helpers; 36 decision points; inherited
9999 Health, 0.75 movement probability, UP entrance, time scale 64 and uncapped
proof FPS. Ladder recovery starts with seeds 1–9, then scans 10–30 in batches
of three only until a natural Cantor entry is found; RNG stride 1000003 is
inherited from run-curve. Three headless workers are the default; the corrected
Tharokh cohort uses one. Measurement input readiness polls at 100 ms.

Native component staging uses a one-tile push, directions Right/Left/Down/Up,
a 2400-frame playback guard, inherited 90 boot/12 layout frames and pointer
parking at `(960,4)`. Contact timing is read from production DragonPresentation.
The 300-second capture guard accommodates playback, not renderer-launch retries.
All proof outputs and isolated HOME locations are task-specific. No gameplay,
rendering style, motion, sound or timing default was authored by this worker.

## Open issues

- Owner-run native captures and their inspection remain outstanding by sandbox
  contract. Hookwind's production push is impossible while Roc is Anchored;
  the alternative is explicitly labeled in the proof.
- The pre-existing Python Guardian fixture mismatch above remains reported.
- Strict all-alternatives follow-up equality retains the one disclosed
  unseen-ground Faultline case above; no undisclosed disagreement was observed.
- No full suite, peer review, commit, inspection-fixture install or publication
  was performed; those steps belong to the design owner under the task split.
