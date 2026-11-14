# atk-01: are the previews lying? (forecast truth audit, 2026-11-13)

## Short answer

- **The numbers the forecast states are almost always true.** Across 18,090 forecasts in 91 real fights, a forecast that
  claimed to know the outcome was wrong 0.6% of the time (114 cases), always in the Block or Stoneskin row or on
  ground the Umbra hides. Those two Block/Stoneskin lies are fixed. After the fixes it is 0.13% (21 of 16,614), and
  every remaining case is one of two open design questions: unseen Umbra ground, and the half-Health rule switch.
- **The surprise damage comes from foes that act twice.** In 44–48% of turns, at least one foe acts twice before
  your next turn. Its second move is hidden on purpose. That hidden move hit the hero in 32–38% of all turns, for 8–9
  damage on average (36 at most). The PASS panel does say so ("+ ? 2ND MOVE", or UNKNOWN), but the number beside
  it covers only the first move, and the foe's disc stays grey when only the second move reaches you. In the short real-Health runs,
  this is how the hero died: the panel said "−4 Health + ? 2nd move" at 5 Health, and the second move killed.
- **A red disc is right 91–92% of the time, but a grey disc is wrong 14–15% of the time.** 82–86% of those
  misses are the hidden second move again. The rest are rule beats (Lightning Storm) on a foe whose own intent is a
  move, and foes the disc plans as if no other foe moves first.
- The open questions below are design choices: whether to reveal or bound second moves, how to show what the Umbra
  hides, and whether discs should follow the full turn simulation.

## What was measured

The tool (`tools/atk01/`) plays real runs through the production scene with the run-hunt bot. At every idle
decision point it reads the exact forecast the UI shows: the PASS panel, the panel for every hero-movement
destination ("move there, then the turn ends"), and the stay-put tile. It also reads the red flag on each compact
intent disc at rest. It then resolves the same choice for real, on a copy, through the live commit path, one
activation at a time until the next turn starts: enemy activations, summons, Bleed and burn, surfaces, traps, rule
beats, Meteorfall and turn start. Forecasts are compared with reality for Health, Block and Stoneskin lost, death,
the hero's final tile, and which foes dealt damage.

| | Before fixes | After fixes |
|---|---:|---:|
| Runs (two full 9,999-Health runs, 8 real-Health runs, 3 Warband entries) | 13 | 13 |
| Fights | 91 | 90 |
| Decision points (PASS forecasts) | 3,050 | 2,793 |
| Destination forecasts (move + stay put) | 15,040 | 13,821 |
| Intent-disc flags checked | 5,451 | 5,422 |

Coverage: all six sections and biomes (fire, ice, earth, air, lightning, shadow), ordinary fights, Guardians,
dragons, Warbands, Umbral Snares, Last Light and the Ember Hoarder. Full runs use 9,999 Health so the bot reaches the
last section; the real-Health runs supply the deaths. Warband rooms were entered with the certified Warband fixture
builder, because the random routes never chose one.

## Mismatch rates

"Said nothing" means the panel showed a confident number. "Flagged" means it also showed UNKNOWN, "? 2ND MOVE" or the
Umbra "?" row, so the mismatch was disclosed. Both passes used the same seeds, but the bot's routes differed, so
compare rates. Every "said nothing" case left after the fixes is Umbra ground or the half-Health switch (below).

| Measure | PASS now: said nothing | Move, then end: said nothing | Stay put: said nothing | All forecasts: wrong but flagged |
|---|---|---|---|---|
| Health lost | 0.00% → 0.04% | 0.07% → 0.14% | 0.00% → 0.00% | 35.13% → 39.69% |
| Block lost | 0.10% → 0.00% | 0.45% → 0.00% | 0.08% → 0.00% | 0.34% → 0.16% |
| Stoneskin lost | 0.13% → 0.00% | 0.23% → 0.00% | 0.17% → 0.00% | 0.72% → 0.36% |
| Death | 0.00% → 0.00% | 0.00% → 0.00% | 0.00% → 0.00% | 0.27% → 0.29% |
| Hero's final tile | 0.07% → 0.00% | 0.06% → 0.10% | 0.04% → 0.00% | 2.67% → 3.91% |
| Which foes hit you | 0.00% → 0.00% | 0.02% → 0.04% | 0.00% → 0.00% | 17.38% → 19.23% |

## The red danger flag (at rest, hero on its tile, then PASS)

| | Before | After |
|---|---:|---:|
| Red, and the foe hits you | 3,034 | 3,249 |
| Red, but the foe does not hit (false alarm) | 288 | 268 |
| Grey, but the foe hits you (missed danger) | 308 | 284 |
| Grey, and the foe does not hit | 1,821 | 1,621 |

Missed danger, by cause (before / after): hidden second move 265 / 232; a Lightning Storm beat on the Storm
Cantor's turn (its disc shows a move) 30 / 24; the disc planned the foe alone 13 / 28. False alarms: the foe moved
but missed (often it died on the way, to fire or its own Bleed, or another foe changed the board first) 222 / 204;
the fight ended on its turn 30 / 31; an earlier foe moved the hero 20 / 13; it never acted 16 / 20. The routes of the
two passes differ, so these shift; the fixes do not touch discs.

## Categories, with one reproduction each

Each reproduction's real save and combat snapshot are kept under
`/private/tmp/labyrinth_codex/atk-01/audit/<before|after>/seed-<seed>…/repro/<seed>-<point>/`. Replay with
`tools/atk01/repro.gd` (engine) or `tools/atk01/capture.gd` (production scene).

1. **Second activation hidden (disclosed; design).** 5,097 mismatches. Seed 201, first fight, turn 5, hero (1,3) at 5
   Health beside a Tunnel Crawler: PASS showed "−4 + ? 2ND MOVE"; the crawler's second move killed the hero. Code:
   `combat_engine.gd advance_revealed_enemy_actions_preview` skips a foe's repeat activation by design.
2. **Walk through fire strips Block the panel did not count (lie, fixed).** 96 mismatches (51 undisclosed).
   Seed 101, Vyraketh (section 1 dragon), turn 5, hero (4,4) with 6 Block, destination (4,5): panel "−4 Block",
   reality −6. Code: `pass_forecast_action_source.gd visibility_safe` kept only the Health the previewed action
   removed; `run_scene.gd _pass_preview_summary_for_phase_result` summed Block/Stoneskin from receipts only.
3. **Block/Stoneskin lost to unreceipted effects (lie, fixed).** 47 undisclosed mismatches. Seed 101,
   section 3 earth fight, turn 4, hero (2,7) with 2 Block: a Burrow Grub erupts under the hero; PASS showed no Block
   loss, reality −2. Same for Lightning Storm beats on Stoneskin (seed 101, section 5 Storm Cantor Guardian, turn 5,
   hero (2,6): panel no Stoneskin loss, reality −2). Code: `battlefield_rules/dispatcher.gd fire` emits no loss
   receipt (except Gust) and the summary's qa-87 net fallback covered Health only.
4. **Unseen ground in the Umbra (undisclosed; design).** 16 mismatches before, 17 after. The forecast plays the
   enemy phase on the board you can see; unseen tiles are left empty, by design. Seed 101 (after-fix run), section 6 ordinary fight,
   turn 9, hero (6,2) → (7,2): the last foe, a Cinder Ooze at 1 Health, avoids fire. Fire on (4,1) is outside sight,
   so the forecast walks it there safely: panel **SAFE**. In reality it steps into fire at (5,2), dies and splits, and
   the two Cinder Droplets hit for 12, plus 3 burn at turn start. Second example: seed 102, Noctyrax (section 6
   dragon), turn 1, hero (1,4) → (2,5): Night Coil pulls the hero into an unseen wooden box (forecast −9 and a pull;
   reality −11, no pull). On the full board the same simulation reproduces both (the ooze's droplets then show as
   unknown arrivals instead of SAFE), so the gap is only what the Umbra hides. Code:
   `pass_forecast_action_source.gd information_state` strips unseen terrain, traps and surfaces.
5. **Foes hidden in the Umbra act first (disclosed; design).** 1,134 mismatches (980 hidden foes, 154 where the last
   visible foe dies and the panel shows "?" instead of victory). Shown as the Umbra "?" row.
6. **New arrivals (disclosed).** 56. A summon or split foe acts before you; its first intent is not forecast. The panel
   shows the Umbra "?" row and the tooltip says "Foes hidden in the Umbra may act first" even in a lit room.
7. **Half-Health rule switch (undisclosed; conflicts with a recorded decision).** 4 mismatches (after-fix pass only;
   the other route never met it). Seed 101 (after-fix run), Vyraketh (section 1 dragon), turn 6, hero (2,1) → (4,1): the dragon drops to exactly half (26/52)
   on its own turn, live play switches Wildfire and replans its landing, and the forecast keeps the old landing (−5 at
   turn start; reality −2). Code: the forecast cursor resolves enemy turns without `battlefield_rules/committed.gd
   accept`; bos-01 feedback 2 requires that PASS previews never switch (`tests/suites/bos01_feedback2_suite.gd`).
8. **Disc planned alone (flag only; 13 before, 28 after).** Seed 101, Rimejaw Guardian (section 2), turn 3, hero
   (3,4): the Rime Whelp between them acts first and steps aside; the Rimejaw's disc showed its attack as cancelled, and it hit for 7.
   Code: `intent_badges.gd build` plans each foe with `enemy_threat_tiles` on the board at rest.

Not seen: randomness, Block/Stoneskin ordering, knockback into a hazard the forecast could see, or replanning after
a move; each resolved identically in forecast and reality. Turn-start damage (Bleed, burn, Fatigue, Wildfire
landings) only differed when a hidden second move changed the board first (6 cases, all flagged).

## Fixes

1. **Walk-through-fire defence.** The destination forecast now counts the Block and Stoneskin its own walk removes,
   as it already counted Health (`pass_forecast_action_source.gd`, `run_scene.gd`).
2. **Unreceipted defence loss.** For the enemy phase, the PASS summary now takes the larger of the receipts and the
   simulated net Block/Stoneskin loss, as qa-87 did for Health. The net is measured from the moment the turn ends,
   so turn-end effects that add Stoneskin (the Guard skill turns leftover Block into Stoneskin) keep their own
   receipt (`run_scene.gd`).

Neither fix changes rules, AI, numbers, saves or analytics, and neither adds simulation: both read the result the
forecast already computed. Interleaved A/B/A/B on the Vyraketh save (destination (4,5)): the summary step went from
20 to 22 µs (median), and the whole destination forecast stayed 3.26–3.32 ms before and 3.25–3.27 ms after.

## atk-03 follow-up: forecast the second move (2026-11-13)

Director decisions, 2026-11-13:
- **Every forecast counts every move before your next turn.** That covers PASS, movement destinations and staying put.
  A visible foe's repeat move rolls its intent on the forecast copy, from the fight's saved generator, exactly as live
  play will (`pass_forecast_repeats.gd`, called from `combat_engine.gd advance_revealed_enemy_actions_preview`).
  The cursor's copy also accepts each action, so the half-Health switch happens in the forecast as it does live.
  - Hidden foes and new arrivals stay unknown.
  - When one of them acts before a visible foe's move ends, that foe's later roll can no longer match live play.
    That repeat keeps "×2 ?" and the known damage.
- **Panel.** A counted repeat shows its portrait and "×2" in the violet ink, with no "?". "Safe" needs the whole
  simulation to lose nothing.
- **Discs.** At rest, a disc is red when any of that foe's activations hurts you in the PASS forecast from your own tile
  (`pass_forecast_discs.gd`). The PASS forecast is recorded once per committed state. Until it is ready, the disc uses
  the at-rest threat rule.
- **Pip.** A foe due to act twice or more wears a small violet "×2" pip on its compact disc. The count comes from the
  turn queue, raised to the forecast's count at rest.

Rerun as `after-atk03` on the same seeds (101 and 102 at 9,999 Health, 201–208 at real Health, one air Warband).
`before-atk03` is the same eleven atk-01 after-fix runs, reported with the same classifier.

| Measure | PASS now: said nothing | Move, then end: said nothing | Stay put: said nothing | All forecasts: wrong but flagged |
|---|---|---|---|---|
| Health lost | 0.04% → 0.21% | 0.15% → 0.25% | 0.00% → 0.23% | 39.30% → 11.34% |
| Block lost | 0.00% → 0.00% | 0.00% → 0.00% | 0.00% → 0.00% | 0.18% → 0.01% |
| Stoneskin lost | 0.00% → 0.00% | 0.00% → 0.01% | 0.00% → 0.00% | 0.39% → 0.17% |
| Death | 0.00% → 0.00% | 0.00% → 0.00% | 0.00% → 0.00% | 0.32% → 0.03% |
| Hero's final tile | 0.00% → 0.07% | 0.11% → 0.09% | 0.00% → 0.05% | 3.92% → 0.64% |
| Which foes hit you | 0.00% → 0.11% | 0.05% → 0.11% | 0.00% → 0.14% | 19.49% → 9.06% |

- **Second moves.** Mismatches fell from 4,651 checks to 770, all of them flagged.
  - 370 are foes that were hidden or new when you chose.
  - 385 are visible foes whose roll stayed unknown: in Umbra rooms a hidden foe acted before that foe's move ended,
    and the Umbra "?" was already showing.
  - 15 were simulated but differed, all in Umbra rooms with the "?" showing.
  - On the PASS points where a foe's later move hit you, the panel's numbers were exact 666 times out of 890. Before,
    they were exact 0 times out of 952.
- **"Said nothing" rose slightly.** All 49 cases are unseen Umbra ground: the full-board simulation matches reality.
  Before, a counted repeat's "? 2ND MOVE" flag hid them. The half-Health switch cases went from 4 to 0. The Vyraketh
  reproduction (seed 101, turn 6, (2,1) → (4,1)) now forecasts −2 at turn start and −4 in total, exactly as live play.
- **Discs.**
  - Red and hits you: 2,977 → 3,018.
  - Red but misses (false alarm): 244 → 13.
  - Grey but hits you (missed danger): 271 → 39. 38 of these are the unknown repeats above, where the disc keeps the
    at-rest rule.
  - Grey and misses: 1,479 → 1,930.
  - The discs had their forecast marks at all 2,818 decision points before the audit read them.
- **Hover cost** (the audit's `ui_usec`):
  - All checks: median 11,976 → 10,193 µs, p95 31,090 → 33,034 µs (+6%).
  - Destination: p95 33,239 → 35,689 µs. Stay put: p95 22,617 → 27,121 µs.
  - PASS is warmed: median 15 → 18 µs.
  - The extra simulated moves drive the tail: checks with a counted repeat had median 17.0 ms and p95 43.2 ms, against
    8.1 ms and 22.2 ms without one.
  - The deferred-roll restart never fired in these runs.

## Open design questions

- **Decided (atk-03, director 2026-11-13): second moves are forecast.** Was TODO_DESIGN_second_move_forecast. See
  "atk-03 follow-up" below.
- **TODO_DESIGN_umbra_unseen_ground.** Forecasts treat unseen tiles as empty, so a push into an unseen crate or trap
  surprises you. Options: show "?" when the simulation moves anything across an unseen tile; or accept it.
- **Decided (atk-03, director 2026-11-13): the forecast copy applies the half-Health switch.** Was
  TODO_DESIGN_half_health_switch_in_forecast. bos-01 feedback 2's "previews never switch" protected the live state,
  analytics, banner and save, which stay untouched; the forecast copy now switches as live play does.
- **Decided (atk-03, director 2026-11-13): at rest, discs follow the PASS simulation.** Was
  TODO_DESIGN_disc_from_full_simulation. A disc is red when any of that foe's activations before your next turn hurts
  you (a rule beat on its turn counts as its own).
- **TODO_DESIGN_new_arrival_wording.** A visible summon's first move shows the Umbra "?" with Umbra wording.

## Rerun

`python3 tools/atk01/audit.py run --seeds 101 --health 9999 --label <name>` (one headless Godot at a time; add
`--warband air:2` for a Warband entry, `--project <dir>` for a baseline copy), then
`python3 tools/atk01/audit.py report --label <name>` and `audit.py table --before before --after after`.
