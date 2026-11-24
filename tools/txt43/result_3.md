# txt-43 round 3 verification

`TXT43 AUDIT: 137 rows, 0 False, 0 UNTESTED`. The starting merge is `d19a83cf4`, with both merges above round 2 `1b50aad4e` intact. Round 3 is uncommitted.

## Copy and truth changes

| Where | Before | After |
| --- | --- | --- |
| Refract Guard and enemy self-clears | `Remove Ice from your tile.` | `Removes Ice under this enemy.` |
| Field Brace | `Clears Fire, Ice and Electrified under the guarded unit.` | `Removes Fire, Ice and Electrified under the guarded unit.` |
| Swept path | `Within 1 tile of its path` | `Within 1 tile of this enemy's path` |
| Erupt Push | `Pushes each unit next to this enemy 1 tile away and moves any unit on its tile aside.` | `Pushes each unit adjacent to this enemy 1 tile away and moves any unit on its tile aside.` |
| Kindle | `Its Burst deals 2 more.` | `This enemy's Burst deals 2 more damage.` |
| Crystal Mantle | `Forms Crystal Mantle. Each direct damaging hit breaks one layer and prevents its damage; ground and damage over time bypass it.` | `Each Crystal Mantle layer prevents damage from 1 direct hit, then breaks.` |
| Charge move row and enemy badge | `At 3 Charge, this enemy's next attack is Arc Lash. Shock removes 1 Charge.` | `At 3 Charge, this enemy's next attack is Arc Lash.` |
| Night Coil move chip | `Night Coil puts out the Marked brazier. Enter that brazier's tile to relight the brazier before Eclipse.` | `Puts out the Marked brazier.` |

- The old audit classified the Lancer's Expend by token icon and action type. It gave `expend_self` a True verdict based on the resolver removing ground from the source, while accepting any displayed sentence. The updated rule checks the rendered actor and ground. The baseline sentence now yields `expend_wrong_subject` with a False verdict. The new sentence names the acting enemy and yields True. The whole-tooltip perspective review found nine moves with legitimate player address and zero remaining suspect second-person rows. [Audit and text diff](../../output/txt43/round3/diff.md) · [Resolver](../../scripts/combat_engine.gd#L5086)
- In the Refract Guard witness, Ice under the Lancer at `(2, 4)` disappeared and Ice under the hero at `(6, 4)` remained. The existing Erupt checks verified the central occupant moves aside and a side-adjacent unit is Pushed directly away once. Ember Hoarder's actual death Burst dealt 4 damage before Kindle and 6 afterward. The shared Kindle copy also updates Ember Tick. [Witness](../../output/txt43/round3/witness.log)
- The Crystal Mantle chip uses the existing glossary definition. Charge's Shock clause stays in its glossary and Grimoire article. Night Coil's tile hover still carries the original relight instructions. The witness checked the move chip and the separate brazier tooltip. Card Expend continues to use the original Card Panel Text. [Witness](../../output/txt43/round3/witness.log) · [Card export](../../output/txt43/round3/audit.log)

## Tests and probes

| Proof | Observed result |
| --- | --- |
| Actual move inventories | `TXT38 INVENTORY: PASS (44 creature pages, 137 move rows, 7 live controls)` and `TXT41 LIVE INVENTORY: PASS (137 Known Moves controls and combat intents)`. The inventories use the merged production Grimoire. [Exports](../../output/txt43/round3/inventories-after.log) |
| Witness and audit | `TXT43 ROUND 3 WITNESS: PASS`, `TXT43 AUDIT: 137 rows, 0 False, 0 UNTESTED`, and `TXT43 LIVE COPY: PASS (approved sentences, Razor Dive chips, Refraction offsets)`. [Witness](../../output/txt43/round3/witness.log) · [Audit](../../output/txt43/round3/audit.log) |
| Card widget | `TXT43 CARDS ROUND 3: PASS (309 catalog IDs, 9 source lists, byte-identical to the before export)`. Zero card hovers changed on the merged build, using the merged crd-33 exporter. [Audit](../../output/txt43/round3/audit.log) |
| Round 1 and 2 fixtures | `TXT43 STRING FIXTURES: 352 checks, 0 failures`, `SHORT CARD TOOLTIPS TEST RESULT: PASS (707 checks, 0 failures)`, `MRK01 MARKED TEST: PASS (69 checks, 0 failures)`, `Dragon committed patterns passed.`, `BOARD TILE TOOLTIPS: PASS checks=233 failures=0`, and `TXT43 STORMCOAL FIXTURES: 40884 checks, 0 failures`. [Copy](../../output/txt43/round3/string_fixtures.log) · [Short tooltips](../../output/txt43/round3/short_card_tooltips_test.log) · [Marked](../../output/txt43/round3/mrk01_marked_test.log) · [Dragon](../../output/txt43/round3/dragon_committed_patterns_test.log) · [Board tooltip](../../output/txt43/round3/board_tile_tooltip_test.log) · [Stormcoal](../../output/txt43/round3/stormcoal_fixtures.log) |
| Wording fixtures | `BRS01 FOCUSED RESULT: PASS (4882 checks; 0 failures)` and `FIX-03 PROBE CONTRACT: PASS (5 states, 1920x1080, UI scale 100%)`. [BRS-01](../../output/txt43/round3/brs01_test.log) · [FIX-03](../../output/txt43/round3/fix03.log) |
| Rules text and UI lints | `PASS: Rules text lint (16 existing hits)`. UI identity reported `Ran 25 tests in 4.510s` and `OK`. [Rules text](../../output/txt43/round3/rules-text.log) · [UI identity](../../output/txt43/round3/ui-identity.log) |
| Python default | `SELECTED MODULES: 23 of 59`, `Ran 196 tests in 32.624s`, `OK`. The optional Git timing-cache write then reported `[Errno 1] Operation not permitted`. [Python](../../output/txt43/round3/python-default.log) |
| txt-37 page check | `TXT37 PAGES: PASS (headless, 44 creatures)`. Updated the page-count pin from 18 to the merged catalog count. [Page check](../../output/txt43/round3/txt37-pages.log) |
| Native dry run | `TXT43 NATIVE PROBE: PASS (headless, 4 combat hovers, 8 Grimoire pages)`. `TXT43 TOOLTIP LOOP: pull_card frame=3 full opacity`. Each requested row was fully inside the detail viewport. The Hookwind image contract checks the loop area itself. The round 2 black panel measured a luma range of 6 and standard deviation of 1.31 in that area. [Round 2 frame](../../output/txt43/native.7VRAqx/gallows_roc_hookwind_1920x1080.png) · [Dry run](../../output/txt43/round3/native-dry-run.log) |

The Guardian Rules run reported `FAIL (693 checks, 1 failures)` for the existing Choir badge assertion expecting `linked tiles`. EN-06 reported `FAIL (136 checks, 1 failures)` for its existing Retaliate glossary-equality assertion on both the starting merge and round 3. The updated Charge assertions passed. Both pre-existing assertions were preserved. [Guardian Rules](../../output/txt43/round3/guardian_rules_test.log) · [EN-06 baseline](../../output/txt43/round3/en06-baseline.log) · [EN-06 current](../../output/txt43/round3/en06_enemies_test.log)

Godot emitted its macOS certificate-loader message during startup. The final inventory runs exited successfully.

## Proof for the design owner

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/txt-43 && tools/txt43/native.sh
```

The command writes the following PNGs and the capture manifest under `output/txt43/native.*/`, with the cel look on at 1920×1080 and 100% UI scale. Windowed proof is pending. The headless receipts used `output/txt43/native.PAziSD/` as the planned output directory.

| Capture | PNG |
| --- | --- |
| Arc Bolt hover | `arc_thrall_arc_bolt_1920x1080.png` |
| Hookwind at full loop opacity | `gallows_roc_hookwind_1920x1080.png` |
| Razor Dive intent | `vaeloryx_razor_dive_1920x1080.png` |
| Groundsplit after an Outcrop died | `craghide_after_outcrop_1920x1080.png` |
| Gust Shrike · Flying and Dive | `grimoire_gust_shrike_1920x1080.png` |
| Frostglass Lancer · Refract Guard | `grimoire_frostglass_lancer_1920x1080.png` |
| Craghide · Groundsplit | `grimoire_craghide_1920x1080.png` |
| Burrow Grub · Erupt | `grimoire_burrow_grub_1920x1080.png` |
| Ember Hoarder · Kindle | `grimoire_ember_hoarder_1920x1080.png` |
| Storm Capacitor · Charge | `grimoire_storm_capacitor_1920x1080.png` |
| Iskaldra · Crystal Mantle | `grimoire_iskaldra_1920x1080.png` |
| Grave Surgeon · Field Brace | `grimoire_grave_surgeon_1920x1080.png` |

## Changed files and chosen defaults

- Move copy lives in `scripts/action_icon_library.gd`, `scripts/enemy_mechanics/capacitor_view.gd`, and `scripts/enemy_mechanics/kindle_view.gd`. The pinned BRS-01, EN-06, and FIX-03 strings in `tests/` follow that copy. The merged data files are unchanged.
- The audit, witness, sweep, canonical card-export routing, and capture changes live in `tools/txt43/`. The merged-build page count is pinned in `tools/txt37/pages.gd`.
- Proof fixtures use the existing STA-01 arena, Ice on the Lancer's start and neighboring tiles, and an adjacent lethal hit for the Ember Hoarder comparison. Page capture uses a 24 px scroll inset, four layout frames, and the existing txt-37 one-pixel geometry tolerance. The Hookwind probe waits up to four seconds for the real loop's own fade threshold. Its 224×126 loop-region contract uses a minimum luma range of 15 and standard deviation of 2. These values affect proof only.

## Report-only wording sweep

Scanned 137 catalog and 137 live rows, including the 7 focused controls and the swept-path receipt.
Reviewed explicit player address in 9 distinct moves. 0 rows need second-person referent review.

| Row | Rule | Surfaces | Current tooltip |
| --- | --- | --- | --- |
| `TODO_DESIGN_burrow_grub_erupt` | avoid `its` | Grimoire row chip, combat row chip, focused live chip | `Pushes each unit adjacent to this enemy 1 tile away and moves any unit on its tile aside.` |
| `TODO_DESIGN_cinder_droplet_hiss_back` | avoid `its` | Grimoire row chip, combat row chip | `Retreat`<br>`This enemy moves up to 1 tile away from its target.` |
| `TODO_DESIGN_cinder_droplet_hiss_back` | avoid `its` | combat intent | `Retreat`<br>`This enemy moves up to 1 tile away from its target.`<br>`Block`<br>`Block absorbs damage until the start of the holder's next turn.` |
| `TODO_DESIGN_ember_hoarder_scurry` | avoid `its` | combat intent | `@pattern(cross:origin) When this enemy dies, this enemy Bursts 4, leaving Fire.`<br>`Retreat`<br>`This enemy moves up to 2 tiles away from its target.` |
| `TODO_DESIGN_ember_hoarder_scurry` | avoid `its` | Grimoire row chip, combat row chip | `Retreat`<br>`This enemy moves up to 2 tiles away from its target.` |
| `TODO_DESIGN_frostglass_lancer_refract_guard` | avoid `its` | Grimoire row chip, combat row chip | `Retreat`<br>`This enemy moves up to 1 tile away from its target.` |
| `TODO_DESIGN_frostglass_lancer_refract_guard` | avoid `its` | combat intent | `Retreat`<br>`This enemy moves up to 1 tile away from its target.`<br>`Block`<br>`Block absorbs damage until the start of the holder's next turn.`<br>`Removes Ice under this enemy.` |
| `TODO_DESIGN_gloam_stalker_fade` | avoid `there` | Grimoire row chip, Known Moves, combat intent, combat row chip | `This enemy Blinks behind you, or to another tile adjacent to you if there is room, then Ambushes on this enemy's next turn.` |
| `TODO_DESIGN_gust_shrike_hover` | avoid `its` | Grimoire row chip, combat row chip | `Retreat`<br>`This enemy moves up to 2 tiles away from its target.` |
| `TODO_DESIGN_gust_shrike_hover` | avoid `its` | combat intent | `Retreat`<br>`This enemy moves up to 2 tiles away from its target.`<br>`Block`<br>`Block absorbs damage until the start of the holder's next turn.` |
| `TODO_DESIGN_harrier_retreat_step` | avoid `its` | Grimoire row chip, combat row chip | `Retreat`<br>`This enemy moves up to 2 tiles away from its target.` |
| `TODO_DESIGN_harrier_retreat_step` | avoid `its` | combat intent | `Retreat`<br>`This enemy moves up to 2 tiles away from its target.`<br>`Block`<br>`Block absorbs damage until the start of the holder's next turn.` |
| `TODO_DESIGN_hoarfrost_seer_withdraw` | avoid `its` | Grimoire row chip, combat row chip | `Retreat`<br>`This enemy moves up to 2 tiles away from its target.` |
| `TODO_DESIGN_hoarfrost_seer_withdraw` | avoid `its` | combat intent | `Retreat`<br>`This enemy moves up to 2 tiles away from its target.`<br>`Block`<br>`Block absorbs damage until the start of the holder's next turn.` |
| `TODO_DESIGN_hollow_mimic_recede` | avoid `its` | Grimoire row chip, combat intent, combat row chip | `Retreat`<br>`This enemy moves up to 2 tiles away from its target.` |
| `TODO_DESIGN_lightning_wisp_blinding_arc` | avoid `its` | Grimoire row chip, combat row chip | `Retreat`<br>`This enemy moves up to 1 tile away from its target.` |
| `TODO_DESIGN_lightning_wisp_blinding_arc` | avoid `its` | combat intent | `Retreat`<br>`This enemy moves up to 1 tile away from its target.`<br>`Ranged`<br>`Deal 4 damage to a target within Range and line of sight, or to a target on Electrified tiles connected to one in Range and line of sight.`<br>`if Electrified used:`<br>`Shock`<br>`Shocked units can't attack on their next turn.` |
| `TODO_DESIGN_slag_mortar_lob_slag` | multiple sentences on one body line | Known Moves, combat intent | `@pattern(cross:hero) On your tile. On this enemy's next turn, this enemy hits each Marked tile and leaves Fire.` |
| `TODO_DESIGN_vaeloryx_eye_of_storm` | avoid `its` | Grimoire row chip, combat row chip | `Retreat`<br>`This enemy moves up to 3 tiles away from its target.` |
| `TODO_DESIGN_vaeloryx_eye_of_storm` | avoid `its` | combat intent | `Takes half Stagger.`<br>`Retreat`<br>`This enemy moves up to 3 tiles away from its target.`<br>`Deal 8 damage in this attack's area.`<br>`How far this attack reaches, in tiles, counted without diagonals.`<br>`Deal 4 damage to an adjacent target.` |
| `TODO_DESIGN_veilbound_acolyte_shroudstep` | avoid `its` | Grimoire row chip, combat intent, combat row chip | `Retreat`<br>`This enemy moves up to 2 tiles away from its target.` |
| `TODO_DESIGN_warden_bulwark` | avoid `every`, avoid `grant` | combat intent | `Block`<br>`Block absorbs damage until the start of the holder's next turn.`<br>`Grants Block to every other living enemy.` |
| `TODO_DESIGN_warden_bulwark` | avoid `every`, avoid `grant` | combat row chip | `Grants Block to every other living enemy.` |
