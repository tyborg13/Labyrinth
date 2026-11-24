# txt-43 round 2 verification

`TXT43 AUDIT: 137 rows, 0 False, 0 UNTESTED`. Round 1 is `e246d9468`. Round 2 changes are uncommitted. All four design items are resolved.

## Requirements

1. **Stormcoal Crucible.** Hero Lightning targeting, previews, and resolution opt in to Fire conduction. Enemy relays, components, Chain, and their forecasts use the Electrified-only default. The Fire hover and electrical presentation still reflect the hero's relic. The seven enemy relay tooltips retain the approved line-of-sight wording. [Conductivity](../../scripts/board_surface_rules.gd#L43) · [Shared attack plan](../../scripts/combat_engine.gd#L12336) · [Enemy relay](../../scripts/combat_engine.gd#L12820)
2. **Fixed force.** The actual strike resolved along a source-relative cardinal line. The four existing tooltips stay in place. Hookwind's off-axis pull stopped level with the source under the shared Pull rule. Mourning Hook's one-tile-wide line had no off-axis victim. [Force selection](../../scripts/combat_engine.gd#L7282) · [Pull stop](../../scripts/combat_engine.gd#L7406) · [Lane geometry](../../scripts/guardian_combat_rules.gd#L553)
3. **Groundsplit.** The tooltip now reads `Hits each Marked tile.` The 22 held tiles stayed marked and all 22 resolved after one Outcrop died. The hero on a tile outside the surviving Outcrop's footprint lost 7 Health. [Held resolver](../../scripts/guardian_combat_rules.gd#L421)
4. **Field Brace.** The tooltip now reads `Clears Fire, Ice and Electrified under the guarded unit.` Separate fixtures cleared each of the three elements. Each retained the Rubble underlay and the Surgeon's own Fire. [Ground removal](../../scripts/board_surface_rules.gd#L118)
5. **Fade, Lay the Choir, Gust, and Burrow.** Fade uses the approved `adjacent` sentence including the Ambush clause carried before round 1. Lay the Choir uses `this enemy's target`. The Gust rule uses its general sentence. The audit cites R10 and the Anchored and Burrowed definitions for the exceptions. The Gust fixture moved the hero downwind and left both exceptions in place. The buried Grub also remained unselectable for all six direct action types tested. [Fade and Burrow copy](../../scripts/action_icon_library.gd#L350) · [Gust and Anchored definitions](../../data/glossary.json) · [R10](../../spec/card_text_style.md#rules-templates)

### Stormcoal receipts

The identical Fire strip was `(4, 4)`, `(5, 4)`, and `(6, 4)`. The relay fixture exchanges the shooter and target at the same positions for the hero control.

| Case | Forecast | Impact |
| --- | --- | --- |
| Enemy Arc Bolt, round 1 | All three Fire tiles appeared in the forecast and marks. | Hero lost 3 Health, and all three Fire tiles disappeared. |
| Enemy Arc Bolt, round 2 | Forecast and marks were empty. | Hero lost 0 Health, and all three Fire tiles remained. |
| Hero Chain Bolt, both rounds | `(4, 4)` was targetable and the plan used all three Fire tiles. | The enemy at `(6, 4)` lost 4 Health, and all three Fire tiles disappeared. |
| Enemy Lightning with Chain and a Fire bridge, round 2 | Only the struck tile `(4, 4)` appeared. | Hero lost 0 Health and the Fire bridge remained. Changing just the bridge to Electrified restored all three forecast tiles and 3 hero Health loss. |

All seven ordinary enemy relay moves still hit via Electrified with Stormcoal equipped and lost their relay when the entry tile's line of sight was blocked. The new witness fails on round 1 specifically on the Fire-only enemy relay and the enemy Fire bridge cases. [Round 1 witness](../../output/txt43/round2/witness-baseline.log) · [Round 2 witness](../../output/txt43/round2/witness.log)

### Force receipts

Source `(4, 4)`. Every attack was declared upward. Coordinates come from actual strike resolution.

| Move | On-axis victim | Off-axis trial |
| --- | --- | --- |
| Hooked Sweep | `(4, 3)` → `(4, 2)`, 6 HP lost | `(5, 3)` → `(6, 3)`, 6 HP lost |
| Hookwind | `(4, 1)` → `(4, 3)`, 3 HP lost | `(5, 3)` → `(4, 3)`, 3 HP lost |
| Razor Pinion | `(4, 3)` → `(4, 1)`, 6 HP lost | `(5, 3)` → `(7, 3)`, 6 HP lost |
| Mourning Hook | `(4, 1)` → `(4, 2)`, 3 HP lost | `(5, 3)` outside the single lane, 0 HP lost |

[Full force receipts](../../output/txt43/round2/force-motion.log)

## Changed files

- Runtime · `scripts/board_surface_rules.gd`, `scripts/combat_engine.gd`, `scripts/board_pixel_surface_field.gd`, and `scripts/board_surface_presentation.gd`.
- Copy · `scripts/action_icon_library.gd`, `data/glossary.json`, and `data/grimoire.json`.
- Contracts · `spec/analytics.md`, `spec/card_balance_heuristic.md`, `tools/card_heuristic.py`, the `pla02_grimoire_pages.json` and `txt20_rules_copy.json` fixtures, and the EN-02, MRK-01, and STA-01 copy suites.
- Proof · `tools/txt43/audit.py`, `inventories.sh`, `native_probe.gd`, `witness.gd`, the new `witness_2.gd` and `stormcoal_fixtures.gd` with sidecars, and this report.

## Tests and probes

| Proof | Observed result |
| --- | --- |
| Inventory and audit | `TXT38 INVENTORY: PASS (44 creature pages, 137 move rows, 7 live controls)`, `TXT41 LIVE INVENTORY: PASS (137 Known Moves controls and combat intents)`, `TXT43 AUDIT: 137 rows, 0 False, 0 UNTESTED`, and `TXT43 LIVE COPY: PASS (approved sentences, Razor Dive chips, Refraction offsets)`. [Audit](../../output/txt43/round2/audit.log) · [Diff with evidence](../../output/txt43/round2/diff.md) |
| Card and relic hovers | `TXT43 CARDS ROUND 2: PASS (309 catalog IDs, 9 source lists, byte-identical to round 1)`. Zero additional card hovers changed. Stormcoal's authored relic description is unchanged. `BOARD TILE TOOLTIPS: PASS checks=233 failures=0` includes the Fire hover's Stormcoal line. [Export](../../output/txt43/round2/audit.log) · [Board tooltip test](../../output/txt43/round2/board_tile_tooltip_test.log) |
| Focused witness | `TXT43 ROUND 2 WITNESS: PASS`. [Log](../../output/txt43/round2/witness.log) |
| Existing Stormcoal and surface suites | `TXT43 STORMCOAL FIXTURES: 40884 checks, 0 failures`. Ran `surface_relic_suite.gd`, `relic_suite.gd`, `relic_u2_suite.gd`, `black_sun_dial_suite.gd`, `card_keywords_w3_suite.gd`, `card_playability_summary_suite.gd`, and `board_surface_suite.gd`. `surface_cpu_performance_benchmark.gd` reported `"semantic_errors":[]`. [Suites](../../output/txt43/round2/stormcoal-fixtures.log) · [CPU semantic result](../../output/txt43/round2/surface-cpu.log) |
| Round 1 string and integration fixtures | `TXT43 STRING FIXTURES: 352 checks, 0 failures`. `SHORT CARD TOOLTIPS TEST RESULT: PASS (707 checks, 0 failures)`. `MRK01 MARKED TEST: PASS (69 checks, 0 failures)`. `Dragon committed patterns passed.` [Strings](../../output/txt43/round2/string-fixtures.log) · [Short tooltips](../../output/txt43/round2/short_card_tooltips_test.log) · [Marked](../../output/txt43/round2/mrk01_marked_test.log) · [Dragon](../../output/txt43/round2/dragon_committed_patterns_test.log) |
| Lints | `PASS: Rules text lint (16 existing hits)`. UI identity reported `Ran 25 tests in 5.691s` and `OK`. [Rules text](../../output/txt43/round2/rules-text.log) · [UI identity](../../output/txt43/round2/ui-identity.log) |
| Python default | `SELECTED MODULES: 23 of 59`, `Ran 196 tests in 27.231s`, `OK`. Tests passed before the optional timing-cache write under Git metadata reported `[Errno 1] Operation not permitted`. [Log](../../output/txt43/round2/python-default.log) |
| Native dry run | `TXT43 NATIVE PROBE: PASS (headless, 4 capture states)`. Craghide showed one surviving Outcrop, 22 displayed Marked tiles, and the embedded `Hits each Marked tile.` popup. [Dry run](../../output/txt43/round2/native-dry-run.log) |

## Open issues outside the audit

- Guardian Rules reports `FAIL (693 checks, 1 failures)` for the pre-existing Lay the Choir badge assertion that expects `linked tiles`. [Current log](../../output/txt43/round2/guardian_rules_test.log)
- The Stormcoal reward hover's containing probe, `ui_32_event_reward_tooltip_probe.gd -- --semantics-only`, reports `UI-36 semantics 1920x1080 at 1.00: 4 event choices, 2 failures`. The failures reproduce on round 1 and concern the Whispering Well and Sealed Sarcophagus column layout. Bloodletter's Basin is the Stormcoal case and emitted no assertion failure. [Round 1](../../output/txt43/round2/stormcoal-reward-baseline.log) · [Round 2](../../output/txt43/round2/stormcoal-reward-semantics.log)
- The standalone Stormcoal surface material, visual, dense, cache-equivalence, and electric-equivalence probes require renderer frames. Windowed PNG proof remains pending.

## Proof for the design owner

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/txt-43 && tools/txt43/native.sh
```

The launcher remains unchanged and prints each of these 1920×1080 PNG paths at 100% UI scale under a new `output/txt43/native.*/` directory.

- `arc_thrall_arc_bolt_1920x1080.png`
- `gallows_roc_hookwind_1920x1080.png`
- `vaeloryx_razor_dive_1920x1080.png`
- `craghide_after_outcrop_1920x1080.png`

## Chosen defaults

The proof uses a centered source for full force travel, one three-tile Fire strip, a 20-Health fixture Illusion, and a synthetic Chain reach of 1 for the enemy bridge check. These are fixture-only values. Capture settings reuse round 1.
