# spx-04 — The six Warband orders

## Header
- **Owner:** enc-specials approved 2026-10-21. Each captain has "a little bit of flavor": one signature order, read
  from `data/special_encounters.json` → `types.warband.variants.<biome>.order`, with a lever the player can use.
- **Base:** integration HEAD after spx-03 (Warband combat) lands. It builds on spx-03's captain flag, roster and
  titles.
- **Owned:** `scripts/enemy_mechanics/{bramble,lob,wind,icefall,capacitor,veil}.gd` and their views, the captain hooks
  spx-03 added, the captain tooltip, `spec/enemies/*.md` for the six mechanics, and tests.
- **Rule for all six:** an order applies only to that warband's captain, only while it lives. Each shows in the
  preview and telegraph before it can hurt you. The captain's tooltip and the Warband objective tooltip gain one line,
  `Order: <order.text>`. Outside a Warband every mechanic behaves exactly as today, proved by golden tests.

## Orders (director decisions; exact)
1. **The Thornmother — `thornmother_wall`.**
   - Her Thornwall is 5 tiles long instead of 3.
   - It's centred on the tile 2 steps from her along the shortest path toward the player, or the nearest legal tile to
     that, and runs perpendicular to that path.
   - Grow only the legal tiles. Existing bramble damage, bleed and duration stay.
   - Lever: brambles already hurt whoever is pushed into them, so push her escort into the wall.
2. **The Slagmaster — `slagmaster_barrage`.**
   - Lob Slag marks two plus-shapes: the normal one, and a second centred 2 tiles to one side of it, perpendicular to
     the line from the Mortar to its target.
   - The room's seeded RNG picks the side. If that side is illegal, use the other; if both are, mark only one.
   - Both land together.
   - While he leads, slag hits everything under the marks, his own warband included.
3. **The Stormcaller — `stormcaller_wind`.**
   - Its called wind doesn't expire while it lives; each new Call the Wind re-aims it.
   - The gust slides every unit 1 tile, followers included, with the existing mover and collision rules. The wind
     preview shows all units' slides.
4. **The Rime Oracle — `oracle_icewall`.**
   - Icefall's marked line is 5 tiles long, centred on the tile halfway between the Oracle and the player (rounded
     toward the player), and perpendicular to the line between them.
   - It lands as today: damage on the line, and ice pillars that shatter for 2 to the tiles beside them.
5. **The Dynamo — `dynamo_tether`.**
   - While both of its warband's Arc Thralls live, Arc Burst fires at 2 Charge instead of 3, and the charge display
     shows the lower threshold.
   - Kill either Thrall and it returns to 3 at once.
6. **The Hollow Prior — `prior_veil`.**
   - While it lives, its followers more than 2 tiles from the player are hidden, using the existing veil and
     hidden-enemy rules and presentation. Whatever reveals veiled enemies today reveals these too.
   - When the Prior dies, every follower is revealed at once, before the break.

## Keep
Every mechanic outside a Warband, spx-03's placement, command, keep-distance and break, and saves mid-combat.

## Proof
- Headless: each order in its own test, with the telegraph or preview asserted before it resolves, plus golden tests
  for each mechanic outside a Warband and mutation checks.
- Windowed, run by the director, at 1920×1080 and 100% UI scale: one frame per order showing its telegraph, plus the
  Prior's reveal. List the exact commands.

## Out of scope
New art, the map and rewards, and the other special types.
