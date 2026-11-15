# atk-05: where the owner's Health actually went (real play logs, 2026-11-14)

## Short answer

- Across 88 fights (8 Jul to 13 Nov) you lost about 490 Health. Almost two thirds came from enemy attacks: 46% from a
  foe's ordinary move, 17% from a foe acting twice before your next turn (23% since October).
- Most of the rest you paid on your own turn: Bleed when you move or attack after a Crawler or Harrier hit (13%),
  card and Empower costs plus two of your own blasts in August (13%), and Fatigue when your deck reshuffled (9%).
  Fire, traps, rule effects, summoned foes and foes hidden in the dark cost 3 Health in all.
- Of six deaths, three were a foe's ordinary attack, two were foes acting twice (8 and 22 Oct), and one was your own
  Cinder Bloom (17 Aug). The latest, Iskaldra on 13 Nov, came in the round after Freeze skipped your turn.
- Since 22 Oct, when the logs start recording how turns end, a third of the enemy damage followed a PASS, a third a
  final move and a quarter a final card. Until today's build a card that ended your turn never said so, and dragging
  a card hid the forecast.
- Today's build shows enemy damage before you commit: the PASS panel counts every visible foe's moves, second moves
  included, and the red discs follow it. Gaps: the red tiles show only a foe's first move; Bleed and Fatigue show only
  while you preview or hover PASS; nothing warns that Freeze will skip your turn, or shows the round after it.
- No fight was played on a build with atk-01..04 (the data ends 13 Nov), so their effect can't be measured yet.

## Data and method

- **Data** (copies in `/private/tmp/labyrinth_codex/atk-05/data/`): main Steam profile (74 fights, 24 days), demo (6),
  Playtest rd-05, rd-08, occ-02 (8); other Playtest profiles have no analytics, Visual Probe ones are skipped. 368 rounds.
- **Losses.** A card's event carries the Health before it plus its own change; an enemy round's events carry the Health
  after it. Each drop is split by the round's records (foe `target_losses` on the hero, rule `damage_to_player`,
  turn-start fire). The repeat split matches `enemy_activations_before_next_turn` in 104 of 109 recorded rounds.
  No event records Bleed or Fatigue: a drop where the draw pile grew is Fatigue; a drop on your action after a Bleed
  hit is Bleed.
- **Log quirks corrected.** Fight-ending rounds lose their combat id, and Oct/early-Nov turn-end receipts could arrive
  late; both are re-attached. Builds before 15 Jul logged no enemy actions; up to 27 Jul Health was logged ×10.
- **Rerun:** `python3 tools/atk05/owner_damage.py /private/tmp/labyrinth_codex/atk-05/data` (`--spot-ranks 1,4,10`
  prints raw event sequences, `--json <file>` every loss row). Standard library only; no ids in the output.

## Health lost by source (gross; heals not netted)

| Source | Health lost | Share | Largest hit | Deaths | Near-deaths (≤25%) | Since 1 Oct | Share |
|---|---:|---:|---:|---:|---:|---:|---:|
| Foe's first move this round | 227.5 | 46% | 8 | 3 | 4 | 89 | 46% |
| Same foe acting again before your turn | 82 | 17% | 5 | 2 | 2 | 45 | 23% |
| Foe that arrived this round (summon, split) | 0 | 0% | - | 0 | 0 | 0 | 0% |
| Battlefield rule beat | 0 | 0% | - | 0 | 0 | 0 | 0% |
| Bleed, paid as you move or attack | 62 | 13% | 2 | 0 | 4 | 19 | 10% |
| Surface or trap (fire: walked in 2, at turn start 1) | 3 | 1% | 2 | 0 | 0 | 3 | 2% |
| Self-inflicted: card/Empower costs 40, own blasts 24 | 64 | 13% | 14 | 1 | 0 | 13 | 7% |
| Fatigue (deck reshuffle) | 43.6 | 9% | 2 | 0 | 2 | 21 | 11% |
| Unknown | 7.5 | 2% | 2 | 0 | 1 | 5 | 3% |
| All | 489.6 | 100% | 14 | 6 | 10 | 195 | 100% |

- No hero status ticked at turn start or end (all were Bleed on your own action). Hidden Umbra foes dealt 0 in all 81
  finished fights (`umbra_hidden_attack_damage_received`); summoned and split foes never hit you.
- Self: Cinder Bloom at the Cinder Crown, 17 Aug (14, a death) and Spark Focus, 19 Aug (10), both under the old rules;
  Bloody Lunge (37, 1 a play) and Glassbone Guard (3). Unknown: two July rounds with no enemy events (2.5), an 8 Oct
  round where only a Dust Acolyte acted and nothing recorded the loss (2), drops on your own turn with no record (3).

## How the turn before an enemy round ended (recorded from 22 Oct)

| Turn ended by | Enemy rounds | Rounds that hurt | Health lost | Share of 102 |
|---|---:|---:|---:|---:|
| PASS button | 59 | 10 | 28 | 27% |
| PASS with plays left (a Wait) | 10 | 2 | 6 | 6% |
| Its last move (auto-pass) | 12 | 7 | 33 | 32% |
| Its last card (auto-pass) | 27 | 10 | 27 | 26% |
| Frozen (turn skipped) | 1 | 1 | 8 | 8% |

Not logged before 22 Oct (254 rounds, 252 Health). Today PASS, a final move and a final card all show the forecast
before the click. Before atk-02 (14 Nov) a final card never said "Ends turn", and dragging a card hid the panel
(`pass_forecast_presentation.gd allowed`). A frozen turn allows only PASS, and nothing warned of it.

## The 15 biggest enemy rounds

| Date | Fight | Lost (Health) | Foes | Categories | Turn ended by |
|---|---|---:|---|---|---|
| 15 Jul | Sooted Spine | 11 (35→24/36) | Ash Acolyte 4, Bone Harrier 4, Tunnel Crawler 3 | first 11 | not recorded |
| 15 Jul | Bleak Grotto | 10 (28.5→18.5/36) | Bone Harrier 7, Ash Warden 3 | first 10 | not recorded |
| 26 Jul | Crooked Spine | 10 (17.5→7.5/36) | Tunnel Crawler 5, Dust Acolyte 5 | first 5, repeat 5 | not recorded · near-death |
| 8 Oct | Fevered Vault | 9 (9→0/24) | Stone Warden 5, Bone Harrier 4 | repeat 9 | not recorded · death |
| 8 Oct | The Rime Tyrant's Court | 9 (13→4/24) | Iskaldra 7 | first 7, Fatigue 2 | not recorded · near-death |
| 26 Jul | Fevered Passage | 8.5 (21→12.5/36) | Dust Acolyte 7 | first 7, Fatigue 1.5 | not recorded |
| 20 Jul | Tempest God's Perch | 8 (21.4→13.4/36) | Zekarion 8 | first 8 | not recorded |
| 31 Jul | Shuttered Grotto | 8 (20→12/24) | Tunnel Crawler 8 | first 8 | not recorded |
| 13 Nov | Warden pack (section 2) | 8 (10→2/21) | Stone Warden 8 | first 8 | last move · near-death |
| 13 Nov | Iskaldra (section 2) | 8 (8→0/21) | Iskaldra 8 | first 8 | Frozen · death |
| 22 Oct | Crooked Grotto (section 2) | 7 (7→0/24) | Tunnel Crawler 4, Dust Acolyte 3 | repeat 7 | PASS · death |
| 16 Jul | Bleak Sanctum | 6.5 (25.5→19/36) | Ash Warden 5 | repeat 5, Fatigue 1.5 | not recorded |
| 16 Jul | Sooted Gallery | 6 (23→17/36) | Tunnel Crawler 6 | repeat 5, first 1 | not recorded |
| 26 Jul | Fevered Hall | 6 (33→27/36) | Tunnel Crawler 6 | first 6 | not recorded |
| 31 Jul | Shuttered Spine | 6 (21→15/24) | Tunnel Crawler 6 | first 6 | not recorded |

**Before / after 14 Nov (atk-01..04):** all 489.6 Health is before; the newest event is 13 Nov 19:08, so no "after" yet.

## Disclosure today (this branch: atk-01..04 merged)

| Source (Health; since 1 Oct) | PASS panel numbers | "?" row | Red disc | Red tiles at rest | Otherwise |
|---|---|---|---|---|---|
| Foe's first move (227.5; 89) | yes | - | yes | yes | - |
| Same foe again (82; 45) | yes, "×N" row | "×2 ?" if its roll is unknown | yes, ×2 pip | first move only | - |
| Arrived this round (0) | no | turn-clock "?" | no | no | - |
| Rule beat (0) | yes | - | yes, on its source | yes, due tiles | - |
| Bleed as you act (62; 19) | only in an action's preview | - | - | - | Bleed icon on the hero; preview chips |
| Surface or trap (3; 3) | yes (turn-start fire; a previewed walk) | - | - | - | path chip while previewing |
| Self: costs 40, own blasts 24 (64; 13) | only in an action's preview | - | - | - | costs printed on card/Empower; "You: −N HP" chip |
| Fatigue (43.6; 21) | yes, Fatigue row | - | - | - | at rest only the draw-pile count |
| Round after a Frozen turn (8; 8; part of first move) | no: the forecast stops at the skipped turn | - | no | no | nothing |

Code (`scripts/`; agrees with `atk01_forecast_audit.md`): panel `pass_forecast_focus_tooltip.gd rows`; simulation
`combat_engine.gd advance_revealed_enemy_actions_preview` + `pass_forecast_repeats.gd`, stopping at the next hero
entry, then `pass_forecast_turn_start.gd`; no status field in `run_scene.gd _pass_preview_summary_for_phase_result`;
discs `pass_forecast_discs.gd apply`; tiles `intent_badges.gd build` (first-activation `enemy_threat_tiles`) and
`battlefield_rule_view.gd`; an action's own loss `pass_forecast_action_source.gd visibility_safe`; chips
`run_scene.gd _movement_player_delta_chips`, `_friendly_damage_preview_chips`; Bleed `_trigger_player_bleed_for_action`.

## Candidate fixes, ranked by Health lost (not decided)

1. **TODO_DESIGN_repeat_threat_tiles** (82; 45 since Oct; 2 deaths): red tiles show only the first move. Options: show
   the second move's reach in a second tone or with the ×2 tag; show it only while the foe or its pip is hovered; or
   leave the tiles and rely on the disc.
2. **TODO_DESIGN_bleed_cost_at_rest** (62; 19): the Health shows only in previews. Options: a "−N" mark on hand
   cards and movement while you Bleed; a PASS-panel Bleed row when the round will leave you Bleeding; a per-action
   ghost on the Health bar; or keep the chips.
3. **TODO_DESIGN_fatigue_at_rest** (43.6; 21): PASS panel only. Options: a Fatigue "−N" mark on the draw pile when the
   next draw reshuffles; a mark on the hero's next rail slot; or panel only.
4. **TODO_DESIGN_self_blast_warning** (24, August, old rules; 0 since): a chip and the panel while aiming. Options: keep
   them, or tint the target in danger ink when the card would hurt you.
5. **TODO_DESIGN_frozen_turn_forecast** (8; 1 death): the forecast can show the freezing hit, not the skipped turn or
   the round after. Options: a "next turn skipped" Freeze row; a forecast through the skipped turn; or both.
