# spx-07 — Warband rework: hover hitches, locked wind, spread spawns

## Header
- **Owner, warband-built (2026-10-21, playtest build fd9adb42c):** "We're getting massive frame drops ... the direction
  of the wind keeps changing every time I move with no discernable reason ... I don't like the whole 'warband' starting
  grouped together on one side of the map. They should be slightly more spread so that 1. the player has the ability to
  take them out 1 by 1 or slip past some to get to the leader 2. they don't spend the first couple of turns just
  bumbling over each other to get toward the player."
- **Director measurement (native, 1920x1080, integration and fd9adb42c):** average frame rate is fine (105–120 fps), but
  sweeping the pointer across the board causes single frames of 55–123 ms. The lightning tier-3 Warband is worst
  (123 ms); an ordinary fight also hitches (71 ms). So the drops are hover-preview stalls, worse with a warband's six
  enemies. Probe: `spec/peer_benchmark/director_tools/warband_perf_probe.gd`.
- **Out of this unit:** the Warband's visual markers (command zone, captain mark, +1). The owner called them crude; the
  director redesigns them separately. Don't change their look here.
- **Base:** integration HEAD after spx-05 merges. **Owned:** `scripts/warband_room_rules.gd`,
  `scripts/enemy_mechanics/wind.gd` and `wind_view.gd`, the hover/preview pipeline wherever the profile points
  (`run_scene.gd`, `combat_board_view.gd`, `combat_engine.gd` preview paths), the Warband data's placement fields, tests,
  and `spec/encounters.md`.

## Change (director decisions; exact)
1. **Hover hitches: root cause first.**
   - Instrument the pointer-hover path headless: what runs when the hovered tile changes, and what runs on mouse
     motion within the same tile. Report the top costs (function and ms) for the lightning tier-3 Warband, the air
     tier-2 Warband and an ordinary fight, then fix those causes.
   - Expected direction: compute per-board-state data once and reuse it per hover (threat tiles, intents, command
     bonuses, wind previews), and do no work on motion that stays inside the same tile.
   - Budget, measured headless as CPU time per hovered-tile change: ≤ 6 ms median and ≤ 12 ms worst in all three
     fights, sweeping every board tile. Card targeting (dragging a card across targets) has the same budget.
   - Behaviour and previews stay identical; prove it with before/after preview snapshots for the swept tiles.
   - The director confirms frame times natively with the probe.
2. **The wind holds its direction.**
   - For every wind source (the Gale Herald's Call the Wind and the Stormcaller's held wind), the direction is chosen
     when the intent is chosen and stays fixed until the wind blows. The player's movement, card plays and hovering
     never change it.
   - The Stormcaller's held wind re-aims only on its own turn.
   - The wind chip's arrow and the slide previews always show that locked direction.
   - Regression: move the hero across several tiles during one player turn; the announced direction never changes.
3. **The warband starts spread out.** The captain keeps its 5–7 tiles from the entry. The followers (the variant's
   escort, sliced by tier as now) take these roles, in this order:
   - **Guard (1):** within 2 tiles of the captain, so inside Command.
   - **Screen (1):** on a shortest path from the entry to the captain, 2–3 tiles from the captain.
   - **Skirmishers (the rest):**
     - each 3–5 tiles from the entry;
     - alternating sides of the entry→captain line (perpendicular offset left, then right; ties go to the lower lane);
     - at least 3 tiles from every other follower and from the captain.
   - Every follower starts at least 3 tiles from the entry, as now, and no two followers start adjacent.
   - **A way through:** there is always a walkable path from the entry to within 2 tiles of the captain that never
     passes next to the screen or a skirmisher. Reroll the layout if not, as today.
   - Put these numbers in the Warband data (`captain.start_distance` stays):
     `followers: {guard_radius: 2, screen_distance: [2, 3], skirmisher_entry_distance: [3, 5], min_gap: 3}`.
     Import the director's staged copy.

## Keep
The captain's stats, Command, keep-distance, the six orders and their telegraphs, the break, rewards, saves, revision-5
and revision-6 maps, reduced motion. Ordinary fights' behaviour.

## Proof
- Headless:
  - the hover profile before and after, in all three fights;
  - preview snapshots identical before and after;
  - the wind-lock regression for both wind sources;
  - the spawn rules over 6 variants × 3 tiers × 200 seeds, including the way-through path;
  - the existing Warband and order suites.
- Windowed, for the director: the air tier-2 and lightning tier-3 fixtures at 1920x1080 on the first turn. List the
  exact commands.

## Out of scope
The Warband markers' look (director redesign), new art, balance numbers.
