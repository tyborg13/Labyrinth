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

- Player pace: `2` cards per turn, `2` draw per turn, and a `7`-card
  maximum hand.
- Every player activation also starts with `2` tiles of independent movement.
  The player can split that pool before, between, or after printed card plays;
  movement costs no card play and no initiative Time. Printed Move and Blink
  actions remain additional movement supplied by their cards.
- The scorer does not add those `2` shared movement tiles to every card's
  intrinsic reach or value. They are a turn-level positioning resource, so
  playability and realized-value analysis should compare movement cohorts while
  printed movement remains the only movement credited directly to a card.
- Combat uses natural player-facing units throughout: the player starts a new
  run at `24` HP, and authored damage, health, healing, block, stoneskin, and
  damaging statuses are stored and resolved without the retired `×10` layer.
- Player turns now run on an initiative clock instead of a fixed player-then-all-
  enemies round. The player starts combat active, then their next turn is
  scheduled at `base initiative + time spent on played cards`.
- Player base initiative is fixed at `9`. Qualitative progression skills do
  not permanently reduce it.
- Printed cards carry a `time` cost on a `1-10` scale. The current baseline
  card is `5` time; fast cards are meant to be a real initiative advantage,
  while heavy cards can let enemies lap the player if overplayed.
- Enemies reveal an intent before entering the queue. Initial enemy slots and
  repeat enemy slots both use `enemy base initiative + revealed intent time`;
  initial slots add a small enemy-index stagger so simultaneous spawns stay
  readable.
- Killing an enemy with a card grants `+1` card play for the turn, so high
  damage gets a modest execute-tempo premium.
- Flurry cards snapshot all card plays available when they begin, repeat their
  printed actions and health cost once per snapped play, and spend all snapped
  plays. The physical card's top-level Time cost is paid once. Plays gained
  during resolution remain available after the Flurry commits.
- Fatigue starts at `2` health and increases by `1` health each reshuffle.
- Each combat tracks room-wide elemental intensity for fire, ice, lightning,
  air, and earth. The room's element starts at intensity `1`; other elements
  start at `0`. Cards and elemental enemies share this resource: both sides can
  build it, threshold effects can gate on it, and stronger cards or enemy
  intents can consume it. Spending can deny a telegraphed enemy payoff or calm
  matching traps as well as fund a card.
- Enemy preview block matters immediately during the player turn.
- Freeze doubles incoming damage and skips the enemy's next turn.
- Pierce attacks deal HP damage through block and stoneskin without removing
  those defenses.
- Shock lets the enemy keep movement, but strips non-movement actions for that
  turn.
- Burn ticks at enemy start of turn and decays by `1`.
- Bleed is one-turn physical pressure: it triggers before the affected actor's
  resolved move or attack actions, stacks additively by damage, and clears when
  that actor finishes its next turn.
- Expose adds damage to the next hit against the target, then clears.
- Sunder removes block and stoneskin before damage lands.
- Poison lands after a two-turn delay.
- Stoneskin is persistent defense and is valued above temporary block.
- Permanent levels grant one run-scoped Defiance charge at levels
  `4/8/12/16/20`. A lethal hit spends one charge and restores `25%` max HP.
  Defiance raises the long-run clock without changing a card's intrinsic score
  or inflating the player's health pool.
- Illusions are stationary, have only health, and redirect enemies that are
  closer to the illusion than to the player. If player-side actors are tied at
  the same distance, enemies choose randomly among the tied targets.
- Umbra pressure primarily advances with completed elemental-dragon sections.
  The first depth is Clear, then Fringe begins on depths `2` and `3` before the
  first elemental dragon and remains for its boss room. Later sections use
  Fringe, Advancing, Pressing, Deep, and then Heart for the Shadow Dragon
  section. Noctyrax authors Eclipse during the final encounter at depth `24`.
  Section-aware layouts preserve this curve if the number of rooms between
  bosses is compressed later.
- Umbra radius is measured by Manhattan distance from the player: unlimited in
  Clear, then `6/5/4/3/2/1` for Fringe through Eclipse. Hidden enemies cannot
  be directly targeted and do not reveal their intent or turn-order identity.
  Radiance cards therefore gain encounter-dependent value by revealing tiles,
  extending vision, granting enemy-only truesight, or reducing Umbra stages.

### Qualitative Progression Policy

The scorer uses a no-skill reference profile. Learned skills can change card
access, card persistence, play timing, positioning, conditional intensity,
defense carryover, and discard or draw choices, but those benefits are not
folded into a card's intrinsic printed score.

This is intentionally a context boundary rather than a coefficient change:

- A single pool-wide skill uplift would make every card score depend on an
  assumed meta build and would hide the value of choosing a different route.
- Several skills improve flexibility or rescue a specific situation rather than
  adding a stable amount of health saved per play.
- Local analytics exposes `progression_skills`, so realized card results can be
  compared between learned-skill cohorts without changing the printed-card
  baseline.

When reviewing a card with an unusually strong skill interaction, record that
interaction beside the neutral score and verify it in playtests. Do not add the
skill's full benefit to the card formula.

Run-scoped relics follow the same context boundary. The neutral card score does
not include relic action mutations or triggered rewards; unusually strong
card/relic interactions belong in relic-focused tests and analytics cohorts
grouped by active relic ids.

Encounter calibration is also important:

- The first combat remains a `Kill All` onboarding encounter. Later standard
  rooms deterministically use an equal `25/25/25/25` mix of `Kill All`, `Kill
  the Leader`, `Survive`, and `Reach the Exit`; boss rooms always use `Kill the
  Leader` without applying the generic leader health/defense bonus on top of
  authored boss stats. Survival targets initiative clock
  `42/46/50` at local depths `1/2/3` and schedules one reinforcement every `16`
  time. Reach-exit rooms add `1/2/2` enemies plus `3` destructible terrain
  pieces, favor control intents, and bias enemy routes toward the player's exit
  lane. Leader kills immediately clear surviving followers without follower
  ember or death-play rewards. Keep the scalar card score objective-neutral;
  compare realized movement/control, AOE, and execute value by
  `objective_type` analytics cohorts and call out objective-specific strengths
  during review.
- A complete run has six four-depth sequences. The first three depths of each
  sequence average about `3`, `4`, and `5` enemies, and the fourth depth is a
  boss gate. The first five gates draw Zekarion and the earth, fire, air, and
  ice dragons in a seeded random order without repeats. Noctyrax, the Shadow
  Dragon, is always the sixth and final gate at depth `24`. Lateral rooms remain
  a deck-building route choice. Once the player has visited three rooms at the
  current depth, a room with no available outward move gains a deterministic
  outward offer; fully exhausted loops retain the same escape guarantee.
- First-sequence standard rooms now use a wider local band. Depth `1` enemies
  have `85%` HP and support actions are shifted down by `1` point, depth `2`
  uses base stats, and depth `3` enemies have `112%` HP without an extra generic
  damage/support bump. Damaging intents use their full authored value from
  depth `1`, making exposed mistakes costly immediately. Standard depths share
  the same normal-room roster eligibility; local depth controls density and
  scaling instead of gating enemy types.
  Enemy base initiative
  is mostly roster-driven: lightning wisps and tunnel crawlers are fast,
  harriers are quick, frostglass lancers and acolytes are baseline, Cinder
  Oozes are slower split pressure, grave surgeons are support-paced, Chainbound Gaolers are mid-slow
  control anchors, bile bloomers are slow attrition anchors with a radius-2
  poison diamond, and wardens are slow. At depth `1`, weighted first/repeat
  cycles before the initial spawn stagger are roughly `11` for wisps, `13` for
  crawlers, `13` for Cinder Droplets, `13.4` for harriers, `15.8` for frostglass lancers, `16` for grave
  surgeons, `16.25` for acolytes, `17.78` for Cinder Oozes, `17.8` for
  gaolers, `19.1` for bile bloomers, and `20.25` for wardens; Zekarion cycles
  around `19.25` before summon forcing. Grave surgeons contribute low direct
  damage but can heal or guard the most injured/threatened nearby enemy, so
  their support amounts follow the same depth/sequence support curve as enemy
  block and healing. Tunnel crawler claw attacks and the Bone Harrier's spear
  shot now add light one-turn bleed pressure. Depth reduces enemy base
  initiative by up to `4` over time.
- Specialist enemies enter normal local depth `1-3` pools only in matching
  elemental rooms: Cinder Oozes in fire, Frostglass Lancers in ice, Chainbound
  Gaolers in air, and Bile Bloomers in earth. Those specialists now build their
  matching room intensity and either gate stronger effects or consume intensity
  for an upgraded payoff; Lightning Wisps use the same builder/consumer model.
  Generic enemies keep their own printed intent actions instead of being
  rewritten to match the room element.
- Cinder Oozes split into up to two summoned Cinder Droplets on nearby legal
  tiles; the droplets add cleanup pressure but grant no embers and no death
  card-play bonus.
- Grave surgeons enter normal local depth `1-3` pools as support enemies that
  lower direct pressure while extending allied bodies.
- Warden Bulwark grants its scaled Block amount to every other living enemy,
  never the Warden itself. In multi-enemy rooms this makes the Warden a durable
  protection anchor and increases the encounter-specific value of focus fire,
  Pierce, Sunder, and broad damage without changing their generic coefficients.
- Chainbound Gaolers enter normal local depth `1-3` pools at low frequency as
  pull/immobilize control anchors without stacking with wardens or boss adds in
  their seeded compositions.
- Bile Bloomers enter normal local depth `1-3` pools at low frequency as slow
  poison/expose attrition anchors without changing boss rooms.
- Frostglass Lancers enter normal local depth `1-3` pools as precision
  four-tile line-thrust enemies that can move sideways to set up a lane, so
  lateral movement and blocker-aware positioning can appear from the opener band.
- Later sequences keep the same local density and elemental room-pressure curve,
  but raise enemy max HP by only `+8%` per completed sequence. Direct-damage
  bonuses across the six sequences are `0/1/1/2/2/3`; support bonuses are
  `0/0/1/1/2/2`. This keeps late fights viable without returning to multi-card
  health sponges.
- Zekarion's 2x2 footprint makes attack reach feel larger than printed range.
  His Tempest Breath is intentionally capped at ranged `3` after a one-tile
  advance so corner repositioning can produce real safe tiles in open boss
  rooms.
- Large enemies use actor-level direct targeting: if any visible footprint tile
  satisfies an attack's range and line-of-sight rules, the full footprint
  accepts the click and resolves against the same actor. This is input
  affordance rather than extra targets or extra hits, so it does not change the
  generic single-target damage coefficient.
- Every dragon has an authored pressure axis in addition to ordinary intents:
  Zekarion summons wisps; Tharokh raises attackable Worldspines before rupturing
  them; Vyraketh plants attackable cinder marks before a forced detonation;
  Vaeloryx combines arena-wide damage with forced movement; Iskaldra gains
  hit-count frost crystal armor; and Noctyrax's Eclipse damages actors outside
  Radiance. Their health, damaging actions, support amounts, and mechanic
  payloads scale from the global boss depth on the same completed-sequence
  curve as normal encounters. These mechanics increase encounter-dependent
  value for area damage, movement, multi-hit sequencing, and Radiance without
  changing their generic card coefficients.
- Rooms reserve a small halo around the player's entry tile, then seed enemies
  with weighted randomness across the room. Placement softly discourages
  adjacent pileups and same-corner clusters, but no longer pushes enemies to
  the far side by default. This should make turn-1 reach and early enemy threat
  more variable than the old far-spawn calibration.
- Revealed enemy execution is deterministic from the current board and intent.
  Advancing attack intents stop at the first reachable attack-enabling tile,
  with movement length ahead of trap exposure and safe routing used to break
  equally short ties. Retreat attacks maximize separation only while preserving
  their follow-up, while attackless retreats maximize safe separation.
  Equal-distance player-side target ties prefer illusions so decoys are
  reliable. When an attack is not reachable this activation, route scoring
  treats destructible terrain as finite clearing time, allied congestion as a
  temporary hard blocker while crediting immediately traversable detours, and
  traps as high-cost but traversable when no safe route exists. Conservative
  threat unions remain visible, with the exact current route, destination, and
  projected attack shown separately; exact projections also honor freeze,
  shock, immobilize, and deterministic lightning-strike tiles.
- Elemental combat rooms seed `2-3` traps across eligible passable floor tiles,
  including the playable edge band, while still avoiding occupied tiles and the
  player's entry halo. Traps blast adjacent tiles when stepped on or attacked,
  so forced movement and area targeting can create higher positional upside and
  risk than the old single-tile trap model.
- Generated traps retain the authored positional base-damage curve:
  `6/7/8` player-scale damage in local standard depths `1/2/3`. First-sequence
  boss-depth traps hit for `5` so they beat weak ranged attacks without
  one-shotting full-health lightning wisps; generated traps use sequence bonuses
  `0/1/1/2/2/3`. Live damage then multiplies
  that base by `72/94/124/162/208/262/324%` at matching elemental intensity
  `0/1/2/3/4/5/6`; scaling caps at `6` for malformed or legacy saves. Normal
  matching rooms therefore begin slightly below the previous damage, while a
  volatile intensity `4` room is already more than twice as deadly. Depth-3
  fire and earth trap statuses are capped at `2`.
- Fire trap burn ramps gently in the first sequence: depth `1-2` fire traps
  apply shallow burn pressure, then deeper standard fire rooms restore the
  heavier trap payload.
- Combat and boss rooms scatter consumable item cards: `15%` have none, `65%`
  have one, and `20%` have two. Equipment eligibility and drop rates are unchanged.
  Pickups prefer a five-tile Manhattan gap from other items and equipment, with
  the best legal separation used in cramped layouts. Items roll by their existing
  rarity weights. The retired instant-heal/shield objects no longer spawn.
  A free item slot auto-equips a pickup and adds it to hand; at the seven-card
  hand cap it goes on top of the draw pile instead. With both slots occupied it
  goes only to reserve inventory. Consumption removes one owned copy permanently
  unless the existing preserve-item skill applies. Pickup access is encounter
  context, not an intrinsic draw/tempo bonus in every item's score.
  Items now target modest tactical effects (mostly scores `2–3.7`; Storm Jar
  remains a narrow epic control premium at `4.84`), rather than the previous
  `6.45–11.69` band. Item Time costs are `3–5`, retaining initiative tradeoffs.
  Shop costs are `25/40/60/90` embers by rarity.
  Combat rooms also scatter `5-7` `3`-HP boxes/crates across
  eligible passable floor tiles, including edge-band and corner floor tiles when
  connectivity stays intact. They block movement, do not block line of sight,
  and can be destroyed by player or enemy attacks, area effects, deterministic
  lightning strikes, and adjacent trap blasts. The heuristic's existing AOE
  tile multiplier represents this conditional terrain-clearing upside; there is
  no separate terrain coefficient because the value depends on the live layout.

The heuristic still rewards cards that compress setup and payoff into the same
play, but early reach assumptions should be reprobed before making fine-grained
mobility or range coefficient changes, especially now that perimeter routes are
not guaranteed to stay clear.

## Formula

The total score is:

`EV = offense + control + defense + flow + elemental_intensity + mobility + radiance + synergy + tempo + flurry_compression_bonus - intensity_spend_cost - health_cost - exhaust_card_penalty - flurry_commitment_penalty`

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
- Flurry: score the printed action package and health cost at the baseline `2`
  available plays, but score printed time only once. For each extra copy, add
  `0.85` for saving a card/draw, `0.75` for saving a separate time payment, and
  `0.25` for target-by-target retargeting, then subtract `0.55` for committing
  another available play to the same printed package. This deliberately makes
  the single-card/single-time compression visible in the score so Flurry cards
  must be under-rate before their copies are counted.
- Elemental intensity gain: `0.70` per point
- Elemental intensity spend: `0.35` per point consumed, after the conditional
  package availability adjustment described below
- High-damage kill-card-play premium: up to `0.45`, scaled by damage,
  playability, and target count
- Illusion health: `0.48` per point
- Illusion placement range: `0.12` per tile
- Illuminate: `0.55` per light radius, `0.25` per activation of duration, and
  `0.06` per placement-range tile
- An attack-carried Illuminate rider uses the same radius and duration values,
  but adds no placement-range value because it inherits the attack's stricter
  enemy, trap, or terrain target and creates Light only after the hit resolves.
- A movement-carried Illuminate rider also uses the same radius and duration
  values without separate placement-range value. It creates Light at the
  movement's actual resolved endpoint, including an endpoint shortened by a
  hidden collision.
- Vision: `0.50` per added-radius activation
- Truesight: `1.40` per activation
- Dispel Umbra: `2.20` per reduced stage
- Umbra relevance multiplier: `0.75` for all Radiance-only value, reflecting
  that only the first depth is guaranteed Clear while some draws still occur
  outside shadowed combats
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
- Bleed one-turn action pressure: `0.65` per stack
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

## Elemental Intensity Gating and Spending

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

A top-level `intensity_cost` makes the entire printed action package conditional.
The scorer uses the same raw availability table, then applies a `0.68` retention
floor: `retained availability = 0.68 + 0.32 * raw availability`. This models a
player holding a payoff while either side builds the shared room resource,
without pretending the card is always playable on draw. The package is
multiplied by retained availability and then charged `0.35` per intensity
spent. The cost is paid once even if a future Flurry card repeats its printed
actions. The heuristic does not credit the situational upside of draining traps
or denying an enemy intent, so Air forced-movement and other battlefield-control
spenders may deliberately land toward the low end of their rarity band.

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
- Skill-tree interactions that change access, timing, persistence, or targeting
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
- Flurry scaling above the baseline two plays and resources or kill refunds
  created between repeated actions; baseline retargeting is represented only by
  a small fixed proxy

If a card is intentionally better than its standalone score because of one of
those factors, note that explicitly in review or commit context.

## Maintenance Rules

Update this document and `tools/card_heuristic.py` together whenever any of the
following change:

- cards per turn, draw per turn, or maximum hand size
- player base initiative, card time costs, enemy base initiative, or enemy
  intent time costs
- qualitative progression effects that change card access, timing,
  persistence, targeting, or resource flow
- fatigue rules
- status behavior
- damage, block, stoneskin, or healing semantics
- enemy preview rules
- enemy target selection, path cost, obstacle clearing, or attack-position rules
- room size, enemy spacing, trap count/placement, or spawn selection
- enemy roster or intent pacing
- AOE, chain, push, or pull behavior
- new card action types or keywords
- elemental intensity production, gates, spending, trap scaling, or enemy use

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

To inspect the encounter and run-structure assumptions used by the coefficients:

```bash
python3 tools/card_heuristic.py --show-assumptions
```

### Source-Aware Views

The default command still scores every card in `data/cards.json`, which is useful
for a global sanity check but mixes cards from different acquisition paths. Use a
source filter when comparing cards against peers:

```bash
python3 tools/card_heuristic.py --reward-pool
python3 tools/card_heuristic.py --elemental-rewards
python3 tools/card_heuristic.py --equipment
python3 tools/card_heuristic.py --items
python3 tools/card_heuristic.py --starters
```

`--reward-pool` is the normal card-reward view: cards with reward-pool metadata
after excluding equipment-granted cards and starters. `--elemental-rewards` is
the elemental subset of that normal reward pool. `--equipment` is the
equipment-only view, excluding starter cards granted by starting gear.
`--neutral-rewards` isolates neutral normal rewards, which is useful when
checking whether old neutral reward metadata is still intentional.
`--items` is the Scavenger consumable view: cards marked `item: true`, typically
also `consume_on_play: true`, which enter decks through equipped item slots and
are destroyed after one play.

Equipment cards are identified from `data/equipment.json`, not only from card
metadata. Starter cards are identified by `starter: true`; legacy
`rarity: "starter"` is still treated as starter metadata so old data does not
leak into reward-pool or equipment-only balance reviews. Item cards are also
excluded from reward-pool and equipment-only views so their one-use strength
does not distort normal card comparisons.

Source tags are shown automatically in filtered text output, can be added to any
text view with `--show-source`, and are always included in `--json` output.

When reviewing or adding cards:

1. Run the tool for the changed card and the full pool.
2. Run the source view that matches how the card enters a deck: `--equipment`
   for gear cards, `--items` for Scavenger consumables, `--starters` for
   starting-deck cards, and `--reward-pool` or `--elemental-rewards` for magic
   rewards.
3. Compare the score against similar cards, not just the global ranking.
4. Decide whether any intentional over- or under-rate is justified by build,
   rarity, or encounter role.
5. If the underlying combat assumptions changed, update the heuristic first.
