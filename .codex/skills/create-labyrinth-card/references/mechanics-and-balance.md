# Mechanics And Balance

## Table Of Contents

- Card schema
- Current action model
- Element and rarity guidance
- Balance workflow
- Design traps to check manually
- Tests to consider

## Card Schema

`data/cards.json` is a dictionary keyed by `card_id`.

Use this shape for a normal reward card:

```json
"card_id_here": {
  "name": "Card Name",
  "element": "fire",
  "rarity": "common",
  "burn": false,
  "health_cost": 0,
  "description": "Short readable fallback.",
  "accent": "#d9623f",
  "art_path": "res://assets/art/cards/card_id_here.png",
  "actions": [
    {"type": "ranged", "damage": 7, "range": 5, "burn": 2}
  ]
}
```

For neutral cards, follow the existing pool and usually omit `element`; `GameData.card_element_from_def` falls back to `ElementData.NONE`. For elemental cards, set `element` and use the matching accent from `scripts/element_data.gd`:

- Fire: `#d9623f`
- Ice: `#5fa7d8`
- Lightning: `#cfb347`
- Air: `#72bea5`
- Earth: `#89a15b`

`rarity` drives reward pools, upgrade cost scaling, sorting, and frame texture selection. Reward cards use `common`, `uncommon`, or `rare`; `starter` is reserved for the starting deck.

Top-level costs:

- `burn: true`: exhausts the card for the rest of combat and renders as an Exhaust cost row.
- `health_cost: N`: pays health after the card resolves and renders as a Health Cost token.

## Current Action Model

Existing card action types:

- `move`: fields `range`.
- `blink`: fields `range`; teleports to any passable, unoccupied diamond tile.
- `melee`: fields `damage`, `range`; range 1 is adjacent, higher range is supported.
- `ranged`: fields `damage`, `range`; requires line of sight.
- `aoe`: fields `damage`, `range`, `pattern`, `rotate`; range 0 anchors on the player, range > 0 targets a visible center tile.
- `push`: fields `amount`, optional `damage`, `range`; forced movement away from the player/source.
- `pull`: fields `amount`, optional `damage`, `range`; forced movement toward the player/source.
- `block`: fields `amount`; temporary defense.
- `stoneskin`: fields `amount`; persistent defense.
- `heal`: fields `amount`; capped at max HP.
- `draw`: fields `amount`.

Existing attack keywords stored on attack-like actions:

- `burn`: fire damage over time; ticks at enemy/player start of turn and decays.
- `poison`: delayed damage; current combat code uses a 2-turn delay.
- `freeze`: next-turn skip and incoming damage multiplier while active.
- `shock`: enemy keeps movement but loses non-movement actions; player is restricted to move/blink.
- `stun`: skip next action/turn; currently used by traps and enemy/status internals more than player cards.
- `chain`: jumps to additional nearby enemies.
- `push` / `pull`: can also be keyword fields on damage actions.

Keep action count modest. `GameData._action_upgrade_options` stops offering action-add upgrades when a card already has 4 actions, and CardWidget icon rows become cramped as rows multiply.

## Element And Rarity Guidance

Use element identity to shape mechanics:

- Fire: burn, direct damage, larger area pressure. AOE plus burn scales hot; check the full pool.
- Ice: freeze, lower damage, precise ranged or line patterns. Freeze is expensive because it denies a turn and doubles incoming damage.
- Lightning: shock, chain, ranged tempo. Zekarion is shock-immune, so do not make shock the only boss plan for a rare.
- Air: movement, push, pull, long reach, positional payoffs. Manually check trap abuse because the heuristic is conservative there.
- Earth: stoneskin, poison, heavy melee, anchoring defenses. Persistent stoneskin and delayed poison need different validation than immediate damage.
- Neutral: baseline weapon, mobility, draw, healing, and block tools.

Heuristic bands from `spec/card_balance_heuristic.md`:

- `7+`: likely overtuned unless rare/build-around/deliberate spike.
- `4-6`: premium.
- `2-3.5`: healthy filler or core pool.
- `1-2`: weak or niche.
- `<1`: under-rate standalone.

Do not balance only to a number. Compare against similar cards by role, element, rarity, reach, and setup burden.

## Balance Workflow

1. Read `spec/card_balance_heuristic.md` and inspect similar cards in `data/cards.json`.
2. Sketch the card in existing action primitives first.
3. Add or edit the card data.
4. Run:
   ```bash
   python3 tools/card_heuristic.py --card-id <card_id> --show-breakdown
   python3 tools/card_heuristic.py
   ```
5. Compare nearby cards in the full-pool output.
6. If the card intentionally deviates, document why in the final response or review context.
7. If combat assumptions, status behavior, action keywords, cards/draw per turn, fatigue, room spacing, enemy assumptions, or encounter pacing changed, update both `spec/card_balance_heuristic.md` and `tools/card_heuristic.py`.

## Design Traps To Check Manually

- Early reach: move or blink before melee drastically changes playability.
- Range and line of sight: long range is stronger when paired with control.
- AOE pattern size: range 0 close AOE and ranged AOE have different playability assumptions.
- Forced movement: trap setups and enemy displacement can overperform the heuristic.
- Draw: draw plus another useful action gets extra value and can offset exhaust-card penalties.
- Health costs: strong for rare spikes, but they affect analytics and player survivability.
- Exhaust: top-level `burn` removes future combat use; use deliberately.
- Healing cards: `GameData.reward_offer_weight` downweights heal cards in rewards.

## Tests To Consider

For data-only cards, at least run JSON parsing and the heuristic. For mechanic or UI changes, add focused tests to `tests/run_tests.gd` around:

- `GameData.card_def`, reward pools, and progression card mods.
- `CombatEngine.valid_targets_for_player_action` and `apply_player_action`.
- `ActionIconLibrary.tokens_for_action` and tooltips.
- `RunScene._card_widget_display` if preview/final damage or summary rows change.
- Analytics payload fields if card play, draw, reward, status timing, or combat outcome behavior changes.
