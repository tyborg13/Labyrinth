# TXT-26 relic truth proof

The TXT-23 scenarios were copied into [probe_truth.gd](probe_truth.gd) and rerun on TXT-26. Eighteen scenarios cover all nineteen findings. The Discharge scenario covers both Copper-Shod Staff findings.

| TXT-23 finding | Decision | Observed outcome |
| --- | --- | --- |
| Iron Lung | **text now true** | `iron_lung_time` paid 8 Time for a 6-Time Overhead Smash and retained all Stoneskin. The approved text specifies the Health component of Empower. |
| Worldheart | **text now true** | `worldheart_midturn` gained 6 Stoneskin and dealt 3 damage during the player's turn with 0 Block. The new sentence applies to any Stoneskin gain. |
| Eclipse Mantle | **fixed in code** | `eclipse_tether` created Light 2 and kept the source and its visibility after the Illusion was destroyed. |
| Pilgrim Boots | **fixed in code** | `pilgrim_boots_blink` created two Light sources from the attacking Blink on Spur Vault. |
| Reinforced Shield | **fixed in code** | `reinforced_shield_move_block` gave 5 Block from a two-tile Catch the Wind with Stoneskin. |
| Shatterglass Prism | **kept by decision** | `frost_prism_footprint` still placed Rubble on 12 tiles for a 2×2 enemy footprint. |
| Overflow Censer | **text now true** | `overflow_censer_enemy_overwrite` ended with one Electrified tile. The approved sentence names the player as the source of the overwrite. |
| Hourglass Awl | **fixed in code** | `hourglass_awl_price` gave Pierce with the 6-Time surcharge and gave no Pierce with the 4-Time discount. Displayed and paid Time matched in both scenarios. |
| Winter's Spur | **kept by decision** | `winters_spur_rubble` still spent 2 Movement leaving Ice over Rubble. |
| Crowncoal Heart | **text now true** | `crowncoal_terrain_hit` destroyed an Outcrop without creating Fire. The new sentence requires a hit on an enemy. |
| Leaden Pommel | **fixed in code** | `leaden_pommel_price` added 1 Stagger with the 6-Time surcharge and added 0 with the 4-Time discount. |
| Hobnail Cleats | **fixed in code** | `hobnail_white_silence` dealt 8 damage to the selected enemy on Ice. |
| Waxen Effigy | **text now true** | `waxen_effigy_hidden` found 0 visible enemies and used the existing center-facing fallback at (3, 4). The hidden enemy was excluded from the ranking, as reflected by the approved qualifier. |
| Briar Vambrace | **fixed in code** | `briar_vambrace_move_block` gave 2 Block and Retaliate 1 from Catch the Wind. |
| Copper-Shod Staff network | **fixed in code** | `copper_shod_discharge` dealt 5 damage to the enemy reached from the virtual conductor. |
| Copper-Shod Staff immunity | **fixed in code** | `copper_shod_discharge` consumed the real Electrified tile and preserved both Health on the Illusion. |
| Hollow Puppet | **fixed in code** | `hollow_puppet_wall` moved the Illusion and preserved both Health through a wall collision. |
| Toll of the Late Bell | **kept by decision** | `toll_late_bell_extra_turn` still dealt 6 damage and queued the immediate player turn at 0 ahead of the enemy at 5. |
| Briar Throne | **fixed in code** | `briar_throne_zero_damage` triggered Static Mantle's Shock and left the Retaliate damage at 0. |

## Rules and preview coverage

- Illusion creation uses the normal lasting Light path for Blink decoys, Waxen Effigy, and cards. The probe also swaps a lit Illusion and checks that its source stays put. Pilgrim Boots checks Blink endpoints and both branches of the Move attack filter.
- A single card uses one Reinforced Shield bonus and one Briar Vambrace bonus, including the per-tile rider. Briar Throne's existing per-tile Block suppression still applies. A Fivefold Knot Brace proves that two Block actions share the bonus. Hollow Puppet checks wall, terrain, Fire entry and enemy collisions. The force suite also verifies the other Illusion's collision damage.
- Quicken, Whirling Sash and Empower fixtures cover the attack thresholds. The relics read the card-face price. Borrowed Time's banked-play waiver is applied separately at payment.
- White Silence uses the same damage adjustment in its hand display and hit resolver. No other current relic has the same family-wide damage wording. The neutral card heuristic excludes owned relic modifiers, so no neutral coefficient changes.
- Discharge can start on a virtual Outcrop and continue through an Illusion. The fixtures verify the damage, the immunity of both constructs and the absence of newly painted ground. Thunderclap also spares both kinds of construct on collision while the moved enemy still takes collision damage. Discharge's actual ground removals retain their existing event meaning.
- A Briar Throne fixture with Stoneskin absorbing a positive Retaliate hit grows by 1. The rider-only fixture leaves the damage unchanged.
- The probe checks the shared action forecast, the production held-card forecast and the relevant face values. The enemy-turn test compares a forecast with the committed reaction.

### Cards with two Block awards

The base catalog has no card with two authored Block actions. At five families, Fivefold Knot adds a second Block action to each of these 63 cards with an authored Block action.

Guarded Step, Patch Up, Brace, Prism Sight, Warded Advance, Cinch Straps, Parry Rhythm, Reprise, Trapdoor, Coffin Brace, Basalt Guard, Kite Bash, Chain Catch, Leather Roll, Undertaker Stand, Gravewind Step, Chain Lock, Mirror Flash, Dust Glide, Ember Guard, Nail Parry, Spike Check, Lodestone Reversal, Polar Guard, Witchglass Double, Undertow Guard, Field Suture, Unpick, Cinderweave Guard, Cinder Patch, Rimeplate Lock, Hoarfrost Shell, Static Pivot, Zephyr Feint, Kept Breath, Cinder Second, Smoke Bomb, Bone-Ward Charm, Blade Dance, Cinder Wall, Hoarfrost Wall, Incense Haze, Plant Pavise, Sun Flash, Vigil, Gate Gambit, Barbed Mail, Brace the Spear, Capacitor, Deflect, Eye of the Storm, Static Mantle, Sworn Oath, Ember Ward, Gale Ward, Hall of Mirrors, Hoarfrost Ward, Hotfoot, Shield Wall, Shrug Off, Static Ward, Stone Ward, and Windbreak.

A second award can also come from Catch the Wind's per-tile rider or another relic that adds a Block action before Fivefold Knot. The receipt applies across all awards on the same card.

## Text fit

The actual treasure-room builder, owned HUD and Chronicle show the approved description. The probe also checks the applicable dragon rewards. The Grimoire has a general Relics entry and no individual relic articles. Open-Eyed Pin is retired and resolves to Tallow Candle. The probe measures the edited historical text through the same builders.

Worldheart, Crowncoal Heart and Hollow Puppet needed 147 px where the offer label originally reserved 130 px. The offer builder now sizes the label to its content with the existing typography, margins and minimum size. The approved exact-copy ledger also supplies the test budget for the four changed descriptions above the historical 25-word ceiling, including Fivefold Knot. The protected relic catalog is unchanged.

## Reproduction

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/txt-26
python3 tools/godot_task_runner.py --task-id txt-26 --stream -- godot --headless --path . --script tools/txt26/probe_truth.gd
python3 tools/godot_task_runner.py --task-id txt-26 --stream -- godot --headless --path . --script tools/txt26/focused_suites.gd
LABYRINTH_CEL_LOOK=all TXT26_OUTPUT=/private/tmp/labyrinth_codex/txt-26 python3 tools/godot_task_runner.py --task-id txt-26 --stream -- godot --headless --path . --script tools/txt26/capture_relics.gd
/private/tmp/labyrinth_codex/txt-26/native.sh --dry-run
/private/tmp/labyrinth_codex/txt-26/native.sh
```

The last command needs the macOS window server. It prints a fresh output directory containing two exact 1920×1080 before images, two exact 1920×1080 and two exact 1280×800 after images for the director's five offers, plus the 12 text-fit captures and proof manifests. The baseline project is the sibling `mrg-14` checkout at the exact `codex/mrg-14` revision. The sibling `txt-25` is one report commit ahead of that revision.

## Chosen defaults

- The copied TXT-23 fixture uses seed 2304, a 9×9 room, a 24-Health hero and the original fixture positions and amounts. Additional forecast cases use named positions and reuse the same seeded room.
- The real treasure fixture uses seed 7321, three offers per row, Waxen Effigy as the sixth director offer, reduced-motion settling, three layout frames and a four-second reveal timeout. The layout measurement allows 0.5 px of rounding.
- Visual contracts inspect the middle offer region for a luma range of at least 20 and a standard deviation of at least 5. Resolution and UI scale come from the brief.

No `TODO_DESIGN_*` placeholders were needed.

## Files changed

| Area | Paths |
| --- | --- |
| Combat resolution | `scripts/combat_engine.gd`, `scripts/board_attack_rules.gd`, `scripts/common_relic_rules.gd`, `scripts/defense_relic_rules.gd`, `scripts/forced_relic_rules.gd`, `scripts/illusion_relic_rules.gd`, `scripts/maneuver_rules.gd`, `scripts/card_stay_rules.gd`, `scripts/retaliate_rules.gd`, `scripts/surface_card_rules.gd` |
| Pricing and previews | `scripts/game_data.gd`, `scripts/card_keyword_rules.gd`, `scripts/card_display_overrides.gd`, `scripts/card_display_dependencies.gd` |
| Treasure text fit | `scripts/run_scene.gd`, limited to content fitting for the relic offer description |
| Analytics | `spec/analytics.md` |
| Existing regression pins | `tests/dragon_rewards_test.gd`, `tests/suites/relic_suite.gd`, `tests/suites/relic_u1_suite.gd`, `tests/suites/relic_u6_suite.gd`, `tests/suites/destruction_preview_privacy_suite.gd`, `tests/text_budget_test.py` |
| Proof | `tools/txt26/` contains the three scripts and UID sidecars, three visual contracts, this report and the native runner. `/private/tmp/labyrinth_codex/txt-26/native.sh` launches the runner. |

## Observed checks

| Check | Result line | Evidence |
| --- | --- | --- |
| TXT-23 scenarios with TXT-26 expectations | `TXT26 truth probe PASS: 18 rerun cases matched, 0 failed` | `truth-final.log` |
| Forecasts | `TXT26 forecast comparisons: 45 resolver, 43 held-card` | `truth-final.log` |
| Focused relic, Illusion, Light, Retaliate, force/collision, Cost and preview suites | `TXT26 focused suites PASS: 7579 checks, 0 failures` | `focused-verified.log` |
| Light and Vision | `LIGHT AND VISION RULES: 75 checks, 0 failures` and `TEST RESULT: PASS` | `light-vision.log` |
| Card display | `CARD DISPLAY OVERRIDES TEST RESULT: PASS (16745 checks, 0 failures)` | `card-display.log` |
| Dragon rewards | `Dragon rewards, gifts, wallet recovery and relic hooks passed.` | `dragon-rewards.log` |
| Relic text fit at both sizes | `TXT26 text fit PASS: 36 offer layouts, 16 checked relic surface sets` | `fit-final.log`, `text_fit.json` |
| Native dry run | `TXT26 text fit PASS: 6 offer layouts, 0 checked relic surface sets` before and `TXT26 text fit PASS: 12 offer layouts, 0 checked relic surface sets` after | `native-dry-final.log`, `captures.AuSikn/{before,after}/text_fit.json` |
| Rules text lint | `Ran 3 tests in 0.062s`, `OK`, `PASS: Rules text lint (16 existing hits)` | `rules-lint.log` |
| UI identity lint | `Ran 25 tests in 5.747s`, `OK` | `ui-lint.log` |
| Exact text budget | `Ran 6 tests in 0.201s`, `OK` | `text-budget.log` |
| Python default group | `SELECTED MODULES: 23 of 59`, `Ran 196 tests in 30.435s`, `OK` | `python-default-verified.log` |
| Windows typed-array scan | `TYPED ARRAY SCAN: 23 scripts; 0 new; 6 pre-existing` | `typed-array-final.log` |

Evidence paths are relative to `/private/tmp/labyrinth_codex/txt-26`. Windowed PNGs and visual inspection are pending the director's native run.

The Python runner finished successfully. Its optional timing-cache update hit the read-only Git directory. Card-display teardown emitted signal-conversion and resource-cleanup diagnostics after the assertions ran. The windowed proof remains open.
