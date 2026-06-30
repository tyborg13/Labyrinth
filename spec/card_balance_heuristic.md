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
- Player turns now run on an initiative clock instead of a fixed player-then-all-
  enemies round. The player starts combat active, then their next turn is
  scheduled at `base initiative + time spent on played cards`.
- Player base initiative starts at `9`, is reduced by `1` per Agility point,
  and floors at `5`.
- Printed cards carry a `time` cost on a `1-10` scale. The current baseline
  card is `5` time; fast cards are meant to be a real initiative advantage,
  while heavy cards can let enemies lap the player if overplayed.
- Enemies reveal an intent before entering the queue. Initial enemy slots and
  repeat enemy slots both use `enemy base initiative + revealed intent time`;
  initial slots add a small enemy-index stagger so simultaneous spawns stay
  readable.
- Killing an enemy with a card grants `+1` card play for the turn, so high
  damage gets a modest execute-tempo premium.
- Fatigue starts at `1.5` health and increases by `0.1` health each reshuffle.
- Each combat tracks room-wide elemental intensity for fire, ice, lightning,
  air, and earth. The room's element starts at intensity `1`; other elements
  start at `0`.
- Enemy preview block matters immediately during the player turn.
- Freeze doubles incoming damage and skips the enemy's next turn.
- Pierce attacks deal HP damage through block and stoneskin without removing
  those defenses.
- Shock lets the enemy keep movement, but strips non-movement actions for that
  turn.
- Burn ticks at enemy start of turn and decays by `1`.
- Bleed ticks at enemy start of turn and decays by `1`. It is physical
  pressure rather than elemental setup.
- Expose adds damage to the next hit against the target, then clears.
- Sunder removes block and stoneskin before damage lands.
- Poison lands after a two-turn delay.
- Stoneskin is persistent defense and is valued above temporary block.
- Illusions are stationary, have only health, and redirect enemies that are
  closer to the illusion than to the player. If player-side actors are tied at
  the same distance, enemies choose randomly among the tied targets.

Encounter calibration is also important:

- Standard rooms repeat in four-depth sequences: the first three depths of each
  sequence average about `3`, `4`, and `5` enemies, and the fourth depth is a
  boss gate. Lateral rooms remain a deck-building route choice; the map only
  opens an emergency outward loop escape when a room has no revealed,
  unsealed same-depth-or-deeper exit.
- First-sequence standard rooms now use a wider local band. Depth `1` enemies
  have `85%` HP and their damaging/support actions are shifted down by `1`
  player-scale point, depth `2` uses the base roster, and depth `3` enemies
  have `112%` HP without an extra generic damage/support bump.
  Enemy base initiative
  is mostly roster-driven: lightning wisps and tunnel crawlers are fast,
  harriers are quick, acolytes are baseline, and wardens are slow. At depth `1`,
  weighted first/repeat cycles before the initial spawn stagger are roughly
  `11` for wisps, `13` for crawlers, `13.4` for harriers, `16.25` for
  acolytes, and `20.25` for wardens; Zekarion cycles around `19.25` before
  summon forcing. Depth reduces enemy base initiative by up to `4` over time.
- Later sequences keep the same local density and elemental-control curve, but
  raise the baseline by `+45%` max HP, `+4` max HP, `+2` attack damage, and
  `+2` block/stoneskin per completed sequence.
- Zekarion's 2x2 footprint makes attack reach feel larger than printed range.
  His Tempest Breath is intentionally capped at ranged `3` after a one-tile
  advance so corner repositioning can produce real safe tiles in open boss
  rooms.
- Rooms reserve a small halo around the player's entry tile, then seed enemies
  with weighted randomness across the room. Placement softly discourages
  adjacent pileups and same-corner clusters, but no longer pushes enemies to
  the far side by default. This should make turn-1 reach and early enemy threat
  more variable than the old far-spawn calibration.
- Elemental combat rooms seed `2-3` traps across eligible passable floor tiles,
  including the playable edge band, while still avoiding occupied tiles and the
  player's entry halo. Traps blast adjacent tiles when stepped on or attacked,
  so forced movement and area targeting can create higher positional upside and
  risk than the old single-tile trap model.
- Generated trap damage uses a stronger positional payoff curve:
  `6/7/8` player-scale damage at local depths `1/2/3`, with boss-depth
  traps at `9` and `+2` player-scale damage per completed depth sequence.
  Depth-3 fire and earth trap statuses are capped at `2`.
- Fire burn ramps gently in the first sequence: depth `1-2` fire enemy attacks
  and traps apply shallow burn pressure, then deeper standard fire rooms restore
  the heavier burn payload.
- Every room places a `4` HP healing potion and a `4` block rusty shield as
  floor pickups. Combat rooms also scatter `5-7` low-HP boxes/crates across
  eligible passable floor tiles, including edge-band and corner floor tiles when
  connectivity stays intact. They block movement, do not block line of sight,
  and can be destroyed by player or enemy attacks.

The heuristic still rewards cards that compress setup and payoff into the same
play, but early reach assumptions should be reprobed before making fine-grained
mobility or range coefficient changes, especially now that perimeter routes are
not guaranteed to stay clear.

## Formula

The total score is:

`EV = offense + control + defense + flow + elemental_intensity + mobility + synergy + tempo - health_cost - exhaust_card_penalty`

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
- Card Play: `0.75` per added card play this turn
- Elemental intensity gain: `0.70` per point
- High-damage kill-card-play premium: up to `0.45`, scaled by damage,
  playability, and target count
- Illusion health: `0.48` per point
- Illusion placement range: `0.12` per tile
- Pure move: `0.25` per tile
- Pure blink: `0.33` per tile
- Move on an attacking card: `0.08` per tile
- Blink on an attacking card: `0.12` per tile
- Health cost: `1.0` per HP
- Exhaust-card penalty: `0.55`
- Card time tempo: `(5 - time) * 0.45`
- AOE base target multiplier: `1.20`
- AOE extra tile multiplier: `0.10`
- Rotatable asymmetric AOE orientation bonus: `0.05`
- Chain extra target bonus: `0.45`
- Pierce defense bypass: `0.75`
- Bleed delayed physical damage: `0.40` per stack
- Expose next-hit setup: `0.32` per point
- Sunder defense removal: `0.20` per point
- Freeze: `3.8`
- Shock: `2.5`
- Immobilize one-turn movement lock: `1.7`
- Push: `0.28` per tile
- Pull: `0.14` per tile
- Directed push/pull bonus: `0.03` per forced-movement tile

Status damage proxies:

- Burn effective damage: `0.75 * stacks + 0.12 * stacks^2`
- Poison effective damage: `0.70 * stacks`

Synergy bonuses:

- `+0.40` for `move/blink + attack`
- `+0.25` for `attack + defense`
- `+0.25` for `attack + status`
- `+0.25` for `draw + another useful action`
- `+0.20` for `card play + another useful action`
- `+0.40` for `draw + card play`
- `+0.20` for `move + push/pull`
- `+0.40` for `move + defense` on non-attack cards
- `+0.30` for `illusion + move/blink`
- `+0.25` when `illusion` appears before later movement on the same card
- `+0.18` when an elemental card raises its own element's intensity
- `+0.30` when a card both raises intensity and has intensity-gated text

## Elemental Intensity Gating

For heuristic purposes, elemental cards are scored as if they are played in a
room of their own element, so their element starts at intensity `1`. Intensity
actions on the same card update this local context before later actions are
valued.

Actions with `requires_intensity` and attack-side `intensity_bonus` clauses are
discounted by how far their threshold is from the current local context:

- Already met: `1.00`
- Short by `1`: `0.62`
- Short by `2`: `0.44`
- Short by `3`: `0.28`
- Short by `4+`: `0.18`

For `intensity_bonus`, the base action is scored normally and only the bonus
damage, status, chain, pierce, or forced movement is discounted. This mirrors
the card UI convention that a card should generally have one targetable attack,
with intensity-gated upside shown as a shaded modifier row instead of a second
attack. This makes mild `2+` text meaningful in matching rooms, gives
self-enabling cards credit for sequencing, and keeps large `4+` payoffs from
scoring as always-on standalone power.

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
range. Rotatable asymmetric AOE patterns get a small orientation bonus because
the player can rotate the pattern while aiming around the hovered center tile.
Push and pull get a small directed-force bonus because the player chooses among
legal straight cardinal lines after choosing the target, constrained to directions
that move the target farther from or closer to the caster:

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
- How often pierce converts damage through block or stoneskin; its bonus is a
  conditional pool-average estimate rather than enemy-intent-specific value.
- Enemy target redirection from illusion placement, especially when board geometry
  lets one illusion absorb multiple enemy turns or when tied target distances
  make redirection probabilistic
- Extreme deck-thinning or fatigue exploitation
- Exact frequency of matching-element rooms after a player drafts heavily into
  one element
- Exact initiative snowballing from multi-enemy queues, especially where a
  fast enemy acts twice before a slow, high-time player build comes back online

If a card is intentionally better than its standalone score because of one of
those factors, note that explicitly in review or commit context.

## Maintenance Rules

Update this document and `tools/card_heuristic.py` together whenever any of the
following change:

- cards per turn or draw per turn
- player base initiative, Agility scaling, card time costs, enemy base
  initiative, or enemy intent time costs
- fatigue rules
- status behavior
- damage, block, stoneskin, or healing semantics
- enemy preview rules
- room size, enemy spacing, trap count/placement, or spawn selection
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

### Source-Aware Views

The default command still scores every card in `data/cards.json`, which is useful
for a global sanity check but mixes cards from different acquisition paths. Use a
source filter when comparing cards against peers:

```bash
python3 tools/card_heuristic.py --reward-pool
python3 tools/card_heuristic.py --elemental-rewards
python3 tools/card_heuristic.py --equipment
python3 tools/card_heuristic.py --starters
```

`--reward-pool` is the normal card-reward view: cards with reward-pool metadata
after excluding equipment-granted cards and starters. `--elemental-rewards` is
the elemental subset of that normal reward pool. `--equipment` is the
equipment-only view, excluding starter cards granted by starting gear.
`--neutral-rewards` isolates neutral normal rewards, which is useful when
checking whether old neutral reward metadata is still intentional.

Equipment cards are identified from `data/equipment.json`, not only from card
metadata. Starter cards are identified by either `starter: true` or
`rarity: "starter"` so older starter cards do not leak into reward-pool or
equipment-only balance reviews just because they lack explicit
`reward_pool: false`.

Source tags are shown automatically in filtered text output, can be added to any
text view with `--show-source`, and are always included in `--json` output.

When reviewing or adding cards:

1. Run the tool for the changed card and the full pool.
2. Run the source view that matches how the card enters a deck: `--equipment`
   for gear cards, `--starters` for starting-deck cards, and `--reward-pool` or
   `--elemental-rewards` for magic rewards.
3. Compare the score against similar cards, not just the global ranking.
4. Decide whether any intentional over- or under-rate is justified by build,
   rarity, or encounter role.
5. If the underlying combat assumptions changed, update the heuristic first.
