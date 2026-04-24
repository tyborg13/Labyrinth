# Card Balance Heuristic

This document defines the current developer-facing heuristic for valuing cards in
`Labyrinth`. The goal is not to replace playtesting. The goal is to give us a
consistent, formulaic baseline that estimates each card's value as
`health saved equivalent` against a blank draw.

Use this together with `python3 tools/card_heuristic.py` whenever you create,
modify, or review cards.

## Scope

The heuristic is calibrated against the current live combat rules and encounter
generation, not the older prototype notes.

The main assumptions come from:

- `scripts/combat_engine.gd`
- `scripts/room_generator.gd`
- `data/cards.json`
- `data/enemies.json`

## Current Gameplay Assumptions

These assumptions are baked into the current coefficients:

- Player pace: `2` cards per turn and `2` draw per turn.
- Fatigue starts at `2` health and increases by `1` each reshuffle.
- Enemy preview block matters immediately during the player turn.
- Freeze doubles incoming damage and skips the enemy's next turn.
- Shock lets the enemy keep movement, but strips non-movement actions for that
  turn.
- Burn ticks at enemy start of turn and decays by `1`.
- Poison lands after a two-turn delay.
- Stoneskin is persistent defense and is valued above temporary block.

Encounter calibration is also important:

- Standard rooms currently average about `3`, `4`, and `5` enemies at depths
  `1`, `2`, and `3`.
- Standard-room enemies average about `13.78` max HP and `3.03` raw damage per
  enemy turn across the non-boss roster.
- Rooms reserve a small halo around the player's entry tile, then seed enemies
  with weighted randomness across the room. Placement softly discourages
  adjacent pileups and same-corner clusters, but no longer pushes enemies to
  the far side by default. This should make turn-1 reach and early enemy threat
  more variable than the old far-spawn calibration.

The heuristic still rewards cards that compress setup and payoff into the same
play, but early reach assumptions should be reprobed before making fine-grained
mobility or range coefficient changes.

## Formula

The total score is:

`EV = offense + control + defense + flow + mobility + synergy - health_cost - burn_card_penalty`

Interpret the result as a relative `health saved equivalent` score.

Higher scores mean the card is expected to preserve more future health by
ending fights faster, denying enemy turns, or preventing incoming damage.

## Coefficients

These are the current default weights used by `tools/card_heuristic.py`:

- Immediate damage: `0.45 * damage + 0.012 * damage^2`
- Block: `0.25` per point
- Stoneskin: `0.40` per point
- Heal: `0.90` per point
- Draw: `0.85` per card
- Pure move: `0.25` per tile
- Pure blink: `0.33` per tile
- Move on an attacking card: `0.08` per tile
- Blink on an attacking card: `0.12` per tile
- Health cost: `1.0` per HP
- Burn-card penalty: `0.55`
- AOE base target multiplier: `1.20`
- AOE extra tile multiplier: `0.10`
- Chain extra target bonus: `0.45`
- Freeze: `3.8`
- Shock: `2.5`
- Push: `0.28` per tile
- Pull: `0.14` per tile

Status damage proxies:

- Burn effective damage: `0.75 * stacks + 0.12 * stacks^2`
- Poison effective damage: `0.70 * stacks`

Synergy bonuses:

- `+0.40` for `move/blink + attack`
- `+0.25` for `attack + defense`
- `+0.25` for `attack + status`
- `+0.25` for `draw + another useful action`
- `+0.20` for `move + push/pull`
- `+0.40` for `move + defense` on non-attack cards

## Playability Factors

The heuristic does not treat all damage as equally reachable.

For melee attacks, playability is based on total reach after any earlier move or
blink in the same card:

- Reach `1`: `0.35`
- Reach `2`: `0.55`
- Reach `3`: `0.72`
- Reach `4`: `0.86`
- Reach `5+`: `0.95`

For ranged, ranged AOE, push, and pull attacks, playability is based on printed
range:

- Range `4` or less: `0.80`
- Range `5`: `0.88`
- Range `6`: `0.95`
- Range `7+`: `0.98`

Close AOE patterns use melee playability based on the player's effective reach
to adjacent tiles, then apply the AOE target multiplier.

This is the core reason `move + attack` and long-range control score so well.

## Interpreting Scores

Use the score bands as a first-pass curve check:

- `7+`: likely overtuned unless it is a rare build-around or deliberate spike
- `4-6`: premium
- `2-3.5`: healthy filler / core pool
- `1-2`: weak or niche
- `<1`: under-rate standalone

These bands are intentionally rough. Rarity targets should be derived from the
live card pool, not treated as fixed forever.

## Known Blind Spots

This heuristic is intentionally conservative about:

- Trap setups and forced-movement trap abuse
- Relic-specific synergies
- Multi-card combos that need a particular hand pattern
- Boss-only value
- Extreme deck-thinning or fatigue exploitation

If a card is intentionally better than its standalone score because of one of
those factors, note that explicitly in review or commit context.

## Maintenance Rules

Update this document and `tools/card_heuristic.py` together whenever any of the
following change:

- cards per turn or draw per turn
- fatigue rules
- status behavior
- damage, block, stoneskin, or healing semantics
- enemy preview rules
- room size, enemy spacing, or spawn selection
- enemy roster or intent pacing
- AOE, chain, push, or pull behavior
- new card action types or keywords

If you change the rules above and do not update the heuristic, future card work
will drift against stale assumptions.

## Workflow

To score the whole pool:

```bash
python3 tools/card_heuristic.py
```

To inspect a single card with a breakdown:

```bash
python3 tools/card_heuristic.py --card-id quick_stab --show-breakdown
```

To get machine-readable output:

```bash
python3 tools/card_heuristic.py --json
```

When reviewing or adding cards:

1. Run the tool for the changed card and the full pool.
2. Compare the score against similar cards, not just the global ranking.
3. Decide whether any intentional over- or under-rate is justified by build,
   rarity, or encounter role.
4. If the underlying combat assumptions changed, update the heuristic first.
