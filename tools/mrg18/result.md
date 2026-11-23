# Candidate 7 integration

The four requested source deltas are composed, in order, in the working files of `codex/mrg-18`. The branch head is `33d6d09f22c7d846358accccfb7125e6cc43d90f` (candidate 6). The director records the merge parents and runs the native inspection. The proposed parents passed `MRG-18 APPROVED ANCESTRY: PASS (4 requested tips, 0 forbidden subjects)`. [Composition log](/private/tmp/labyrinth_codex/mrg-18/composition.log) · [Complete changed-file inventory](/private/tmp/labyrinth_codex/mrg-18/changed-files.txt)

| Order | Approved tip | Three-way base | Intended merge subject |
| --- | --- | --- | --- |
| 1 | `93ce8fa7b` | `8b5494403` | Merge codex/release 93ce8fa7b (gfix-32, gfix-36, pol-59..66; owner approved polish-batch-1123/1123b) |
| 2 | `5fc49329c` | `a0094c780` | Merge codex/pol-68 (owner approved polish-batch-1123c) |
| 3 | `dda1a033c` | `93ce8fa7b` | Merge codex/pol-69 (owner approved polish-batch-1123c) |
| 4 | `c20d6c02b` | `a753ba8a5` | Merge codex/pol-74 (owner approved shop-inspection) |

## Conflict rules

1. **Opening aim.** `scripts/line_opening_aim.gd` stays deleted. `scripts/area_target_aim.gd` selects by visible hit count from POL-56’s targetable set. For attack lines with equal hit counts, `_score` takes the minimum Manhattan distance from the hero to the struck footprint tiles. Directions are visited with the authored direction first, so a full tie preserves it. Surface cards retain POL-56’s occupied-footprint scoring and manual Rotate still holds at the same center. The POL-62 baseline switch is gone from aim, deck fitting and the launcher. POL-62’s proof uses the shared helper’s classification and independently measures line damage, proximity and utility surface occupancy. Its crate and box sweep moves to the center before rotating, so POL-56’s automatic aim on center change can run before the test starts.
2. **RunScene and playback.** The textual conflict in `RunScene._exit_tree` keeps candidate 6’s acquisition, contact, Ice and Blink cleanup and then resets the objective dock. POL-68’s two badge hunks apply alongside the release changes. The shared file retains the action caption, map fade, Pack and gear focus, hand tint, objective and boss HUD, and restored Continue framing. Candidate 6 card panels, intent text and combat contact calls remain in place. In `CombatPacing.decorate`, the retained popup call keeps `IMPACT_DAMAGE_KEY` from POL-71 and shares the new retention helper with POL-69’s enemy Fire turn-start entry. `status_tick_feedback.gd` retains candidate 6’s active status-icon handling and adds the enemy Fire helper. The release-era Bleed bookkeeping stays retired.
3. **Separate deck and card title widgets.** The 12 px fallback lives in the 190 px UI and Character Deck rows. POL-70’s card-widget measurements and title motion keep their existing implementation. POL-74 composes on the POL-70 shelf by adding hover and focus inspection for both Browse and Sell and retaining the approved Ember amount on the Sell button.
4. **Export.** All six presets carry the source union of 65 patterns. The 13 paths added to each candidate 6 list appear below.
5. **Pinned assets.** The union has 4,408 pins. Release retains the approved `defense_heal_casts.png` pin, so its PNG, import sidecar and density exclusion enter the union. The 28 hash clashes all resolve to the files in candidate 6. These include seven tile-burst sheets, seven shot sheets and fourteen icon PNGs. Nine provenance files passed the union check with their existing working contents. [Full hash decisions and filter validation](/private/tmp/labyrinth_codex/mrg-18/logs/export-assets-union.log)

POL-68 and release both contain independently cherry-picked SCN-01 tool source. The SCN-01 trees at `db9985a9b` and `060674b1a` are byte-identical. The add/add resolutions use that payload to combine SCN-02’s production save preparation, room-stage receipts, retired shot numbering and input paths with POL-68’s root Window option, geometry accounting, menu cases and batch driver. `census.gd.uid` and `census_input.gd.uid` use the release sidecars. `native.sh` retains both launch modes, `result.md` retains both histories and `shots.json` retains the extended catalog and the reserved shot numbers. `tools/pol63/`, `tools/pol65/measure.gd` and `tools/pol69/census_measure.gd` use the combined census signatures and viewport setup. The objective rule, pre-battle, skill-tree and objective-suite overlaps merged textually.

The [proof alignment patch](proof-alignment.patch) records the smallest integration fix and verifier updates outside the merge hunks. It advances the GFIX-32 manual map sample past automatic map entry, tests 14 px while checking the existing badge anchors and padding, uses an active Frostbite popup reference in the POL-69 fixture and tests POL-74’s final Sell wording and computed value. The production hunk preserves candidate 6's held rectangle for a hidden Objective when a combat fixture has no Objective. A visible Objective still waits for POL-63’s framed home. The shrink-and-focus regression then passed with its original assertions. The uncommitted proof tree already includes the patch.

## Each preset’s additional export patterns

```text
assets/art/effects/defense_heal_casts.png
scenes/card_widget.tscn
scripts/board_hud_budget.gd
scripts/character_menu_view.gd
scripts/dragon_boss_library.gd
scripts/emaciated_man_cutout/presentation.gd
scripts/enemy_identity.gd
scripts/game_data.gd
scripts/large_map_backdrop.gd
scripts/post_combat_reward_sequence.gd
scripts/run_engine.gd
scripts/status_tick_feedback.gd
scripts/ui_skin.gd
```

## Proof for the design owner

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/mrg-18 && LABYRINTH_CEL_LOOK=all /private/tmp/labyrinth_codex/mrg-18/native.sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/mrg-18 && LABYRINTH_CEL_LOOK=all /private/tmp/labyrinth_codex/mrg-18/native.sh --dry-run
```

The launcher prepares the line-aim and census fixtures locally, captures through `tools/visual_probe_runner.py` and prints output folders. The exact 1920×1080 SubViewport renders at 100% UI scale. The native groups cover the line tie, Cinderburst’s area aim and POL-56’s utility area aim, Skills headers and selected links, boss bar, objective dock, both header badges, Scavenger Browse and Sell hover, enemy turn-start Fire and the Kindle fight. Scavenger and Fire also retain their approved enlarged detail crops. The primary Kindle still is `kindle/kindled_full.png`. For a fresh checkout without the temporary wrapper, run `./tools/mrg18/native.sh` from the same worktree. The sandbox ran the dry proof. Native PNGs are due at the director’s inspection.

## Chosen defaults

- The launcher uses fresh output folders, the approved fixture seeds 83, 84 and 7262026, the approved 60 Hz Kindle proof clock, and a 180-second proof watchdog.
- The POL-69 comparison fixture uses an equal-size synthetic Frostbite loss to exercise the active status-number path. The engine-generated Fire samples still verify the real pass-turn playback for both the hero and an enemy.
- The census comparison validates the relevant control geometry headless. The proof contracts require the expected image names, sizes and board-region luminance variation where applicable.

## Design placeholders

No new design placeholders. POL-68’s approved report data retains the existing `TODO_DESIGN_dialogue_deck` measurement in `tools/pol68/design_todos.json`.

## Headless proof

| Check | Observed result |
| --- | --- |
| Combined native dry run | `MRG-18 DRY RUN PASS (7/7 proof groups)` · `MRG-18 AREA AIM: PASS (Cinderburst)`. [Dry-run log](/private/tmp/labyrinth_codex/mrg-18/logs/native-complete.log) · [Headless receipts](/private/tmp/labyrinth_codex/mrg-18/headless.p0x8c92n) |
| GFIX-32 | `GFIX-32 AFTER HEADLESS: 0 failures`. All nine Settings checks passed. |
| GFIX-36 | `MRG-18 GFIX36 FRAMING: PASS (6 Continue or walk-in routes match fresh entry)` · `TEST RESULT: PASS — committed save/resume boundary matrix` · `TEST RESULT: PASS — main menu resume safety`. |
| POL-56 and POL-62 | `ROTATABLE CARD AIM: PASS` · `POL62 after: PASS (0 failed checks)`. Seed 84 Volt Surge, Molten Reach and Thunderline selected south with `(2, 1)` versus east at `(2, 2)` for pointer, keyboard and controller. The crate and box forecasts and HUD paint samples changed on the same frame. All five reported names fitted at 12 px in both Deck views. |
| POL-59 and POL-60 | `POL59 CAPTURE: PASS (after, 126 planned PNGs, 0 errors)` · `POL60 headless after: 0 failures`. |
| POL-61 | `POL-61 AFTER HEADLESS: 0 fixture failures` · `RETAINED HAND CONTENT TEST RESULT: PASS` · `CARD DRAW HAND FLOW TEST RESULT: PASS`. The three retained faces stayed at alpha 0.56000 at the proxy-to-live handoff in normal motion, and reduced motion applied its immediate tint. [Frame traces](/private/tmp/labyrinth_codex/mrg-18/pol61/frames.jsonl) |
| POL-63 | `POL63 STATE PROOF: PASS; 60 rows; 0 failures` for the deadline, `POL63 STATE PROOF: PASS; 70 rows; 0 failures` for Door and Continue, and `POL63 STATE PROOF: PASS; 15 rows; 0 failures` for the focused objective and treasure catalog. |
| POL-65 | `MRG-18 POL65 BOSS BAR: PASS (21 layouts with matching rectangles, budget orders and idle behavior)` · `BOSS HEALTH PREVIEW TEST: PASS (0 failures)`. |
| POL-66 | `POL66 after HEADLESS: PASS (4552 checks, 0 failures)` · `SKILL TREE SUITE: PASS (387 checks, 0 failures)`. |
| POL-68 | `COMBAT HUD BUTTONS TEST: PASS` · `COMBAT HUD BADGES TEST: PASS`. Both map runs reported `105 overlapping pairs, 113626 sampled points` with no misrouted activation. Grimoire and Loadout matched the approved badge rectangles `[1812, 9, 21, 25]` and `[1737, 9, 20, 25]`. |
| POL-69 | `MRG-18 SKILL HEADERS: PASS (5 at 17 px)` · `POL69 gameplay proof: 0 failures`. The enemy’s Fire tick showed `−3` with `surface_fire` and the ground beat owned impact. |
| POL-74 | `POL74 SHOP READABILITY AFTER: PASS` · `SCAVENGER SHOP SUITE: PASS (5845 checks, 0 failures)` · `SCAVENGER CLOSED SHOP LIFETIME: PASS`. |
| Candidate 6 Kindle | `FX-38 PROFILES PASS (three actors, death, bonus reset)` · `FX-38 BASE SOURCE PASS (profiles 0-11: same sampling, grading and output, zero Kindle gain)` · `FX-38 AFTER PLAN PASS (18 captures)` · `PERF165 LIFECYCLE: PASS (0 failures; 34 warmed recipes)`. |
| Candidate 6 card titles | `MRG-17 TITLE CENSUS PASS (8 contexts, 2440 names)` · `MRG-18 POL70 TITLE METRICS: PASS (14 shots match the candidate 6 receipt)` · `CARD SUMMARY FIT RESULT: PASS (5447 checks, 0 failures, 650 samples)`. |
| Candidate 6 playback | `POL71 gameplay proof: 0 failures` · `RULE VALUE GUARD: PASS (8 scenarios, Health, Block, statuses and surface events identical)` · `PREVIEW HANDOFF: PASS (contradicted Expose pruned at commit, matching previews held without a second pop or extra refresh)` · `MRG-18 POL71 BADGE GEOMETRY: PASS (2 expected POL-68 rectangles)` · `RECT COMPARISON: PASS (441 matched paths, maximum edge delta 0.0000 px)`. |
| Candidate 6 enemy intent | `POL73 HEADLESS LAYOUT after 1920x1080: 5 surfaces, 0 failures.` · `POL73 ROSTER after: 44 enemies, 6 Guardians, 137 intents, 422 checks, 0 failures.` · `THREATS AT REST TEST RESULT: PASS (15645 assertions; includes compass suite)`. |
| Earlier effects | `GFIX-34 VERIFY: 308 checks, 0 failures` · `MRG-15 REFLECTION VERIFY: 68 checks, 0 failures` · `FX-12 VERIFY: 120 checks, 0 failures` · `FX-17 VERIFY: 132 checks, 0 failures` · `FX-14 AFFECTED SUITES: PASS (1112 checks, 0 failures)` · `FX-14 VERIFY: PASS (1998 checks, 0 failures)` · `FX-20 VERIFY: PASS (172 checks, 0 failures)` · `FX-20 VERIFY: PASS (3374 checks, 0 failures)` · `FX-29 VERIFY: 4258 checks, 0 failures` · `FX-36 VERIFY PASS (621 checks, 0 failures)`. |
| Earlier proof plans and copy | `MRG-16 NATIVE DRY RUN PASS` · `FX-35 NATIVE DRY RUN: PASS (2 before/after pairs)` · `FX-35 BAKE IDENTITY: PASS (27398800 non-Shadow palette-index bytes, 40 rows x 13 frames x 7 sizes, zero row shifts)` · `TXT26 truth probe PASS: 18 rerun cases matched, 0 failed` · `TXT26 focused suites PASS: 7579 checks, 0 failures` · `TXT27 FOCUSED SUITES: 91337 checks, 0 failures` · `TXT28 WITNESS RESULT: PASS (54 witnesses, 0 failures)` · `TXT28 RULES SUITES: PASS (656 checks, 0 failures)` · `TXT30 WITNESSES: 4 true, 0 failed`. |
| Static and Python | `MRG-16 EXPORT FILTERS: PASS (6/6 presets)` · `MRG-17 PIN UNION: PASS (4408 pins, 28 hash clashes)` · `MRG-17 PROVENANCE AND DENSITY: PASS (9 provenance files and 1 registry)` · pin test `Ran 1 test in 13.285s`, `OK` · UI lint `Ran 25 tests in 5.302s`, `OK` · `PASS: Rules text lint (16 existing hits)` · default group `SELECTED MODULES: 23 of 59`, `Ran 196 tests in 32.781s`, `OK`. |

[Named verifiers and focused tests](/private/tmp/labyrinth_codex/mrg-18/logs) · [Objective and boss measurements](/private/tmp/labyrinth_codex/mrg-18/approved-proof-aligned) · [Candidate 6 regression receipts](/private/tmp/labyrinth_codex/mrg-18/candidate6)

## Open issues

- Candidate 6’s inherited `FX-23 VERIFY: FAIL (258 checks, 7 failures)`, `FX-35 WIDTH TARGET: 0/14 within 45–55%`, `TXT27 WITNESSES: 43 passed, 1 failed` and `GLOSSARY TEST RESULT: FAIL (6218 checks, 4 failures)` reproduced. The independent Fade check passed all 42 assertions. The inherited assertions remain in place.
- The optional locked-hand cache renderer probe reached its cap with the dummy display. The required retained-hand and turn-start tests passed headless.
- The Python runner’s optional timing-cache write was denied by read-only Git metadata after the default group passed. The director still owns the merge record and renderer inspection.
