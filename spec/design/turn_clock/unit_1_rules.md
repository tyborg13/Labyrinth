# Unit 1: Wait rule, copy, analytics, specs

Read [spec/turn_clock.md](../../turn_clock.md) first. It is the rule. This brief
says how to land it.

Files likely involved:
- `scripts/combat_engine.gd` (`finish_player_card` ~1940–2000, `prepare_next_player_turn` ~2782, `finish_player_activation` ~2179, `_projected_next_entry_for_current_actor` ~5290)
- `scripts/tempo_relic_rules.gd`
- `data/relics.json` (Pocket Sundial)
- `scripts/action_icon_library.gd` (`time` entry)
- `scripts/contextual_combat_tutorial.gd`
- `scripts/run_scene.gd` (analytics emission only: `_resolve_enemy_round` ~24050 and the pass and auto-pass handlers ~28023)
- `spec/card_balance_heuristic.md`, `tools/card_heuristic.py` (check only)
- `spec/analytics.md`
- `spec/relic_pool_overhaul/relic_data.py` (Pocket Sundial scoring row)
- tests: `tests/suites/initiative_order_suite.gd`, `tests/suites/relic_u4_suite.gd`, `tests/relic_u4_probe.gd`, plus any test that encodes "unused plays are free"

## Change

1. **Constant and helpers in `CombatEngine`:**
   - `const WAIT_TIME_PER_UNUSED_PLAY: int = 5`.
   - `func base_plays_waited(state, extra_plays_spent := 0) -> int` returns `max(0, mini(BASE_CARDS_PER_TURN, cards_per_turn) − plays_made − extra_plays_spent)`.
     - `plays_made` = play slots actually spent on cards this activation: `cards_played_this_turn` minus plays forfeited by Freeze.
     - It is 0 outside the player's turn.
   - `func pending_wait_time(state, extra_plays_spent := 0) -> int` returns `WAIT_TIME_PER_UNUSED_PLAY * base_plays_waited(...)`.
2. **Freeze forfeits.** Both places that force `cards_played_this_turn = _card_play_capacity(...)` because of `frozen` (`finish_player_card` ~1997 and `prepare_next_player_turn` ~2832) must record how many slots they forfeited. Use a per-activation field that `prepare_next_player_turn` resets, e.g. `plays_forfeited_this_turn`, defaulting to 0 on old saves. Find and treat any other status-driven forfeit the same way. A frozen activation with no cards played therefore waits 2 × 5.
3. **Scheduling (`TempoRelicRules`).** Every hero projection and every scheduled hero turn adds `pending_wait_time(state, plays_spent)`.
   - `next_turn_time`: add the Wait. Replace the `unused_play_time_reduction` term with the new Pocket Sundial term (item 4). Keep the Borrowed Hourglass shortcut (`return clock`) exactly as is.
   - `end_activation`, normal path: unchanged apart from going through `next_turn_time`.
   - `end_activation`, extra-turn path: the debt added is everything this activation would have cost: `player_turn_time_spent + pending_wait_time − sundial reduction`.
   - `is_late`: the hero time must equal the rail's projection for that card. That is `clock + base + debt + spent + extra_time + pending_wait_time(state, plays_spent) − sundial`, with no Borrowed Hourglass shortcut. Check the in-resolution accounting: `_tempo_card_time` and `_tempo_plays_spent` are stamped while the card resolves, before `finish_player_card` adds its Time and slots, so neither gets double counted. Add a test that the rail's Late mark while previewing card X equals the bonus applied when X resolves, for both a full turn and a partial turn.
4. **Pocket Sundial.**
   - Replace its effect with a new type `full_turn_time_reduction`, `{amount: 2}`. When `base_plays_waited(state, plays_spent) == 0`, the next turn comes `amount` sooner.
   - Remove the `unused_play_time_reduction` type and its helper. Nothing else uses it.
   - New description: `If you use both @icon(card_play) in a turn, your next turn comes 2 @icon(time) sooner.`
   - Update its row in `spec/relic_pool_overhaul/relic_data.py`, and `proposal.json` if it is the generated source of truth. Keep its rarity.
5. **Projection field for the HUD.** In `_projected_next_entry_for_current_actor` (player branch), when a card preview is active, add `projected_time_delta` = the projection with the preview minus the projection without it. A Time-2 card with a base play still open gives `−3`, and a Time-6 card gives `+1`. Keep `projected_time_cost` as is. Also expose `projected_wait_time` (the Wait included in the shown projection) for the rail tooltip.
6. **Copy.**
   - `action_icon_library.gd` `time.description`: `Delays your next turn. Each unused play takes 5.`
   - Tutorial `PHASE_TURN_CLOCK` (both variants, pointer and controller text): `Card Time places your next turn. An unused play still takes 5, so faster cards bring you back sooner.`
   - Tutorial `PHASE_PASS_TURN`, first variant only (lesson 6/8, pointer and controller): `Pass ends your turn. Each unused play still takes 5 Time. The preview shows what enemies do next.`
   - Leave the "Your actions are spent…" variant unchanged.
   - Check the tutorial bubble does not overflow (an existing tutorial probe or test, if one covers text fit).
7. **Analytics.** Add an append-only `player_turn_ended` event, written once per hero activation end through the same durable outbox and checkpoint path that `_resolve_enemy_round` already uses. Never write it from a preview (`_pass_preview_summary` and the other `finish_player_activation` callers at ~15372, 18835 and 19242 are previews). Payload:
   - `end_reason`: `pass` / `auto` / `frozen`.
   - `plays_made`, `base_plays_waited`, `unused_bonus_plays`.
   - `card_time` (the `player_turn_time_spent` before ending), `wait_time`, `sundial_reduction`.
   - `borrowed_extra_turn` (bool), `next_turn_eta` (scheduled time minus clock).
   - `enemy_activations_before_next_turn`: count the enemy entries before the hero's next entry in the post-schedule `current_turn_order` projection.

   Document the event in `spec/analytics.md` (event list plus a short section). It must not change any existing event.
8. **Specs.**
   - `spec/card_balance_heuristic.md` "Current Gameplay Assumptions": the hero turn now includes Wait, and the tempo term `(5 − time) × 0.45` is the saving against waiting, so the coefficient is unchanged. Link `turn_clock.md`.
   - Check `tools/card_heuristic.py` for any assumption about passing or unused plays. Change code only if it models one, and say what you found.
   - Fix any other spec line that states the old rule (`grep -rn "time spent on played cards"`).

## Keep

- Full two-card turns schedule to the identical Time as before. Prove it with a test.
- Enemy scheduling, Stagger, Quicken, Flurry payment, Empower surcharge, Winter's Hourglass reserve, Borrowed Time, and the extra turn and its trigger all stay as they are.
- Save compatibility: a new optional field defaults to 0, and old saves load. No other persistent field changes.
- Existing analytics event payloads.
- Do not touch the HUD rendering in `run_scene.gd`. Unit 2 owns it. The only `run_scene.gd` change allowed is the analytics emission.

## Proof

- Focused tests in `tests/suites/initiative_order_suite.gd`, or a new `tests/suites/turn_clock_wait_suite.gd` wired into the full suite. Each case asserts the exact scheduled Time:
  - pass (+19);
  - one Time-4 card (+18);
  - two Time-4 cards (+17, unchanged);
  - Flurry (no Wait);
  - a kill refund left unused (no extra Wait);
  - a kill refund used plus one ordinary play (no Wait);
  - Whirling Sash's third play unused (no Wait);
  - Measured Breath banking (Wait still paid);
  - Freeze at turn start (+19);
  - a mid-turn freeze;
  - Borrowed Hourglass debt including Wait;
  - Pocket Sundial (−2 only when both plays are made);
  - Quick-Draw Bandolier item (not a play);
  - free Rite (not a play);
  - `projected_time_delta` for Time 2 / 5 / 6 cards, at turn start and with one play left;
  - Late Bell agreement (item 3).
- Update existing assertions that encode the old free-unused-play behaviour. List each one in your final message with its old value and its new value.
- `player_turn_ended`: one event per activation end; previews write none; payload values for a pass and for a full turn.
- Run the full suite: `python3 tools/godot_task_runner.py --task-id <task-id> --timeout 900 --stream -- godot --headless --path . --script tests/run_tests.gd`. Also run `python3 tests/test_icon_identity_policy.py` and the card heuristic check, if one exists in tests.
