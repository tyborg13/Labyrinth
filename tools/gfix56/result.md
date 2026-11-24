# gfix-56 demo gate repair

The 11 failures in the gate's top-level count comprise seven failed program suites and four in-process assertions, including the Guardian roll-up. The table expands the program suites into their individual failed assertions. The baseline is `output/gfix56/gate_8cfb865a7_godot.log`.

| Suite | Failed assertion | Approved merge and cause | Old pin or fixture | New pin or fixture |
| --- | --- | --- | --- | --- |
| special_encounter_test | Release regression forces the production fallback branch | `c66b16e6a` eco-03 added a `specials_placed` check before the placement call | `if revision >= 6 and not Specials.place_from_catalog(` | Match `if revision >= 6 and not layout.get("specials_placed", false) and not Specials.place_from_catalog(` |
| special_encounter_test | Assertion-free revision 6 fallback places an enabled special in section 1 | `c66b16e6a` stale match left the normal roll in place | Exactly one special, with fallback unforced | Exactly one special, with fallback forced |
| special_encounter_test | Assertion-free revision 6 fallback places an enabled special in section 2 | `c66b16e6a` stale match left the normal roll in place | Exactly one special, with fallback unforced | Exactly one special, with fallback forced |
| special_encounter_test | Assertion-free revision 6 fallback places an enabled special in section 3 | `c66b16e6a` stale match left the normal roll in place | Exactly one special, with fallback unforced | Exactly one special, with fallback forced |
| special_encounter_test | Assertion-free revision 6 fallback places an enabled special in section 4 | `c66b16e6a` stale match left the normal roll in place | Exactly one special, with fallback unforced | Exactly one special, with fallback forced |
| special_encounter_test | Assertion-free revision 6 fallback places an enabled special in section 5 | `c66b16e6a` stale match left the normal roll in place | Exactly one special, with fallback unforced | Exactly one special, with fallback forced |
| save_resume_boundary_test | 3 — live analytics must preserve wallet settlement ordering | `e3b27e209` gfix-50 made the locked profile ineligible, bypassing the pending-prompt checkpoint before wallet settlement | Locked default profile | Services unlocked and tutorial complete, so a blocked prompt checkpoint still prevents wallet settlement |
| save_resume_boundary_test | 1 — Save & Quit retains the heirloom fallback or active Abandon run and all its held Embers | `e3b27e209` gfix-50 made the Dragon fixture ineligible for a prompt fallback | Locked default profile for both variants | Unlocked, tutorial-complete profile for the Dragon variant |
| save_resume_boundary_test | 2 — only the checkpoint holds the choice (successful departure variant) | `e3b27e209` gfix-50 made the pending prompt ineligible | Locked default profile | Unlocked, tutorial-complete profile |
| save_resume_boundary_test | 2 — departure settles the confirmed heirloom from the checkpoint | `e3b27e209` gfix-50 made the source prompt ineligible | Locked default profile | Unlocked, tutorial-complete profile |
| save_resume_boundary_test | 2 — only the checkpoint holds the choice (blocked departure variant) | `e3b27e209` gfix-50 made the pending prompt ineligible | Locked default profile | Unlocked, tutorial-complete profile |
| save_resume_boundary_test | 2 — blocked departure retains the confirmed choice | `e3b27e209` gfix-50 made the source prompt ineligible | Locked default profile | Unlocked, tutorial-complete profile |
| main_menu_resume_test | 1 — an unprocessed heirloom fallback wins over the completion receipt | `e3b27e209` gfix-50 made the terminal checkpoint ineligible for a pending prompt | Locked default profile | Unlocked, tutorial-complete profile |
| main_menu_resume_test | 2 — an advanced descent counter must preserve a pending prompt | `e3b27e209` gfix-50 made the pending prompt ineligible before the counter comparison | Locked default profile | Unlocked, tutorial-complete profile with the same counter sequence |
| hoarder_test | Natural Hoarder uses normal pre-battle entry | `c66b16e6a` eco-03 moved the first Hoarder beyond the starting reveal | Teleport to seed 1 parent `(7,-5)` | Follow the seed 2 approach to the section 1 Hoarder at `(3,-2)` |
| hoarder_test | Natural Hoarder prepared layout matches input | `c66b16e6a` eco-03 left the teleported run in room mode | Prepare after a refused move | Prepare after ordinary pre-battle entry |
| hoarder_test | Natural Hoarder combat starts at large | `c66b16e6a` eco-03 left the teleported run without a battle | Begin from the empty preparation | Begin from the matching preparation |
| deck_element_reward_test | Lamplighter trophy fallback exhausts the Fire legendaries in the initial offer | `c66b16e6a` eco-03 moved the encounter on the source map, changing the coordinate used in the reward RNG | Reward seed `9590`, room `(22,-19)` | Reward seed `25171`, room `(22,-18)`. Exact initial offer stays `[wildfire_halo, salamander_heart, capacitor]` |
| glossary_test | Keyword panel count unchanged: stoke | `85f1e5217` crd-33 added a separate target-specific damage panel | 2 | 3 |
| glossary_test | Keyword panel order unchanged: stoke/1 | `85f1e5217` crd-33 inserted a second All Enemies panel before the surface panel | `surface_fire` at index 1 | `all_enemies` at index 1, `surface_fire` at index 2 |
| glossary_test | Keyword panel count unchanged: white_silence | `85f1e5217` crd-33 added a separate target-specific damage panel | 3 | 4 |
| glossary_test | Keyword panel order unchanged: white_silence/2 | `85f1e5217` crd-33 inserted a second All Enemies panel before Stagger | `stagger` at index 2 | `all_enemies` at index 2, `stagger` at index 3 |
| gear_02_rules_test | The real first Umbra Guardian grants the Lantern with the trophy | `c66b16e6a` eco-03 moved the first Umbra Gallows Roc and changed its approach | Seed `90211`, `(1,-1) → (2,-2) → (0,2)` | Same seed, `(1,-1) → (0,1) → (2,-2)` |
| gear_02_rules_test | Guardian reward offer attributes the Lantern | `c66b16e6a` stale walk left no Guardian victory | Old walk reaches no reward | New walk reaches the trophy and Lantern |
| gear_02_rules_test | Staged combat_ended includes the Lantern when the transition board has no inventory award | `c66b16e6a` stale walk left the Guardian battle empty | Old walk supplies no Guardian transition board | New walk supplies the Guardian transition board, with the Lantern inferred from the victory |
| gear_02_rules_test | Staged combat_ended attributes the Lantern to the victory | `c66b16e6a` stale walk left no award to stage | Old walk reaches no Guardian victory | New walk stages the Guardian victory with the Lantern |
| gear_02_rules_test | Live combat_ended logs precisely one Lantern | `c66b16e6a` stale walk left no award for the live combat event | Old walk supplies an empty battle | New walk logs the settled Guardian victory |
| gear_02_rules_test | Live reward_offered attributes the Lantern | `c66b16e6a` stale walk left no award for the live reward event | Old walk supplies no Guardian reward | New walk logs the trophy reward and Lantern |
| guardian_suite | Groundsplit identifies surviving outcrops | `a42d30aa7` txt-43 rewrote the Groundsplit range phrase | `Each Outcrop · within 2` | `Within 2 tiles of each Outcrop` |
| guardian_suite | Guardian encounter, relic and versioned map contracts | `a42d30aa7` stale Groundsplit pin propagated to the roll-up | Roll-up receives the Groundsplit failure | Roll-up passes with the approved phrase |
| fix_03_suite | library_erupt preserves authored summary text | `a42d30aa7` txt-43 labeled the Erupt rider as applying to the enemy itself | `Erupt 6 · Push 1 · Rubble · Expose 2` | `Erupt 6 · Push 1 · Rubble · Self: · Expose 2` |
| fix_03_suite | intent_erupt preserves authored summary text | `a42d30aa7` txt-43 added the self label to the Erupt tokens also used by the Burrow intent | `Erupt 6 · Push 1 · Rubble · Expose 2` | `Erupt 6 · Push 1 · Rubble · Self: · Expose 2` |

## Diagnostic receipts

- Forced special placement passes for every section of revisions 6, 7 and 8 with assertions removed. Revisions 7 and 8 both run the existing section, door and layout checks on the resulting web.
- The unlocked profile is derived from the existing opening-boon fixture and preserves the default counter. The live blocked-checkpoint test still emitted `["combat_ended", "run_ended"]` once and passed its unchanged wallet-order assertion. The confirmed departure cases printed `profile=duelist_rapier checkpoint=` and `profile= checkpoint=duelist_rapier`.
- The old Hoarder selection on revision 8 is seed `1`, section 2, room `(7,-2)` off parent `(7,-5)`. The fixture wrote `current_room` and `cleared` without visiting the parent. The Hoarder had `revealed=false` and `sealed=false`, and both rooms were at depth 7. `RunEngine.available_moves` skips the unrevealed target at `scripts/run_engine.gd:910`. The resulting empty move list makes `move_to_pre_battle` return at line 1054. A normal walk to that same parent returned legal moves `[(7,-2), (7,-1)]` and entered `pre_battle` at `(7,-2)`. The focused fixture uses the shorter section 1 route to exercise the same production entry, preparation, combat and catch reward.
- The old Hoarder preparation left `combat_state` empty. Its three downstream script errors were missing `enemies` in `hoarder_index`, out-of-bounds index 0 in `CombatEngine._damage_enemy`, and missing `cards` in `_natural_entry`. The Lantern stale route likewise produced a missing `enemies` error in `_won_battle`.
- Revision 7 reproduced the original Lamplighter offer using the current card data, including bal-05 `23152865a` and bal-06/07 `f553556d6` and `652f6261f`. At the same reward seed, revision 8 changed the Shadow encounter room from `(22,-19)` to `(22,-18)` and rolled `[wildfire_halo, skybreak_current, seekers_mark]`. The new seed recovered the exact old offer, which exhausts the Fire legendary pool. It rerolled to `[firebrand_volley, pyroclasm, dust_devil]`. The fixture still owns the trophy before combat to exercise the card fallback.
- The glossary override changes only Stoke and White Silence. Sleet Squall's crd-33 follow-up hover changes its body text and has the same ordered panel identities and body-line counts.
- On seed `90211`, revision 7 still walks the old route and awards `cracked_lantern` with the Gallows Roc trophy on the current build, which includes tut-01 `79db06dcf`. On revision 8, after `(1,-1)` the legal exits are `[(0,1), (-1,1)]`, so `move_to_room` rejects `(2,-2)` at `scripts/run_engine.gd:933` on the second leg. The old destination `(0,2)` is now a campfire. The new route enters the same Guardian at Umbra stage `fringe` with no prior award. Victory grants the Lantern with `galehook_talon`, and all six original award and analytics assertions pass.
- The live Groundsplit summary changed from `Melee 7 · Each Outcrop · within 2` to `Melee 7 · Within 2 tiles of each Outcrop`. The existing exclusion of Spire remains in the assertion.

## Proof receipts

All focused logs are under `output/gfix56/`. The seven programs ran individually through `tools/godot_task_runner.py` with `--task-id gfix-56 --timeout 600 --stream` and `godot --headless --script tests/<suite>.gd`.

| Log | Result line |
| --- | --- |
| `special_encounter_test.log` | `SPX special encounter suite: 0 failures` |
| `save_resume_boundary_test.log` | `TEST RESULT: PASS — committed save/resume boundary matrix` |
| `main_menu_resume_test.log` | `TEST RESULT: PASS — main menu resume safety` |
| `hoarder_test.log` | `Hoarder suite: 0 failures` |
| `deck_element_reward_test.log` | `DECK ELEMENT REWARDS: 0 failures` |
| `glossary_test.log` | `GLOSSARY TEST RESULT: PASS (6222 checks, 0 failures)` |
| `gear_02_rules_test.log` | `GEAR-02 RULES: PASS (569 checks, 0 failures)` |
| `in_process.log` | `GFIX-56 GUARDIAN AND FIX-03: PASS (257 checks, 0 failures)` |
| `rules_text_lint.log` | `PASS: Rules text lint (16 existing hits)` |

The in-process runner invokes the same Guardian and FIX-03 suite entry points as the full gate. All eight Godot proof logs contain zero `SCRIPT ERROR` lines. The eleven changed GDScript files passed individual headless `--check-only` runs through the task runner. The logs are `output/gfix56/parse_*.log`. The map, route and copy diagnostics are in `output/gfix56/map_and_copy_v2.log` and `output/gfix56/routes.log`. Godot generated the runner's adjacent UID in `output/gfix56/write_uid.log`.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/gfix-56 && python3 tools/godot_task_runner.py --task-id gfix-56 --timeout 600 --stream -- godot --headless --script tools/gfix56/in_process.gd
```

## Chosen defaults

- Hoarder fixture seed `2`, destination `(3,-2)`, and approach `(1,-1) → (0,1) → (2,-2) → (1,2) → (-2,2) → (-2,0)`.
- Lantern fixture approach on seed `90211` through `(1,-1) → (0,1) → (2,-2)`.
- Lamplighter fixture reward seed `25171`. The source map still comes from the existing skill fixture seed `73021`.

## Open issues

No `BLOCKER_*` or `TODO_DESIGN_*` items. The original gate's main-menu Grimoire teardown error and save/resume leaked-resource diagnostics still appear in the corresponding passing focused runs. The task helper reported an empty stored contract for this worktree. Verification used the supplied brief. The full release gate remains for the design owner. The renderer capture and playable inspection fixture are inapplicable to these test-only changes.
