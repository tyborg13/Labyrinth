# txt-28 candidate 4 card truth results

The [txt-25 witnesses](../txt25/truth.md) ran against the uncommitted txt-28 worktree. The copied scenarios retain their original aims. F01 and F14 also compare the combat forecast with committed resolution. The runtime summary was `TXT28 WITNESS RESULT: PASS (53 witnesses, 0 failures)`. The per-case log is at `/private/tmp/labyrinth_codex/txt-28/witness.log`.

| Finding | Card | Outcome | Rerun evidence |
| --- | --- | --- | --- |
| F01 | Lodestone Reversal | **fixed in code** | The enemy stopped at (3,4) and only (3,4) gained Electrified. A blocked Pull kept both the enemy and Electrified on (4,4). Both forecasts matched. |
| F02 | Ember Guard | **text now true** | Ember Guard placed Fire on the adjacent enemy's tile. The distant enemy's tile stayed clear. |
| F03 | Ember Ward | **text now true** | Ember Ward placed Fire on the adjacent enemy's tile. The distant enemy's tile stayed clear. |
| F04 | Static Ward | **text now true** | Static Ward placed Electrified on the hero and the adjacent enemy. The distant enemy's tile stayed clear. |
| F05 | Stone Ward | **text now true** | Stone Ward placed Rubble on the adjacent enemy's tile. The distant enemy's tile stayed clear. |
| F06 | Cinderweave Guard | **text now true** | Each of the two adjacent enemies lost 2 Health. Fire covered the four adjacent tiles. |
| F07 | Bottled Gale | **text now true** | Both adjacent enemies moved 3 tiles away from the hero without selecting a target. |
| F08 | Caltrops | **fixed in code** | The item entered the consumed pile. The aimed stone tile stayed and gained Rubble. The face reads “Consume.” and keeps Tile and Range 2. |
| F09 | Powder Keg | **fixed in code** | The card raised a Powder Keg with sight through its tile. The Range panel names the Powder Keg. |
| F10 | Grounding | **text now true** | Grounding removed Electrified from an empty tile and gained 6 Stoneskin. Its Expend panel uses the generic removal sentence. |
| F11 | Spike Mantle | **text now true** | Spike Mantle removed Rubble from an empty tile and gained 4 Stoneskin. Its Expend panel uses the generic removal sentence. |
| F12 | Seek the Light | **kept by decision** | The hero Blinked to Light five tiles away. The card sentence gives the Light option. |
| F13 | Sleet Squall | **kept by decision** | The enemy was selected at distance 3 in line of sight and took 3 damage after the Push put it at distance 5. |
| F14 | Snare Coil | **fixed in code** | Fetter Spikes forecast and dealt 6 Collision damage before Snare Coil applied Immobilize. An already Immobilized enemy still took 12. |
| F15 | Skybolt | **fixed in code** | The enemy lost 8 Health across a wall. The Ranged panel requires visibility and Range. |
| F16 | Thunderstone | **fixed in code** | The enemy lost 5 Health across a wall. The Ranged panel requires visibility and Range. |
| F17 | Meteorfall | **fixed in code** | The saved mark hit the enemy at distance 5 for 8. The damage chip stays in its original face row and explains Cinder Marks. The Ranged panel is gone. |
| F18 | Meteorfall | **text now true** | Choosing the distance-4 center Marked tiles at distances 3, 4 and 5. |
| F19 | Meteorfall | **text now true** | The Range panel describes aiming. The distance-5 tile was Marked from the legal distance-4 center. |
| F20 | Cinder Wall | **text now true** | A distance-2 Cinder Wall aim left Fire at distances 1 through 4. |
| F21 | Frost Lane | **text now true** | A distance-3 Frost Lane aim left Ice at distances 2 through 4. |
| F22 | Lamp Oil | **text now true** | A distance-3 Lamp Oil aim left Fire at distances 2 through 4. |
| F23 | Earthen Rampart | **text now true** | A distance-2 Earthen Rampart aim raised Outcrops at distances 1 through 3. |
| F24 | Grapple | **text now true** | Grapple Blinked beside a lone Powder Keg. The destination check also admits other terrain kinds. See the design placeholder. |
| F25 | Jaw Trap | **fixed in code** | With Alchemist’s Retort, the distance-2 hit dealt 3 damage. The face and inspection agree. All seven item cards with damage and Range numerals passed under both relevant relics individually and together. |
| F26 | Frost Circuit | **kept by decision** | The chosen Ice at distance 1 connected to the hidden enemy at distance 4, which took 2 damage. The card sentence gives the connected hits. |

## Acceptance evidence

- Lodestone's aimed board published the Electrified creation event at (3,4). The matched before capture fixture published the event at the original (4,4) aim. The balance heuristic scored Lodestone Reversal **3.85** at Time 5, with 1.13 offense, 0.92 control, 1.25 defense, 0.29 surfaces and 0.25 synergy. The existing surface and collision event schemas cover both fixes.
- Snare Coil's fresh and already Immobilized targets matched the forecast for Health, position, Immobilize and collision damage.
- The item audit covered Nail Bomb, Pitch Firebomb, Frost Snare, Storm Jar, Jaw Trap, Grave Dust Satchel and Powder Keg. With Alchemist's Retort, Jaw Trap still had Range 2 and its Pack row read “Deal 3 damage at Range 2 and Immobilize.”
- Skybolt and Thunderstone read the targeting action's `ignore_los` flag. Meteorfall retains its damage icon, number and row arrangement. Powder Keg and ordinary Outcrops select their own Range panels from the terrain action.
- The semantic inventory checked all 15 director edits, nine generated card articles, the Expend article, the new panels and markup across 305 live card entries and their exported variants. The combat capture fixture also checks that the production Scavenger and reward card widgets resolve the same rules and keyword entries. Icon and diagram faces already representing the area use their existing compositions.
- The Caltrops face had `Tile [range] 2 / [consume] Consume tile. Leave [surface_rubble] Rubble and [expose] Expose 2 each enemy hit.[diagram 1]` before. It now shows `Tile [range] 2 / [consume] Consume. Leave [surface_rubble] Rubble and [expose] Expose 2 each enemy hit.[diagram 1]`.

## Design placeholder

`TODO_DESIGN_grapple_terrain` is in `probe_claims.gd`. Grapple accepts a destination beside a visible enemy or any live terrain entry. Current producers create `crag_outcrop`, `powder_keg`, `wooden_crate` and `wooden_box`. The witness also accepted `crate`, `raised_cover`, `barrel`, `dragon_spire`, `bramble`, `ice_pillar` and an arbitrary fixture kind. Legacy spires migrate to Outcrops and legacy Bramble and Ice Pillar terrain is removed during save loading. Wooden boxes are the extra terrain kind produced in current gameplay. The director's Grapple sentence stays in use.

## Headless results

| Check | Observed result |
| --- | --- |
| Candidate witnesses | `TXT28 WITNESS RESULT: PASS (53 witnesses, 0 failures)` |
| Forced movement, maneuvers, board surfaces and card surface rules | `TXT28 RULES SUITES: PASS (656 checks, 0 failures)` |
| Panel text | `CARD PANEL TEXT TEST RESULT: PASS (2210 definitions, 7758 panels, 15745 checks, 0 failures)` |
| Short tooltips | `SHORT CARD TOOLTIPS TEST RESULT: PASS (707 checks, 0 failures)` |
| Card display and item text | `CARD DISPLAY OVERRIDES TEST RESULT: PASS (16744 checks, 0 failures)` |
| Card faces | `FACE FIT CHECKS: 18992 checks, 0 failures` and `TEST RESULT: PASS` |
| Copy and markup | `TXT28 COPY: PASS (15 director edits, 9 card articles, 305 cards scanned, both new panel templates)` |
| Typed arrays | `TXT28 WINDOWS TYPED ARRAYS: PASS (4 modified GDScript files, 4 new proof scripts)` |
| Rules lint | `PASS: Rules text lint (16 existing hits)` |
| UI identity lint | `Ran 25 tests in 5.524s` and `OK` |
| Python default group | `SELECTED MODULES: 23 of 59`, `Ran 196 tests in 33.121s` and `OK` |
| Before capture dry-run | `TXT28 DRY RUN before 1920x1080: PASS (7 inspections, 0 PNGs, 0 failures)` |
| After capture dry-run | `TXT28 DRY RUN after 1920x1080: PASS (20 inspections, 0 PNGs, 0 failures)` |
| Compact capture dry-run | `TXT28 DRY RUN after 1280x800: PASS (20 inspections, 0 PNGs, 0 failures)` |

## Proof for the design owner

Run the native captures at 100% UI scale with the requested exact-size SubViewports.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/txt-28 && /private/tmp/labyrinth_codex/txt-28/native.sh
```

The launcher sets `LABYRINTH_CEL_LOOK=all`, checks that the sibling txt-25 game files match `codex/mrg-14`, and prints a fresh `/private/tmp/labyrinth_codex/txt-28/native.XXXXXX` folder. It uses the following windowed commands. Here `$worktree` is the absolute txt-28 path and `$output` is the printed folder.

```sh
export LABYRINTH_CEL_LOOK=all
python3 tools/visual_probe_runner.py --project "$worktree/../txt-25" --task-id txt-28 --no-headless --display-driver macos --audio-driver Dummy --timeout 120 --expect-size 1920x1080 --proof-contract tools/txt28/before.contract.json --result-manifest "$output/before-1920x1080/manifest.json" "$worktree/tools/txt28/capture.gd" -- before 1920x1080 "$output/before-1920x1080"
python3 tools/visual_probe_runner.py --project "$worktree" --task-id txt-28 --no-headless --display-driver macos --audio-driver Dummy --timeout 120 --expect-size 1920x1080 --proof-contract tools/txt28/after.contract.json --result-manifest "$output/after-1920x1080/manifest.json" "$worktree/tools/txt28/capture.gd" -- after 1920x1080 "$output/after-1920x1080"
python3 tools/visual_probe_runner.py --project "$worktree" --task-id txt-28 --no-headless --display-driver macos --audio-driver Dummy --timeout 120 --expect-size 1280x800 --proof-contract tools/txt28/after.contract.json --result-manifest "$output/after-1280x800/manifest.json" "$worktree/tools/txt28/capture.gd" -- after 1280x800 "$output/after-1280x800"
```

Compare `before-1920x1080/caltrops.png` with `after-1920x1080/caltrops.png`. The matched Lodestone aim is `lodestone_aimed.png` in each capture folder. The dry-run used `/private/tmp/labyrinth_codex/txt-28/native.yty1fe` and measured actual Godot label wrapping, viewport bounds, visible text and the board's surface preview event. The logs and semantic inventory are under `/private/tmp/labyrinth_codex/txt-28`.

## Chosen defaults

- The headless witnesses reuse the txt-25 Surface Test room, seed 501, 40-Health crawlers and named board coordinates. A synthetic terrain kind tests Grapple's unrestricted lookup.
- The capture fixture uses one card in hand and a Quick Stab in the draw pile so Frost Lane retains Draw 1. It uses reduced motion, the existing inspection panel at (24,144), the production hand keyword stack and an offscreen 250×352 composition for the Scavenger and reward checks.
- The capture fixture waits five settling frames with a 600-frame boot limit. Each multi-card windowed invocation has a 120-second timeout.

## Open issues

- The sandbox has no macOS window server. The three windowed capture passes and visual inspection are for the design owner.
- The compact Lodestone keyword stack extends 11 px above the 1280×800 viewport on both candidate 4 and txt-28. The 1920×1080 stack and the edited sentences and new panels fit in the headless checks at the two resolutions.
- Both worktrees emitted headless diagnostics for missing imported animation textures and a macOS certificate lookup. The card display suite also emitted a teardown signal error. The focused assertions and capture dry-runs reported the results above. The Python suite passed and could not update its Git timing cache under the read-only metadata policy.
