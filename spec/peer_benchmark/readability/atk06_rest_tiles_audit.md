# atk-06: do the red tiles at rest tell the truth? (danger-at-a-glance audit, 2026-11-14)

## Short answer

- **Standing still, red is honest.** When your own tile was red, you were hurt 98% of the time (2,087 of 2,135). When
  you were hurt on a clear tile (221 of 2,308 hits), no foe's attack had been drawn in the wrong place: about half was
  start-of-turn damage (Fatigue, standing in fire), the rest a foe's second move, a rule beat or a new foe. The red
  set on screen was never stale (2,818 of 2,818 decision points matched a fresh rebuild).
- **Red at rest never means "safe to move here".** It shows where attacks land if you stay. 79% of the destinations
  that get you hurt are clear at rest, mostly (71%) because the foe simply follows you. Hover the tile and the board
  re-plans with you standing there: 80% of those hits then show red. The rest is mostly your own walk through fire,
  second moves and Fatigue.
- **Two lies, fixed.** (1) Hovering a tile a visible foe can't see from there erased its red and showed its attack as
  cancelled, while PASS counted the hit (157 hovered hits). (2) Tharokh's Faultline aimed before its burst cleared the line.
- **What red leaves out is design** (options below): second moves, rule beats, fire laid under you, a dark destination,
  foes that die to their own Bleed or Fire first (red but safe), telegraphs that land after your next turn.

## What the player sees today

At rest the board paints red, on tiles you can see, every tile a visible foe's current intent will strike before your
next turn if you stay where you are: its planned attack from where it will stand (`intent_badges.gd build`, from
`enemy_threat_tiles`), plus Lob landings, the due battlefield beat's fire/freeze/strike/rise tiles, Snare pressure and
the Thornmother wall. Foes that don't act before you, are Shocked or Frozen, have no target, or hide in the Umbra add
nothing. Your tile pulses when it is red (steady with reduced motion). It is one set for all foes: hovering a foe or
one of its red tiles only dims the others, and Details [I] leaves it alone, adding every foe's whole move and attack
reach on top (teal and orange). Pick Move and hover a destination, or select a card, and the set is rebuilt with you
standing there: the foes re-plan and the red follows your pointer, under the teal move range. At rest, a clear tile in
your move range only means nothing lands there while you stand still.

## Method

`tools/atk06/` extends the atk-01 walk. At each idle decision point it reads the red set the board itself draws (as
held, after a fresh rest refresh, and with each move destination hovered). For your tile (PASS) and every destination:
(a) red?; (b) hit?: the forecast (the panel's own replica) has you lose Health, Block or Stoneskin, or moved, before your
next turn (Block that merely expires is not a hit). Each simulated activation carries that foe's own plan at that moment.
Seeds as atk-01 plus the air:2 Warband: 84 fights, all six sections. Where no "?" showed, forecast hit = real hit in
9,369 of 9,369 checks. Both passes took the same routes: all 16,692 checks pair one to one.

## Agreement matrix (before → after the fixes)

| Checks | Red & hit | Red & safe (false alarm) | Clear & hit (missed) | Clear & safe |
|---|---:|---:|---:|---:|
| Your tile, PASS (2,818) | 2,087 → 2,087 | 48 → 48 | 221 → 221 | 462 → 462 |
| Destinations at rest (11,662) | 1,990 → 1,990 | 25 → 25 | 7,613 → 7,613 | 2,034 → 2,034 |
| Destinations, hovered (11,662) | 7,558 → 7,722 | 137 → 142 | 2,045 → 1,881 | 1,922 → 1,917 |

Where no "?" showed: your tile 1,428 / 8 / 129 / 255, destinations 1,312 / 9 / 4,991 / 1,237. Neither fix touches the
rest set or the forecast: no rest tile and no forecast changed in any of the 16,692 checks.

## Root causes, with one reproduction each

Saves: `/private/tmp/labyrinth_codex/atk-06/audit/before/seed-<seed>…/repro/<seed>-<point>/`; replay with
`tools/atk06/repro.gd -- --save-dir <dir> [--tile x,y]`. Sections count from 1. Your tile, clear but hurt (221):
- **Second move (77).** Seed 101, section 2 ice fight, turn 5, hero (7,7): the Harrier's repeat Pelt hits for 5
  (`101-133`). The red set plans each foe's current intent once (`intent_badges.gd build`).
- **Start-of-turn damage (106):** Fatigue 43, ground and rule effects 46, your own ticks 6, end of turn 11.
  Seed 102, section 2 lightning fight, turn 6, hero (4,2): Fatigue 2 (`102-183`).
- **Rule beats (25).** Seed 101, Vaeloryx (section 4), turn 3, hero (1,3): the Gust after its turn pushes you into the
  Gust Shrike's dive (`101-642`). `battlefield_rule_view.gd _due_tiles` paints only fire/freeze/strike/rise tiles.
- **New foe (7)** (seed 101, section 5 Snare, turn 1, hero (1,4): an arriving Arc Thrall shoots for 5, `101-829`),
  **fire laid under you (5)**, an Ember Tick's death burst on its own turn (1).
Your tile, red but safe (48):
- **Foe dies first (33).** Seed 101, section 2, turn 3, hero (6,7): the Cinder Ooze dies to its own Bleed or Fire
  before it strikes (`101-127`). The plan ignores the foe's own ticks; the disc (PASS forecast) is already grey.
- **Telegraph lands later (10).** Seed 102, section 3 fire fight, turn 1, hero (4,1): a Slag Mortar Lob mark
  (`102-600`). Burrow Grub's dig marks your tile the same way.
- **A beat at the end of your turn reshapes the board (5).** Seed 102, Tharokh (section 1), turn 10, hero (6,4):
  Upheaval moves things and Worldspine Claw re-aims away (`102-151`).

Destinations clear at rest but hurt (7,613): the foe follows you 5,398 (seed 101, Rimejaw, turn 10, (4,3) → (5,4): −21,
red once hovered, `101-217`), your own walk 930 (seed 101, section 2, turn 7, (4,6) → (4,5): a hazard on the path,
−9, `101-142`), second moves 515, Fatigue 256, out of sight from there 168, rule beats 146, the rest under 50 each.

Hovered destinations still clear but hurt, after the fixes (1,881): own walk 852, second moves 470, Fatigue 241, rule
beats 143, fire laid under you 43, own ticks 32, **destination in the dark 32** (all Noctyrax: seed 102, turn 10, (4,4)
→ (5,3), `102-1425`: both foes' plans and discs show the hit, but red is only painted on tiles you can see now), end
of turn 29, new foes 26. Red but safe (142): foe dies first 60, telegraphs 41, beats reshaping the board 33.

Not seen: a wrong footprint or area, a push or pull left out, a dead or hidden foe painted red. Of 34,361 visible
activations, a plan missed a real hit 29 times (Faultline 15, Ember Tick bursts 14; 14 after the fixes).

## Fixes

Presentation only: rules, AI, numbers, PASS, discs at rest, saves and analytics are unchanged.
1. **A foe you can see keeps its red when you hover a tile it can't see** (`intent_badges.gd build`, `enemy_orders`;
   `combat_engine.gd committed_enemy_threat_tiles`). The badges treat today's sight as the boundary, but the threat
   query and the turn order judged sight again from the hovered tile: the plan came back empty, the turn-order slot
   vanished, the red disappeared and the disc showed "cancelled" while PASS counted the hit. Foes hidden now stay
   hidden. Seed 101, section 6 shadow fight, turn 9, hero (5,5) → (5,4): Bile Bloomer, −8 (`101-1002`). 157 hovered
   hits turn red (plus 5 where something else hurt first); 5 Burrow Grub digs now mark tiles as any dig does.
2. **Faultline's shot is marked where it lands** (`combat_engine.gd _projected_attack_after_pattern`). When only board
   patterns resolve before an intent's direct attack (Faultline; Vyraketh's Kindle Ground), the attack is planned on
   the board the patterns leave, through the real resolver on a private copy, as Guardian plans already do. Seed 102,
   Tharokh (section 1), turn 9, hero (7,3) → (7,2): −4 (`102-146`). 15 missed activations → 0; 2 hovered checks turn red.

Rest red-set build per decision point: 3.45 → 3.48 ms median, 9.27 ms p95 both. Native pairs (cel, 1920×1080, 100%,
real saves, destination hovered): `/private/tmp/labyrinth_codex/atk-06/captures/fix{1_out_of_sight,2_faultline}_{before,
after,pair}.png`. After, a red edge shows inside the hover ring (which covers most of it), the Bloomer's disc reads ×2 6
and each foe's callout opens.

## TODO_DESIGN options

Caught = clear-but-hurt checks it would turn red; added = clear-and-safe checks it would turn red. Costs per decision
point, median / p95; the PASS simulation the discs already run takes 5.9 / 19 ms.
- `TODO_DESIGN_red_second_moves`: add repeat activations' tiles from the PASS forecast. Your tile 77 caught, 4 added;
  destinations at rest 174 / 5. Cost: plans inside that simulation, 2.0 / 7.5 ms.
- `TODO_DESIGN_red_in_context`: plan every activation as the PASS forecast plays it (also beats, foes moved first).
  Your tile 91 / 7; destinations 222 / 9. Same cost.
- `TODO_DESIGN_red_drops_foes_that_die_first`: drop a foe's red when its own Bleed or Fire kills it first, as the disc
  does. Removes 33 false alarms on your tile and 60 hovered; no new simulation for your tile.
- `TODO_DESIGN_red_telegraph_timing`: Burrow digs and Lob marks are red for hits after your next turn (10 / 41 alarms).
- `TODO_DESIGN_red_rule_beats`: Gust pushes and collisions, Upheaval moves, beats at the end of your turn: 25 misses on
  your tile, 146 destinations at rest. The beat forecast already exists (`BattlefieldRules.forecast`).
- `TODO_DESIGN_red_fire_laid_under_you`: a foe's surface on your tile burns at your turn start: 5 / 45 misses.
- `TODO_DESIGN_red_on_dark_destination`: paint a hovered destination's red when the tile is dark: 32 hovered misses.
- `TODO_DESIGN_red_per_destination`: say at rest whether each reachable tile gets you hurt. (a) The hover re-plan for
  every destination: 5,744 caught, 125 added, 18 / 69 ms. (b) Each destination's own forecast: all 7,613, none
  added, 65 / 221 ms. Details [I] reach already covers 5,699, but adds 195 and paints all reach.

## Rerun

`python3 tools/atk06/audit.py run --label <name>` with `--seeds 201 … 208 --health 0`, `--seeds 101 102 --health 9999`
and `--seeds 301 --health 9999 --warband air:2 --stop-after 220` (one headless Godot at a time, ~30 min per full run);
then `audit.py report --label <name>` and `audit.py table --before before --after after`. Captures:
`tools/atk06/native_capture.sh <repro dir> <rest|x,y> <name> "<x,y>"` and `tools/atk06/pair.py`.
