# atk-08: who hit me? Hit receipts (2026-11-14)

## Short answer

- **When a foe hits you, the game shows it plainly.** The foe's name and move appear in the banner ("Tunnel Crawler:
  Skitter Strike"), the foe walks and winds up, the hit freezes for a beat, a red −N pops on the hero, and your Health
  bar fades in with the lost slice still lit for about a second. In 1,100 receipts from 81 fights, all 545 foe hits had
  the right number on the hero, uncovered, with the foe animating and named as it landed.
- **A foe acting twice is never blurred into one hit.** Each activation is its own beat with its own number and banner
  (all 72 repeat hits clear; in the strip below the second −4 lands 4.9 s after the first). Bleed shows as −N with the
  Bleed icon; turn-start Fatigue as −N plus "fatigue sets in"; fire as −N with the fire icon or a flash of the tile.
- **Two losses showed nothing at all, now fixed:** Health paid for an Empowered card (or a card's own Health cost) and
  Fatigue from a card draw that reshuffles your deck mid-turn. The bar dropped silently. Both now show the hero's
  existing −N beat (Fatigue with its words).
- **Two weaker spots need a design call (TODO below).** The turn-clock rail runs one step behind when foes act quickly:
  at 40% of foe hits it highlights nobody and at 1% the previous foe (the banner and animation still name the right
  foe). And the numbers of a few big multi-frame attacks (Tharokh's slam, Vyraketh's marks, your own area cards' Bleed)
  appear a fifth to a third of the way into their life, so they read for 0.26–0.36 s instead of about 0.4 s.

## What was measured

`tools/atk08/` plays real fights with the atk-01 run-hunt bot and seeds through the production RunScene playback. A
copy of the RunScene script, renamed hooks only, reports each real playback call (enemy round, each activation, the
Fatigue and turn-start fire beats, each hero action). For every hero Health, Block or Stoneskin loss it records:

- **Truth:** amount and source from the states those calls receive: the activation's actor and its count this round
  (first or repeat), each damaging step separately, Bleed from the engine's Bleed receipts, Fatigue from deck cycles,
  fire and traps from surface events; the rest of a hero action is "self". Block that expires at turn start or
  converts to Stoneskin is not a hit.
- **Screen:** every number the board's effects layer actually laid out each frame (text, kind, colour, icon, tile,
  screen rect, progress, alpha), what overlapped it, any painting UI above it, the hero's health ghost and plate, the
  rail's active entry, the banner, the animating actors and surface flashes.

A loss is **clear** if a number with its amount is on the hero, never overlaps another number or panel, reads (alpha
≥ ½) for its intended ~0.39 s of presentation time (`floating_combat_text.gd`, within one sampled frame), and its source
shows: the foe animating, highlighted or named in the banner; the Bleed or fire icon on the number; the Fatigue words;
a surface flash; or the played card moving.

Runs: seeds 201–208 (real Health) and 101, 102 (9,999 Health; 900 and 600 decisions) at normal speed; seeds 201–204 and
101 (400 decisions) with reduced motion, at fastest speed, and both (normal is the slowest setting). The bot never
Empowers or plays Health-cost cards, so a coverage pass (`--empower`, seed 101) Empowers what it selects. A rerun can
take another route (timing-dependent offers), so each reproduction below is a real save.

## Receipts by source, before → after (normal speed, motion on)

| Source | Receipts | Health | Clear | Wrong or missing | Merged or covered | Too brief | No source |
|---|---:|---:|---:|---:|---:|---:|---:|
| Foe's first move this round | 263 → 263 | 1108 → 1108 | 261 → 262 | 0 → 0 | 0 → 0 | 2 → 1 | 0 → 0 |
| Same foe acting again | 46 → 46 | 197 → 197 | 46 → 46 | 0 → 0 | 0 → 0 | 0 → 0 | 0 → 0 |
| Bleed, paid as you move or attack | 212 → 212 | 299 → 299 | 210 → 210 | 0 → 0 | 0 → 0 | 2 → 2 | 0 → 0 |
| Surface or trap | 46 → 46 | 122 → 122 | 46 → 46 | 0 → 0 | 0 → 0 | 0 → 0 | 0 → 0 |
| Self: card/Empower costs (Empower pass) | 4 → 4 | 4 → 4 | 0 → 4 | 4 → 0 | 0 → 0 | 0 → 0 | 0 → 0 |
| Fatigue (deck reshuffle) | 26 → 26 | 62 → 62 | 24 → 26 | 2 → 0 | 0 → 0 | 0 → 0 | 0 → 0 |

Both passes played the same route. No summon, rule beat or turn-start status hurt the hero (atk-05: 0% of the owner's
Health). "Too brief" shifts by one or two because those numbers are born near the threshold on coarse headless frames;
the fixes do not touch them (same family both times: Tharokh, Grave Surgeon, your area cards' Bleed).

All settings, before → after (same routes; reduced motion snaps the rail and starts numbers at contact):

| Setting | Fights | Receipts | Clear | Wrong or missing | Merged or covered | Too brief | No source |
|---|---:|---:|---:|---:|---:|---:|---:|
| Normal speed | 35 | 517 | 511 → 514 | 2 → 0 | 0 | 4 → 3 | 0 |
| Normal, reduced motion | 14 | 157 | 157 → 157 | 0 | 0 | 0 | 0 |
| Fastest | 14 | 189 | 181 → 181 | 1 → 0 | 0 | 7 → 8 | 0 |
| Fastest, reduced motion | 14 | 157 | 157 → 157 | 0 | 0 | 0 | 0 |

No loss was merged, covered by a number or panel, or unattributed; the hero's ghost matched every Health loss (bar
down, lost slice lit) with the plate visible or fading in. No hidden Umbra foe hit the hero.

## Failure kinds, with one reproduction each

Saves (real save + decisions; replay natively with `tools/atk08/strip.gd`):
`/private/tmp/labyrinth_codex/atk-08/receipts/<label>/<setting>/seed-<n>-hp<h>/repro/<seed>-<decision>/`.

- **Missing number, Empower/card Health cost (self).** Empower pass, seed 101, room (0, 1), turn 2: Empowered Bloody
  Lunge, −1 Health, nothing on screen (4 of 4). Costs are paid in `combat_engine.gd finish_player_card` after the
  actions `_play_player_card` animates; nothing presented the hero's side of that commit. Save `empower/…/101-63`.
- **Missing number, mid-turn Fatigue.** Seed 101, room (6, 0), turn 6: Lantern Shot's draw reshuffles, −2 Health, only
  "+1 draw" shows (2 of 22 Fatigue receipts at normal speed). The Fatigue beat ran only at turn start
  (`_resolve_enemy_round`); the draw case of `_animate_player_action_step` showed the draw alone. Save `before/…/101-393`.
- **Too brief (number born late).** Seed 102, room (4, 0), turn 13: Tharokh's slam, −8 first drawn at 34% of its life,
  readable 0.26 s. Attack feedback advances in the attack's own frame steps (`_attack_feedback_elapsed_seconds`), so the
  first frame past contact can already be 0.11–0.16 s into the number. 4 of 517 at normal speed, 7 of 189 at fastest
  (where 0.26 s of game time is about 0.16 s of real time), none with reduced motion (numbers start at contact there).
- **Rail on the wrong foe.** Seed 101, room (9, 2), turn 2, round 76 (Umbra fight): a Tunnel Crawler hits for −5 while
  the rail highlights the foe before it. `combat_pacing.gd present_turn_order` keeps a single pending order while
  `_animate_turn_order_transition` tweens; a quick activation's highlight lands late or is replaced by the next order.
  3 of 269 foe hits on the wrong foe, 109 with no foe highlighted (normal speed); with reduced motion, which snaps the
  rail, 10 of 75 with none and none wrong.

## Fixes (presentation only; rules, numbers, AI, pacing constants and analytics unchanged)

1. **Card and Empower Health costs** (`scripts/run_scene.gd _play_player_card`): after the card's actions and echoes,
   any hero loss its finish caused plays the existing hero-loss beat (`_player_loss_floating_texts` through
   `_animate_floating_text_presentation`), as Bleed on a move already does. Empower pass: 0 of 4 → 4 of 4 clear.
2. **Mid-turn Fatigue** (`scripts/run_scene.gd _animate_player_action_step`, draw case): a draw that reshuffles plays
   the existing turn-start Fatigue beat (`_animate_fatigue_damage`: −N and "fatigue sets in") before "+N draw".
   Missing: 2 → 0 at normal speed, 1 → 0 at fastest.

## TODO_DESIGN, ranked by share of the owner's Health lost (atk-05)

1. **TODO_DESIGN_rail_follows_actor** (resolved by atk-10, below) (foe moves: first 46% + repeat 17%). The banner and animation already name every
   attacker, but the rail often shows nobody, sometimes the previous foe. Options: snap the rail to an activation when a
   rail tween is still running (what reduced motion does); hold the foe's wind-up until its rail activation lands (adds
   up to ~0.7 s per quick activation); or keep the rail as a schedule and rely on the banner.
2. **TODO_DESIGN_late_hit_numbers** (resolved by atk-10, below) (a few foe moves and the hero's own area cards; under 2% of losses). Options: start
   the number's 0.48 s clock at its first drawn frame (rounds grow by up to ~0.16 s per such hit); step attack feedback
   per render frame; or keep.
3. **TODO_DESIGN_fatigue_deck_cue** (Fatigue 9%; low). Fatigue is named by its words on the hero; the draw pile shows
   nothing. Options: pulse the draw pile with the −N; or keep the words.

## Proof and rerun

- Receipts (headless, one Godot at a time; timing is the game's own clock): `python3 tools/atk08/receipts.py run
  --label <name> --config normal:0 --seeds 201 202 203 204 205 206 207 208 --health 0`, `--seeds 101 --health 9999
  --stop-after 900`, `--seeds 102 --health 9999 --stop-after 600`; `--config normal:1 fastest:0 fastest:1` with seeds
  201–204 and 101 (`--stop-after 400`); `--seeds 101 --health 9999 --stop-after 250 --empower`. Then `report --label
  <name> --examples`, `table --before before --after after --extra-before empower --extra-after after-empower`, `events`.
- Native strips (1920×1080, 100% UI, cel look, normal speed, MovieWriter 30 fps clock): `LABYRINTH_CEL_LOOK=all python3
  tools/visual_probe_runner.py --godot tools/atk08/strip_movie.sh --no-headless --display-driver macos --audio-driver
  Dummy --rendering-driver metal --rendering-method mobile --timeout 400 --expect-size 1920x1080 tools/atk08/strip.gd
  --task-id atk-08 -- --save-dir <repro> --out-dir <dir> --seconds 8 --every 0.08`; `tools/atk08/strip.py <dir> <png>`.
  In `/private/tmp/labyrinth_codex/atk-08/strips/`: `before/strip_{double_hit,bleed_move,fatigue_reshuffle}.png` and
  `{before,after}/strip_{midturn_fatigue,empower_cost}_{before,after}.png`.

## atk-10 follow-up: the rail lights the foe that hits you; numbers get their full time (2026-11-14)

Director decision on TODO 1 and 2: the rail never queues behind itself and no foe waits for it; a number's clock
starts at its first drawn frame. Rules, AI, numbers, analytics, pacing constants and rail tween durations unchanged.

**Why the rail showed nobody (or the previous foe).** Two causes:

1. *Queueing* (motion on). `combat_pacing.gd present_turn_order` kept one pending order behind the running tween, so a
   quick activation's highlight landed late or was skipped. Now a newer order ends the running motion at its end state
   (`run_scene.gd _finish_turn_order_transition_now`: its tweens stepped to their end, every slot reconciled to its
   baseline) and plays at once at its normal duration; a superseded request that is still waiting returns.
2. *Stale initiative* (motion on and off; the only cause with reduced motion). Enemy playback skips the engine's commit
   steps, so the playback state kept the round's starting current actor and queue. Each hit or defeat mid-activation
   re-projected the rail from it (`overlap_defeats`, `_animate_turn_order_alongside_defeats`), which cleared the acting
   foe's highlight just before its number and could flash the round's starting order. During enemy playback the rail
   now projects the slice's real initiative (`_turn_order_entries_from_state`: the engine's own pop on a probe of the
   pre-slice state, then the resolved state from the reschedule on).

**Late numbers.** In the hero's and the foes' attack frame paths a number's clock is attack-feedback time minus the
time it was first drawn; the final beat carries that offset for the numbers only (`floating_text_delay_seconds`, read
and removed by `_animate_floating_text_presentation`). Frame stepping and the other feedback keep the attack's clock.

Same seeds and settings as above, new passes `before` (this branch's base) and `after`
(`/private/tmp/labyrinth_codex/atk-10/receipts/`). Routes are the same fights in both passes; foe-hit counts differ
where a timing-dependent offer changed a turn. Round time is the presentation clock per fight (enemy rounds summed).

| Setting | Foe hits | Rail on the acting foe | Nobody | Another foe | Too brief (all receipts) | Round s per fight, median | max |
|---|---:|---:|---:|---:|---:|---:|---:|
| Normal | 277 → 284 | 182 → 284 | 93 → 0 | 2 → 0 | 10 → 0 | 43.3 → 41.3 | 140.2 → 133.5 |
| Normal, reduced motion | 75 → 75 | 65 → 75 | 10 → 0 | 0 → 0 | 0 → 1 | 23.0 → 22.9 | 67.5 → 67.4 |
| Fastest | 76 → 76 | 56 → 76 | 20 → 0 | 0 → 0 | 20 → 1 | 40.3 → 38.5 | 215.2 → 208.1 |
| Fastest, reduced motion | 75 → 75 | 65 → 75 | 10 → 0 | 0 → 0 | 1 → 2 | 37.9 → 37.8 | 104.7 → 104.5 |

- **Cost of the number fix:** 549 attacks at normal speed started their numbers later than contact, median 0.02 s,
  at most 0.145 s (fastest: 167, median 0.04 s, at most 0.18 s), at most 1.4 s summed over one fight. Rounds still got
  shorter, because the round's end no longer waits for a queue of rail motions: paired by fight, enemy-round time
  changed by a median of −1.6 s at normal and −1.0 s at fastest (no fight longer at fastest); with reduced motion,
  where neither fix adds or removes time, the paired change is −0.25…+0.31 s (the rerun noise of the headless clock).
- The remaining "too brief" flags (1–2 per setting) are a number whose last headless frame was 0.18–0.22 s long, so it
  expired between samples; the same crawler hit is flagged in both passes. One is a Vyraketh mark at fastest that stops
  being drawn at ~22% of its life in both passes (noted, not changed here).
- Native strips (cel look, 1920×1080, 100% UI, normal speed, cropped to the board and rail), `before/` and `after/` in
  `/private/tmp/labyrinth_codex/atk-10/strips/`: `strip_wrong_*` (seed 101, room (7,0), turn 2: Shale Bloomer's −4
  lands while the rail lights the Hoarfrost Seer → lights the Shale Bloomer), `strip_nobody_*` (seed 101, room (0,1),
  turn 4: the Ember Ticks' −2 B land with nobody lit → the acting Tick lit), `strip_tharokh_*` (seed 102, room (4,0),
  turn 14: −8 and −4 first drawn at 6% of their life → 0%; the −4 had nobody lit → Tharokh). The atk-08 wrong-foe save
  (seed 101, room (9,2)) did not recur: reruns take another route there, so these strips use real saves from
  `before-saves` (a base-code pass that keeps a save before every foe hit, `ATK08_REPRO_PER_CATEGORY=1000`).
- Rerun: `tools/atk08/receipts.py --root <dir> --task-prefix <id> run …` as above, then `report`, and `compare --before
  before --after after` for this table.

