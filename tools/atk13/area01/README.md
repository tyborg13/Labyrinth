# area-01 feedback 1: relative stamps and fixed marks

Implementation of the director's 2026-11-16 feedback. Changes remain uncommitted
on `codex/area-01`. The owner handles native inspection, commit, peer review and
publication. No windowed run, peer review, Git write or queue edit was performed.
The previous handoff is archived in `round0_readme.md` and `round0_results.*`.
`results.md` / `results.json` are the current empirical handoff.

## Requirements

1. **From the boss:** `scripts/boss_area_rules.gd` classifies the 19 approved
   relative moves. `area_fixed_tiles` remains the save-compatible field holding
   the original footprint, with `area_targeting: relative_to_source`. The stamp
   translates by actual attack anchor minus stored planned attack anchor.
   It never rotates, re-aims, extends a lane or rebuilds a shape from the live
   board. Only off-board/newly impassable cells are inert. The original committed
   path remains an offset from its announcement start, including after forced
   displacement; interrupted movement shifts the whole strike with the actual
   arrival. Existing movement, victims, damage, surface and push resolvers remain
   in use. The rest-badge service reads the card forecast's source position, so
   relative red moves during aiming, even before the boss is due. For the
   imminent cast, the existing loss cursor supplies its resolved attack anchor,
   including known later route interruptions. Its private receipt survives the
   forecast codec; it is absent from live state, saves and analytics. No second
   forecast or alternative movement model is introduced.
2. **Sky/ground:** the eight fixed moves retain round-0 frozen footprints and
   original fuel ownership. Meteorfall and Cinder Maw marks, Skybreak, Thornwall,
   Crownfire, Faultline, Groundsplit and Last Eclipse never translate. Grub damage
   remains on its original Erupt mark if surfacing relocates. Its existing badge
   now remains on that same marked tile rather than following the relocated body.
   Ordinary live-target follow-ups remain separate actions, rows and events.
3. **Marked:** existing per-tile medallions were found in Icefall, Lob Slag and
   Erupt; no missing-visual stop was needed. Fixed boss areas reuse Lob's existing
   medallion painter and the approved `assets/art/icons/marked.png`. Relative
   areas have only ordinary enemy red. Fixed action rows, including raw library
   and pre-battle rows, carry the existing Marked keyword; the existing glossary
   entry is discovered. Mouse and controller tile details use its unchanged
   definition. No new art, icons, words, fonts, sounds or visual tuning was made.
   **Meteorfall would double up:** its landed cinder marks already have per-tile
   medallions. The generic Marked painter and detail entries omit those tiles,
   preserving one existing cinder badge rather than stacking another badge.
4. **Saves:** new saves retain announcement and planned attack origins plus the
   source id. Round-0 or older relative actions use the saved path/origin when
   present (`area_origin_basis: stored_announcement`). With no recorded origin,
   stored tiles are treated as announced from the current source position
   (`current_position_fallback`). Neither case re-aims or reconstructs the held
   footprint. Current-save migration is idempotent; null non-combat checkpoints
   still load. Fixed legacy detonation/pending-wall migration remains as in
   round 0. Missing or partial paths and null origins use the current-position fallback.
   If the body plan is absent, the existing movement planner seals its offset
   once against the saved board while retaining the stored footprint and
   direction. Rules checks cover these cases, empty footprints and actual
   production save loading. An actual round-0 save also completed push/strike
   playback with `stored_announcement` origins.

## Unit files across both rounds

- Targeting/resolution: `scripts/boss_area_rules.gd`, `guardian_combat_rules.gd`,
  `combat_engine.gd`, `enemy_mechanics/bramble.gd`, `enemy_mechanics/burrow.gd`.
- Presentation: `intent_badges.gd`, `pass_forecast_red_tiles.gd`, `pass_forecast_discs.gd`,
  `threat_tiles.gd`,
  `board_layer_slices.gd`, new `boss_area_marks.gd`, `board_threat_isolation.gd`,
  `board_threat_isolation_paint.gd`, `combat_board_view.gd`, `board_tile_tooltip.gd`,
  `enemy_mechanics/lob_view.gd`, `enemy_mechanics/burrow_view.gd`,
  `action_icon_library.gd`, `pre_battle_inspection_view.gd`, `grimoire_library.gd`.
- Saves/analytics: `progression_store.gd`, `enemy_action_analytics.gd` and
  `spec/analytics.md`. Analytics retains the additive targeting/shown-tile fields;
  relative events identify `relative_to_source`, fixed ones `fixed_at_announcement`.
- Rules: `tests/suites/boss_area_rules_suite.gd`, its Guardian suite integration,
  and changed-rule expectations in `dragon_committed_patterns_test.gd`,
  `dragon_area_presentation_suite.gd`, `dragon_pressure_mechanics_suite.gd`,
  `guardian_suite.gd`, `en01_enemies_suite.gd`. No non-rules test module was added.
- Proof: this directory, its owned UID sidecars, and the existing opt-in
  `tools/run_curve_dragons.py --area01` adapter.

Protected `data/` and assets are unchanged. No rule-beat code, authored number,
card scoring assumption, tooltip definition or ordinary enemy targeting changed.
The Erupt presentation correction implements the approved marked-landing rule.

## Truth and forecast proof

`audit.py --stamps` extends atk-13's real production scene and observation
engine, with all original PASS/every-movement-destination checks. It visits
naturally generated boss rooms and helpers, preserves their rosters, layouts,
intent cycles and rules, and keeps the inherited high-Health non-attacking walk.
Its continued walks are not difficulty measurements. Separate counterfactual
Updraft/Yank actions use their existing data, legal targets, the production
card-aim surface/known-state path, rest-badge service and real resolution. They
do not alter the continued walk. These are individual action branches, without
paying or finishing a whole card; the real-card replay/capture checks the card
aiming and playback separately. Source displacement attempts, effective moves,
geometry checks and actual strike receipts are counted separately per move.

The reporter independently translates stored coordinates using recorded attack
anchors, compares real animation/effect strike receipts, and checks held red.
It distinguishes later declarations from the announcement already shown at
turn start. A Weaver can show an older pending wall and a new declaration at
once; those are distinct footprints, not one oversized strike receipt.

Completed logs, JSONL and production resumable saves are under:

- `/private/tmp/labyrinth_codex/area-01/feedback1/cursor-truth/` (11 boss targets, seeds
  1301/1302, 36 decision points; natural Bell Tender coverage comes from Cantor).
- `/private/tmp/labyrinth_codex/area-01/feedback1/cursor-helpers/` (Grub/Weaver, seeds
  1302/1310; same natural-room sampling convention as round 0).

The per-move and per-kind counts, follow-up matrices and raw paths are in
`results.md`. Alternatives from one decision are not independent played fights.

**Uncertainty limitation:** geometry agrees with the predicted and actual
attack anchors, respectively. Nine aimed-warning versus actual-strike differences
remain across 680 legal push/pull action branches, all relative and all carrying
the existing uncertainty disclosure; none are undisclosed. Fixed tiles agree
exactly. Fourteen branches have differing raw-action immediate source positions.
The union of those cases and the future-anchor differences was replayed through
real card aiming: all 15 show `unseen_ground_crossed`; 13 retain differing
immediate positions. Records are `feedback1/cursor-force-disclosure.json`.
The filter and its disclosure are preserved; no hidden terrain is revealed to
force a zero count. For a concrete reproduction, Tharokh seed 1301, point
`1301-6`, Updraft aimed at Bedrock Breath predicts `(1,4)` but hidden ground
stops the source at `(3,4)`. The stamp follows the respective source in both
simulations. This remains an explicit limit on the brief's strict
all-alternatives forecast-equality proof.

Gallows Roc is Anchored. Real push/pull attempts keep that immunity; effective
movement counts are zero where appropriate. The controlled rules fixtures also
exercise changed source positions directly, without presenting those synthetic
positions as natural push successes.

## Ladder

Three N=64 cohorts per boss are run with the same constructor inputs, RNG cells,
byte-unchanged policy v2 and original fight loop. The release baseline is the
pre-area-01 local-master snapshot (`fd6d24f274457557906e2a87794bd87569745d94`),
not an assertion about an independently downloaded storefront build. Round 0
was snapshotted before feedback-1 edits. Data/loadout inputs are identical.

The original nine natural release ladders supply the matched entries; only the
missing Cantor group uses the naturally recovered seed-24 entry from the prior
10–24 recovery. These are conditional boss-entry/loadout cohorts with repeated
RNG cells and the ladder's existing full-Health reset, not 64 distinct loadouts
or whole-run escape rates. No meas-07 tool is present in this checkout.
Raw records, exact runner commands and source metadata are under
`/private/tmp/labyrinth_codex/area-01/feedback1/{release,round0}/`.

## Focused checks

`run_checks.py` runs only the round-0 requested dragon/Guardian suites,
`threats_at_rest_test.gd`, atk-03 and atk-04, plus the coherent area rules suite.
The separate Marked and Burrow suites cover the reused mark and corrected Erupt
badge. Final exact result lines and log paths are in `results.md`.
No full Python or GDScript suite was run. No new Python test module was added;
the Python resource audit is still required and recorded.

The pre-existing Python Guardian measurement fixture failure from round 0
remains: `test_production_contains_only_the_chosen_cumulative_rungs`,
`tests/test_guardian_rules_measurement.py:186`, expects older enemy definitions,
including art_scale 1.15 versus unchanged master 1.03. Both the assertion and
protected data remain untouched. The focused Python rerun observed Dragon
`Ran 6 tests` / `OK`, and Guardian `Ran 11 tests` / `FAILED (failures=1)`
with this same failure. Logs are `feedback1/python-{dragon,guardian}-measurement.log`;
its matching round-0 baseline/current logs remain under
`/private/tmp/labyrinth_codex/area-01/checks/`.

## Proof for the design owner

No windowed run was attempted. The headless component proof loads the audited
saves, adds the existing Updraft to the debug hand, enters real card targeting,
checks the red while aimed, then plays the card and captures the production
strike receipt. This proves semantics, not native pixels or pointer handling.

Run the exact native cel commands from this worktree:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/area-01 && sh tools/atk13/area01/native_capture.sh /private/tmp/labyrinth_codex/area-01/feedback1/truth/tharokh-1301/repro/1301-10 tharokh bedrock_breath
cd /Users/borgerding/workspace/Labyrinth.worktrees/area-01 && sh tools/atk13/area01/native_capture.sh /private/tmp/labyrinth_codex/area-01/feedback1/truth/zekarion-1301/repro/1301-1 zekarion skybreak
```

The wrapper uses `visual_probe_runner.py`, the native Metal launcher, cel look,
1920×1080, 100% UI scale and a three-image proof contract. Each case emits
`<enemy>-<intent>_rest.png`, `_aimed.png`, `_strike.png`, semantic JSON and a
manifest under `/private/tmp/labyrinth_codex/area-01/feedback1/captures/`.
The expanded commands are also retained in `feedback1/native-proof.sh`.
No `inspection_fixture.py` installation is needed: the audited saves load in
the runner's isolated HOME; fixture preparation remains with the design owner.

The breath fixture predicts a two-tile slide and has one cell become impassable
through the existing Upheaval beat before contact; that cell correctly becomes
inert. The sky fixture retains its marked footprint while the source moves.
Both use a real production push, without synthetic source placement.

## TODO_DESIGN placeholders and chosen defaults

No TODO_DESIGN placeholder was needed. No player-facing default was authored.
The existing hidden-ground uncertainty above remains a reported proof limit.

Test/proof-only named defaults retain round-0 seeds, 36 decision points,
9999 audit Health, 0.75 walk probability, UP entry, proof time scale 64 and
uncapped FPS. Rule fixtures retain source `(5,3)`, hero `(2,4)`, displacement
`(0,1)`, 2000 Health, fuel witnesses `(3,4)` / `(6,5)` and the private nullable-save
path and `PROOF_PARTIAL_SAVE_PATH`. Core source-position changes are synthetic fixtures, not natural pushes.

New force branches use existing Updraft and Yank without changing their values.
Native cases append Updraft to the debug hand and reset the debug played-card
counter to zero. Existing 90 boot / 12 layout frames, pointer parking `(960,4)`,
2400 playback-frame guard and production contact timing are retained. The capture
has a 300-second guard and no renderer retries. Ladder recovery/input/RNG-stride
values remain unchanged; the three cohort drivers each use one worker. The uncertainty diagnostic drains shutdown for a named 0.5 seconds. Outputs
and HOME directories are task-local. These choices affect proof only.

## Open issues

- Owner-run native captures and visual inspection remain outstanding by sandbox
  contract; no real-renderer capture or independent visual judgement is claimed.
- Strict forecast equality retains the disclosed hidden-ground limitation above.
- The pre-existing Guardian Python fixture mismatch remains reported.
- Commit, peer review, full-suite merge checks, inspection fixture and publication
  remain assigned to the design owner. All feedback-1 implementation edits are uncommitted.
