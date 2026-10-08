# Turn Clock pass: "Waiting takes Time"

Owning spec: [spec/turn_clock.md](../../turn_clock.md).

Mockups (primary checkout, untracked):
`/Users/borgerding/workspace/Labyrinth/output/time-turn-order-design-2026-10-08/mockups/`

- `01_turn_start.png`: rail ghost at 19 and the Pass plate showing `+10`
- `02_fast_card.png`: Quick Stab −3 pill and landing strip
- `03_heavy_card.png`: Bloody Lunge +1 pill and landing strip
- `04_act_again.png`: second card returns before everyone; ACT AGAIN
- `05_details.png`: pill colours, plate states, tooltip copy
- `proposed_*.png`: full 1920×1080 frames
- `baseline/*.png`: today's real-renderer captures
- `src/`: the scratch probe and compositing scripts. These are reference only and must not ship.

| Unit | Brief | Owns | Depends on |
| --- | --- | --- | --- |
| 1 | [Rules, copy, analytics, specs](unit_1_rules.md) | engine, tempo relic rules, data, tutorial and icon copy, analytics, specs, engine tests | — |
| 2 | [Turn-order HUD](unit_2_hud.md) | rail pill, landing strip, Pass plate, badge tooltip, probe | Unit 1 helpers |

Decisions already made (do not reopen):
- Wait is 5 per unused base play.
- Base initiative stays 9.
- Keep the dimmed actor after the hero in the strip.
- No ACT AGAIN turn banner yet.
- No ring on the Time badge.
