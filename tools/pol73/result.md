# pol-73 floating enemy intent audit

The floating label uses the existing move-row builder in both regular-enemy and boss layouts. The existing inspection tooltip still uses the combined rows. Move titles, amounts, icons, conditional riders and the layout code are unchanged.

## Removed rows

The audit covered all 44 production enemy definitions, including the six Guardians, and 137 authored intents. The table lists each enemy with an authored passive row in the baseline. The conditional Light row applies across the roster.

| Enemy | Removed entry | Where the player still finds it |
| --- | --- | --- |
| Ember Tick | Burst 4, cross diagram and death-Burst sentence | Combat Burst trait badge tooltip, pre-battle inspection with the cross diagram, and blast-tile glow when aiming a lethal hit |
| Ember Hoarder | Burst 4, cross diagram and death-Burst sentence | Combat Burst trait badge tooltip, pre-battle inspection with the cross diagram, and blast-tile glow when aiming a lethal hit |
| Cinder Ooze | Splits 2 and the death-split sentence | Combat Splits trait badge tooltip and pre-battle inspection |
| Tharokh, the Worldspine | Steadfast | Pre-battle Steadfast trait row |
| Vyraketh, the Cinder Crown | Steadfast | Pre-battle Steadfast trait row |
| Vaeloryx, the Hollow Gale | Steadfast | Pre-battle Steadfast trait row |
| Iskaldra, the Rime Tyrant | Steadfast | Pre-battle Steadfast trait row |
| Zekarion, the Raging Tempest | Steadfast | Pre-battle Steadfast trait row |
| Noctyrax, the Last Eclipse | Steadfast | Pre-battle Steadfast trait row |
| Any enemy projected to start its turn in Light | Light and Expose 2 forecast | Light keyword definition and the existing inspection-tooltip data |

Ember Hoarder’s Kindle still shows Burst +2 because Kindle increases its future Burst on that turn. Hollow Mimic’s already-active Retaliate was already confined to its combat status badge. Echo still shows Retaliate 3 when Echo will give the Mimic that status.

The six Guardians are Ashen Reaver, Rimejaw, Storm Cantor, Gallows Roc, Craghide and Last Lamplighter. None had an authored passive row in the floating label. Storm Cantor’s Lightning Storm beat stays with Peal, which triggers it. Scheduled battlefield-rule auras, Warband Command, Stoneback Mite’s death Rubble and terrain Burst had no floating rows at baseline. Every removed rule already had an inspection or keyword surface, so the unit added no details rows.

## Capture proof

The existing txt-27 renderer capture shows Ember Tick’s Burst 4 icon, cross and sentence above Scuttle in the Movement Test Room. The new probe reuses the exact encounter fixture and trap and enters the real board hover path. [Existing txt-27 capture](/private/tmp/labyrinth_codex/txt-27/captures.ybw4Nk/after-1920x1080/ember_tick_burst.png)

The headless baseline was reproduced before the production edit. The completed launcher was dry-run against both worktrees. Ember Tick’s rendered-row input was Burst 4 plus the diagram and sentence, followed by Scuttle with Move 3 and melee 2. Afterward the Scuttle rows contain Move 3 and melee 2. Cinder Ooze’s Smolder Slide keeps Move 1, melee 5 and Fire. Ember Hoarder’s Kindle keeps Burst +2. Hollow Mimic’s Shade Bolt keeps damage 4 and range 4 while Retaliate 3 remains inspectable. The Tick’s combat trait tooltip still returns the existing Burst sentence. [Baseline layout](/private/tmp/labyrinth_codex/pol-73/baseline-layout/layout.json), [before dry-run layout](/private/tmp/labyrinth_codex/pol-73/captures.a3v14j/before/layout.json), [after dry-run layout](/private/tmp/labyrinth_codex/pol-73/captures.a3v14j/after/layout.json)

Run this command on the director’s Mac to produce the native proof.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/pol-73 && bash /private/tmp/labyrinth_codex/pol-73/native.sh
```

The launcher checks the sibling `codex/txt-27` baseline at `35b683909`, sets `LABYRINTH_CEL_LOOK=all`, and uses `tools/visual_probe_runner.py`. Each revision emits four 1920×1080 frames and four 2× intent crops under the printed capture folder. The candidate also emits `ember_tick_details_frame.png`. Each PNG path is printed on its own line.

## Verification

| Check | Result |
| --- | --- |
| Before layout | `POL73 HEADLESS LAYOUT before 1920x1080: 4 surfaces, 0 failures.` |
| After layout | `POL73 HEADLESS LAYOUT after 1920x1080: 5 surfaces, 0 failures.` |
| Roster before | `POL73 ROSTER before: 44 enemies, 6 Guardians, 137 intents, 422 checks, 0 failures.` |
| Roster after | `POL73 ROSTER after: 44 enemies, 6 Guardians, 137 intents, 422 checks, 0 failures.` |
| Intent previews | `TXT27 SUITE enemy intent previews: 41 checks, 0 failures` |
| Intent continuity | `TXT27 SUITE enemy intent continuity: 1918 checks, 0 failures` |
| Enemy Burst | `TXT27 SUITE enemy Burst: 145 checks, 0 failures` |
| Guardians | `TXT27 SUITE guardians: 151 checks, 0 failures` |
| Battlefield rules | `TXT27 SUITE battlefield rules: 629 checks, 0 failures` |
| Burst and playback | `BRS01 FOCUSED RESULT: PASS (4708 checks; 0 failures)` |
| Hollow Mimic | `MIM01 TEST RESULT: PASS (40 checks, 0 failures)` |
| Threats and compass | `THREATS AT REST TEST RESULT: PASS (15645 assertions; includes compass suite)` |
| UI identity lint | `Ran 25 tests in 5.591s`, `OK` |
| Rules text lint | `PASS: Rules text lint (16 existing hits)` |

The roster check also verified the two Burst actors’ exact glow tiles with a lethal aim and no hover. The run logs and temporary roster check are in the [proof folder](/private/tmp/labyrinth_codex/pol-73). The headless scene emitted macOS certificate and missing generated-texture diagnostics on the baseline and candidate. The layout checks completed successfully. Native rendering and visual inspection are pending because the implementation sandbox has no window-server access.

## Chosen defaults

- Reused the txt-27 run seed 7262026, reduced motion, Ember Tick fixture and Fire trap, and the Gallows Roc startup fixture.
- Used the same isolated Movement Test Room for Cinder Ooze, Ember Hoarder and Hollow Mimic. Hollow Mimic used Shade Bolt with the existing Retaliate 3 applied by its rule helper.
- Used a 600-frame startup budget, five settling frames, eight pixels of crop padding, nearest-neighbor 2× crops, and a 180-second native runner timeout. Placed the already-built combat tooltip at (1170, 355) in the debug capture.
- The temporary roster check reused the engine’s Light Expose value and a 99-damage, range-5 test attack for lethal preview.

No `TODO_DESIGN` placeholders were needed.
