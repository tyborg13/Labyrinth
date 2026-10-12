# Umbra inventory at program start (master 816f5e68a, 2026-10-12)

Condensed from an Explore-agent sweep; file:line pointers are into master at that commit.

## Run
- 6 sections (boss order seeded; Noctyrax last). Budget per route 66 rooms / 40 fights (10/11/11/11/11/12; 6/6/7/7/7/7).
- Room types: combat, guardian (elite, optional, one lane of group 1), boss, campfire (Ember Hearth, 1 per section on every
  route), treasure (relic 3-pick), scavenger (shop: gear/magic/items, no relics, no removal), event, graftwright (~20% of
  eligible services after 3 fights), start/threshold.
- Map: `scripts/section_map_graph.gd` — 2–3 lanes, groups of ≤3 steps, neighbor-lane joins, no crossings; fog + 2 Scouts per
  section; next 2 transitions known. Legacy circular map still loaded for old saves (`labyrinth_map_view.gd`).
- Events: ONE (Lost Cartographer: 25 Embers or reveal routes). Hardcoded `run_engine.gd:3733-3757`,
  `section_map_panel.gd:636-660` (680×228 panel, no art). Seen ~5–7× per run. No event framework.

## Combat
- 9×9 iso grid; initiative clock (spec/turn_clock.md). Activation: draw 2, 2 card plays, 2 free movement, hand cap 7.
  Next turn = now + 9 + card Time + 5×unused plays. Kill refunds +1 play. Fatigue on reshuffle 2,+1.
- Objectives: Defeat All 50% / Defeat Leader 25% / Reach Exit 25% (Survive parked). Guardians/bosses = Defeat Leader.
- Surfaces Fire/Ice/Electrified/Rubble; elemental traps; universal push/pull with collision damage; Umbra fog shrinks by
  section (∞/6/5/4/3/2).
- Intents: compass icons always on visible enemies; "Intents [I]" toggle shows all threat tiles. Previews are ITB-grade
  (damage, lethal marks, push paths, collisions, surfaces, Pass forecast). No undo after commit.

## Content
- Cards 309 ids: 126 reward magic (22/element + 16 neutral), 152 equipment-only, 24 consumable items, 3 starter, 4 retired.
- Deck = loadout: 5 gear slots (each 1–3 cards) + 6 attuned magic slots + 2 item slots; ~13–23 cards. Rewards go to a
  reserve. Starter 16 cards. Reward: 3 choices (2 room element + 1 any) or skip = heal 3.
- Relics 100 live (88 offerable; 12 guardian/dragon legendaries). Equipment 72 (5 slots), all drawn on hero.
- Skills 29 live, 5 branches + keystones. Levels 1–20 bought with Embers; Defiance charges; Moltshards.
- Enemies 31: 10 regulars (5 neutral: crawler, acolyte, harrier, warden, grave surgeon; 5 element: cinder ooze/droplet,
  shale bloomer, chainbound gaoler, frostglass lancer — lightning has none), 6 dragons, 6 guardians, 7 helpers, 2 summons.
  SAME regular roster in every section; only +8% HP/section and +0..3 damage.

## Audio
- 28 SFX files (+1 runtime click): sword, bow, block, 5 elemental attacks, card draw/play/flip, rewards, hearth (6),
  menu open/close, ambience, door. Enemies/traps reuse the 8 attack sounds. No hit/hurt/death/footstep/status/UI-hover
  variety.
- Music: menu (Mussorgsky), Lanterns Below (safe), The Turning Key (planning/overlays/event/shop), Ashen Pursuit
  (standard combat — one track for all 34 regular fights), Thorns in the Dark (guardian), 6 dragon themes, Chopin
  (death); 2 stingers. 9 legacy tracks (~260 MB WAV, incl. per-element combat loops) unrouted.

## Feel
- Present: card arcs (draw 0.32 s, play 0.23 s), cutout idle/walk/attack/hit/collapse for all, shadow dissolve death,
  shake 3–5.5 px, floating numbers, turn banners, reward reveal, door travel, strike trails, elemental FX.
- Missing: hit-stop; per-enemy slides for area pushes; full-screen room transitions.
- Enemy round ≈ 2.5 s per enemy (4-enemy round ≈ 10 s; clip in output/peer-benchmark-2026-10-12/clips/b_enemy_turn).

## Meta / UI
- No ascension/difficulty, no daily/seeded runs, no achievements, no run-history UI (32 results stored), no
  compendium/stats screen outside a run. Main menu: Continue / New Game / Settings / Quit (+ hidden debug Fight Boss).
- Run-end recap: 6 stats on black. Tutorial: 14-milestone first-fight spotlight curriculum.

## Placeholders / inconsistencies
- Board tiles load from `assets/placeholders/tiles/`; Emaciated Man art is a placeholder ("anime trial").
- Every combat room uses the same stone floor + sandstone torch pillars + crates regardless of section.
- Grimoire lacks guardians/helpers and per-relic entries. Stale specs: prototype.md, meta_leveling.md counts.
