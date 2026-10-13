# en-04 feedback 2 (director)

The painted thicket, growth and sink are approved
(`output/peer-benchmark-2026-10-12/proof/en-04/r1/03_thornwall_grown.png`).

## Fix
1. **Empty frame above every Bramble.** Root cause: `_should_show_terrain_health_bar` shows a bar when
   `hp < max(1, max_hp)`; Bramble terrain has no `hp`/`max_hp`, so it draws an empty 0/1 bar (a plain outlined box above
   each thicket in 02/03/04/08). Rule: terrain that has no positive `max_hp` (non-destructible: Bramble, and the existing
   Ice Pillar special case) never shows a terrain health bar or damage preview bar. Keep boxes/crates/kegs unchanged.
   Regression: a Bramble at rest, in `attack_tiles`, and under a damage preview shows no bar; a damaged crate still does.

## Proof
- Suites green; re-capture 03 and 04 with the bramble-only probe; list the command.
