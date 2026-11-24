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
  scheduled at `base initiative + time spent on played cards + 5 × unused base plays`
  (plus carried debt and relic adjustments; see [turn_clock.md](turn_clock.md)).
  Each of the first two plays left unused takes 5 Time; bonus plays never wait.
- Player base initiative is fixed at `9`. Qualitative progression skills do
  not permanently reduce it.
- Printed cards carry a `time` cost on a `1-10` scale. The current baseline
  card is `5` time. The tempo term `(5 − time) × 0.45` measures the
  saving against waiting, so its coefficient is unchanged. Fast cards are meant to be a real initiative advantage,
  while heavy cards can let enemies lap the player if overplayed.
- Enemies reveal an intent before entering the queue. Initial enemy slots and
  repeat enemy slots both use `enemy base initiative + revealed intent time`;
  initial slots add a small enemy-index stagger so simultaneous spawns stay
  readable.
- Killing an enemy with a card grants `+1` card play for the turn, so high
  damage gets a modest execute-tempo premium.
- Every enemy `summon_minions` move that brings at least one enemy onto the
  board grants `+1` Card Play on the next hero activation, per move rather than
  per enemy, stacking without a cap. Blocked/capped summons, death spawns,
  Survive waves and automatic Guardian replacements grant no Card Plays.
  This is encounter-level economy, excluded from intrinsic
  card coefficients; compare realized card-play cohorts around summon moves.
- Card targeting uses one board decision, with automatic riders and combined
  movement approaches. A Push/Pull target is legal anywhere within maximum
  range when the action deals damage, moves the target at least one tile, or
  collides. Existing ranged playability factors already assume this radius;
  force value remains a conditional positional benefit.
- Forced movement travels one straight cardinal line
  ([forced movement](forced_movement.md)). A stopped line collides: the target
  and whatever stopped it take 2 damage per lost tile (walls take none). The
  collision value below prices that at roughly one collision per three
  forced-movement plays, so relics that add distance also add damage value.
- A Push action carrying a `surface` places it at the target's final tile,
  including travel shortened by Collision. A target killed before moving leaves
  it on its occupied tile. Rooted Kick is the only current card using this
  combination. This uses the ordinary bounded surface value, without crediting
  guaranteed entry contact or additional control.
- Flurry is dormant (flu-01): no shipped card carries `flurry`; the six former
  Flurry cards resolve once for one Card Play. Engine, analytics and scorer
  support remain for synthetic tests and a possible return. The preserved engine
  path snapshots all available card plays, repeats printed actions and health
  cost once per snapped play, and spends all snapped plays. The physical card's top-level Time cost is paid once. Plays gained
  during resolution remain available after the Flurry commits.
- Fatigue starts at `2` health and increases by `1` health each reshuffle.
- Rules v5 uses shared board surfaces, with Rubble under one elemental layer.
  Fire deals 2 per actual entry step and 3 per affected actor start, without
  direct-attack riders. Ice Exposes 2 a unit on entry or eligible turn start.
  Placement alone applies no contact effect. The next damaging hit spends Expose.
  Cards with "On Ice: also Stagger 6" delay eligible targets by up to 6. Dragons
  take half. Each hero or enemy has one 6 Time cap across sources between its turns.
  Rubble costs 2 movement to leave; a fresh positive allowance permits a first
  adjacent step even when only 1 movement remains. Splitting movement does not
  refresh that exception. Electrified is immediately usable as cardinally
  connected ground or as relay nodes for intrinsic Chain. Ordinary Electrified survives use;
  Stormcoal Fire conducts hero Lightning card hits and those hits consume it.
- Enemy preview block matters immediately during the player turn.
- Stagger delays a turn. Shock and Immobilize restrict actions. Expose increases damage taken.
- Pierce attacks deal HP damage through block and stoneskin without removing
  those defenses.
- Shock lets the enemy keep movement, but strips non-movement actions for that
  turn.
- Expose adds damage to the next hit against the target, then clears.
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
  Light reveals tiles within the Light radius and Exposes enemies at turn start.
  Light placed by cards, relics, and skills lasts the battle. A brazier
  supplies Light while lit, and a unit aura supplies Light while the unit lives.
  Temporary Vision reveals enemies while leaving the sight radius unchanged.

### Enemy hit pressure (pla-07)

Skitter Strike, Pelt, Worldspine Claw, Razor Dive, Grave Dive, Crushing Rush,
Lash of Thorns, and Talon Rake gain 1 printed damage each when their retired
rider is removed. For comparisons, `enemy_hit_pressure` values one landed hit
on the hero at the existing per-point damage and Pierce coefficients. The old
comparison adds the old rider coefficient from the pre-cut scorer. This
comparison leaves out player-card kill rewards, card tempo, and multi-target
estimates. Actual enemy damage still uses the normal room and depth scaling.

### Magic ownership (deck-01)

The scorer has no six-magic-loadout assumption: it scores the intrinsic value
of a card play against a blank draw, not draw frequency in a fixed deck. All
owned magic now enters the deck. At deck-01, the starting deck had 16 cards,
including Pale Spark ×2, Dull Bolt ×2, and Waning Pulse ×2. Removing a magic copy changes
draw frequency, not that card's printed value. Compare realized results by
`deck_cards` composition/count and purge source/price in analytics. No card,
Time, damage, draw, fatigue, or scoring coefficient changes in deck-01. The
service prices are the director's 50 Embers, then +25 per later paid Scavenger
purge; Campfire removal replaces its other choices, costs zero Embers, and never
raises the Scavenger price.

Gear-02 starts new runs with 9 gear cards and 4 spells. Pale Spark, Dull Bolt,
Waning Pulse, and Buffet each appear once. Lantern Shot enters the deck by
equipping the Cracked Lantern after the first Umbra victory. Previously saved
runs keep their loadouts and printed card rules. The early gear rate changes
acquisition timing. All individual card scores still use the same coefficients.

### Qualitative Progression Policy

The scorer uses a no-skill reference profile. Learned skills can change card
access, card persistence, play timing, positioning, surface placement and relocation,
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

- The first combat remains a `Kill All` onboarding encounter. Layout revision
  `6+` standard fights always use `Kill All`. Revisions `3–5` retain the seeded
  `50/25/25` mix of `Kill All`, `Kill the Leader`, and `Reach the Exit`. `Survive` is out of the standard rotation;
  its former seeded slots use `Kill All`. The Last Light special (spx-08) is the
  one current `Survive` room: sight 3, three radius-2 braziers the Wick Shades'
  Snuff puts out and the hero relights by stepping, Shadowstep after each player
  turn, and +2 Health per brazier lit at dawn (cap 6) on top of the special bonus. Boss rooms always use `Kill the
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
- Legacy runs have six four-depth sequences with about `3`, `4`, and `5`
  enemies before each boss gate. In section-map table fights the tier is the
  minimum of the depth-band tier and the current section fight-number tier:
  fights `1–2` → tier `1`, `3–4` → tier `2`, `5+` → tier `3`. Caps after token
  expansion are tier ceilings `3/5/6`, further limited by fight-number caps
  `3/3/4/5/5/6` for k `1–6`; later fights retain the final cap. The global
  `max_units` remains an additional bound. Count the
  guided tutorial, specials, Guardians and resolved mystery fights, excluding
  bosses. Enemy stats still use depth; intrinsic card coefficients are unchanged. The first five gates draw Zekarion and the earth, fire, air, and
  ice dragons in a seeded random order without repeats. Noctyrax, the Shadow
  Dragon, is always the sixth and final gate at depth `24`. New section-map runs
  budget 66 room visits and 40 fights including bosses across six sections;
  see [section_map.md](section_map.md). Branches preserve each section's fight
  budget and vary service order. This changes run pacing without changing
  combat/action coefficients in the scorer. Legacy saved circular-map runs
  retain lateral deck-building choices. Once the player has visited three
  rooms at the current depth in a legacy run, a room with no available outward
  move gains a deterministic
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
  around `19.6` before summon forcing. Grave surgeons contribute low direct
  damage but can heal or guard the most injured/threatened nearby enemy, so
  their support amounts follow the same depth/sequence support curve as enemy
  block and healing. Depth reduces enemy base
  initiative by up to `4` over time.
- Specialist enemies enter normal local depth `1-3` pools only in matching
  elemental rooms: Cinder Oozes in fire, Frostglass Lancers in ice, Chainbound
  Gaolers in air, and Shale Bloomers in earth. Specialists create, consume or
  exploit local shared surfaces: Ooze Fire and local fuel defense, Lancer Ice
  lanes, Gaoler hazard displacement, Bloomer Rubble, and Wisp Electrified.
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
  Pierce and broad damage without changing their generic coefficients.
- Chainbound Gaolers enter normal local depth `1-3` pools at low frequency as
  pull/immobilize control anchors without stacking with wardens or boss adds in
  their seeded compositions.
- Shale Bloomers enter normal local depth `1-3` pools at low frequency as slow
  Rubble/Expose control anchors without changing boss rooms.
- Frostglass Lancers enter normal local depth `1-3` pools as precision
  three-tile line-thrust enemies with a one-tile approach that can move sideways to set up a lane, so
  lateral movement and blocker-aware positioning can appear from the opener band.
- Later sequences keep the same local density and elemental room-pressure curve,
  but raise enemy max HP by only `+8%` per completed sequence. Direct-damage
  bonuses across the six sequences are `0/1/1/2/2/3`; support bonuses are
  `0/0/1/1/2/2`. This keeps late fights viable without returning to multi-card
  health sponges.
- Zekarion's 2x2 footprint makes attack reach feel larger than printed range.
  Overload keeps a direct bolt for 3 and fires Lightning Storm across every
  Electrified tile on the board when Overload fires for 6 (7 at half Health),
  with Chain 0. Advancing Storm Lash keeps its shot for 4 and Electrified ground. Movement safety depends on
  each intent's announced geometry and conduction rules.
- Large enemies use actor-level direct targeting: if any visible footprint tile
  satisfies an attack's range and line-of-sight rules, the full footprint
  accepts the click and resolves against the same actor. This is input
  affordance rather than extra targets or extra hits, so it does not change the
  generic single-target damage coefficient.
- Dragons cycle distinct pressure rather than rolling unrelated attacks.
  Vyraketh plants shared Fire that can be moved/consumed before a fixed burst;
  Tharokh caps attackable Worldspines while preserving two routes for a 2×2 body;
  Vaeloryx holds directional fans/lanes, dives, then retreats; Iskaldra alternates
  capped hit-count armor, Ice lanes, a physical sweep and a close pursuit;
  Zekarion combines fixed marks, conduction, a charge and capped summons;
  Noctyrax alternates attack geometry with lit refuges and an Eclipse that
  punishes darkness. Held directions survive player movement; charges reanchor
  their pattern at the actual destination and evaluate the entire footprint's
  hazards. Base cycle-average initiative delays, before depth/status modifiers,
  are 18/20/17.5/19/19.6/19.75 for Fire/Earth/Air/Ice/Lightning/Shadow.
  See [the encounter contract](dragon_boss_encounters.md) for cycle payloads.
  These mechanics change the encounter-specific value of positioning, control,
  secondary hits, surfaces, and Light. They do not change intrinsic card
  coefficients: the scorer assumes no boss trophy, prepared board, progression
  skill, or Defiance. Live tests separately track acquired trophies and levels.
- Rooms reserve a small halo around the player's entry tile, then seed enemies
  with weighted randomness across the room. Placement softly discourages
  adjacent pileups and same-corner clusters, but no longer pushes enemies to
  the far side by default. This should make turn-1 reach and early enemy threat
  more variable than the old far-spawn calibration.
- Revealed enemy execution is deterministic from the current board and intent.
  Normal enemies now use explicit frontliner, artillery, skirmisher, protector,
  controller, or support profiles when refreshing that intent. They discard
  tactically dead options such as stationary out-of-range shots, irrelevant
  retreats, unavailable heals, and distant defensive turns, then retain seeded
  weighted variation only among the near-best legal choices. Support profiles
  prioritize missing allied health and threatened allies without walking toward
  the player when a support target is already in range; protectors prefer group
  defense when a back-line ally is exposed and otherwise advance to screen it.
  If no immediately useful option remains, selection retains an available
  authored intent at its printed Time. In particular, a Briar Weaver with
  occupied Thornwall tiles and no wounded ally retains Lash of Thorns even
  outside range or line of sight; its existing cancelled attack badge shows
  that it cannot currently hit. No empty-intent/default-Time turn is intended.
  This raises realized enemy pressure and support reliability relative to the
  old full-list weighted roulette without changing printed action coefficients.
  Advancing attack intents stop at the first reachable attack-enabling tile,
  with movement length ahead of trap exposure and safe routing used to break
  equally short ties. Retreat attacks maximize separation only while preserving
  their follow-up, while attackless retreats maximize safe separation.
  Equal-distance player-side target ties prefer illusions so decoys are
  reliable. When an attack is not reachable this activation, route scoring
  treats destructible terrain as finite clearing time, allied congestion as a
  temporary hard blocker while crediting immediately traversable detours, and
  traps as high-cost but traversable when no safe route exists. True total route
  cost is compared before open-prefix length; equal-cost routes prefer the
  current-activation prefix with the strongest immediate progress, so an enemy
  delays a detour around a distant blocker instead of taking an early U-shaped
  path. Conservative
  threat unions remain visible, with the exact current route, destination, and
  projected attack shown separately; exact projections also honor
  shock, immobilize, and deterministic lightning-strike tiles.
- Elemental combat rooms seed `2-3` single-use traps, avoiding the player's
  entry halo. Only the center occupant takes direct damage. The center and four
  cardinal neighbors receive the element's surface; Air only pushes cardinal
  neighbors outward. Placement
  does not cause immediate Fire/Chill contact; diagonals are unaffected.
- Generated traps retain fixed `6/7/8` damage at local depths `1/2/3` and `5`
  in first-sequence boss rooms, with later sequence bonuses `0/1/1/2/2/3`.
  There is no multiplier, direct status rider or adjacent crate damage.
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
  [Item relics](item_relic_rules.md) can replace non-healing Consume with
  once-per-combat Exhaust, amplify item values, or trade one extra Time for
  zero play spend. These owned-relic transformations do not change the
  scorer's printed, relic-free item baseline.
  Items now target modest tactical effects (mostly scores `2–3.7`; Storm Jar
  remains a narrow epic control premium at `4.84`), rather than the previous
  `6.45–11.69` band. Item Time costs are `3–5`, retaining initiative tradeoffs.
  Shop costs are `25/40/60/90` embers by rarity.
  Combat rooms also scatter `5-7` `3`-HP boxes/crates across
  eligible passable floor tiles, including edge-band and corner floor tiles when
  connectivity stays intact. They block movement, do not block line of sight,
  and can be destroyed by player or enemy attacks, area effects, deterministic
  lightning strikes, but not trap wake placement. The heuristic's existing AOE
  tile multiplier represents this conditional terrain-clearing upside; there is
  no separate terrain coefficient because the value depends on the live layout.

The heuristic still rewards cards that compress setup and payoff into the same
play, but early reach assumptions should be reprobed before making fine-grained
mobility or range coefficient changes, especially now that perimeter routes are
not guaranteed to stay clear.

## Formula

The total score is:

`EV = offense + control + defense + flow + surfaces + mobility + radiance + synergy + tempo + flurry_compression_bonus + follow_up + empower - surface_fuel_cost - health_cost - exhaust_card_penalty - flurry_commitment_penalty`

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
- Dormant Flurry support (synthetic cards only): score the printed action package and health cost at the baseline `2`
  available plays, but score printed time only once. For each extra copy, add
  `0.85` for saving a card/draw, `0.75` for saving a separate time payment, and
  `0.25` for target-by-target retargeting, then subtract `0.55` for committing
  another available play to the same printed package. This deliberately makes
  the single-card/single-time compression visible in the score so hypothetical Flurry cards
  must be under-rate before their copies are counted.
- High-damage kill-card-play premium: up to `0.45`, scaled by damage,
  playability, and target count
- Illusion health: `0.48` per point
- Illusion placement range: `0.12` per tile
- Player-raised outcrop (`outcrop` action): `0.90` per outcrop health point,
  times `0.50` availability (it absorbs a hit or blocks a useful lane about half
  the time), scored as defense. Extra pattern tiles use the `0.45` surface
  extra-tile retention. A plain 3-health outcrop is worth `1.35`. Placement
  range, the Rubble left on destruction and facing-aimed (`"aim": "facing"`)
  areas receive no separate value.
- Lasting Light: `0.55` per radius tile, `0.25` per expected remaining
  activation (the existing 3-activation horizon) and `0.06` per placement-range
  tile, multiplied by `0.75` for Umbra relevance. Light attached to movement
  or an attack inherits that action's placement and has no separate range value.
  Movement trails retain the existing discount for overlapping placements.
- Light's Expose 2 uses the existing Expose coefficient and the same horizon.
  The model expects `0.50` enemy starts in the area per activation at radius 2,
  scales down linearly for smaller radii and caps at that rate for larger radii.
  This is a coverage estimate, including overlap, and applies in Clear too.
- Vision: `1.40` per turn times `0.75` Umbra relevance, using the former
  enemy-only reveal coefficient. Vision adds no sight radius and contributes
  no lit tiles.
- The unlit part of Seek the Light's Blink uses full mobility value. Its
  additional range uses the existing Light-destination availability discount.
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
- Expose next-hit setup: `0.32` per point
- "On Ice: also Stagger N" is `N x 0.30` control at the Ice setup availability
  (`0.50`, or `0.80` after an earlier painter in the same card).
- Shock: `2.5`
- Immobilize one-turn movement lock: `1.7`
- Push: `0.28` per tile
- Pull: `0.14` per tile
- Directed push/pull bonus: `0.03` per forced-movement tile
- Shared hazard opportunity: `0.24` per forced-movement tile
- Collision opportunity: `0.30` per forced-movement tile (`2` damage per lost
  tile x about `0.33` collision availability x the `0.45` damage weight, for
  target plus blocker), applied like the hazard value and scaled by playability
- Stagger: `0.30` per point of delay, scaled by attack playability and target
  multiplier (below Time's `0.45`, because it delays one enemy rather than
  every other actor; the 6-per-turn cap and dragon halving are not modeled)
- State bonus (`state_bonus`): the damage delta over the printed hit plus
  Stagger at `0.30`/pt, scaled by expected condition availability: target in
  Light `0.40`, Exposed/Immobilized/Staggered/Shocked `0.30`, at or below
  half health `0.45`
- Scale bonus (`scale_bonus`): the damage delta from expected points, capped at
  the card's `max`: `2.5` Stoneskin, or `1.5` independently moved tiles plus the
  card's own earlier Move/Blink range
- Follow-up: `0.55 ×` the score of the bonus, where the bonus score is the card
  scored with its mods/appends applied minus the printed card
- Empower: `0.5 × max(0, bonus_score − cost_value)` with the same bonus score,
  and cost `0.45` per Time, `1.0` per health, `0.55` for Exhaust

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
## Board Surface Value and Setup

Permanent terrain receives bounded expected useful-contact value, never a
turn count multiplied by arbitrary encounter duration. For `n` distinct authored
cells, effective coverage is `min(4, 1 + (n-1) * 0.45)`. Fire is `0.84`, Ice
`0.60`, Rubble `0.44` and Electrified `0.45` per effective cell. Fire's coefficient
represents roughly one useful contact weighted for shared hazard risk and local
setup value; it does not assume every tile hits every turn. Placement at range
uses the existing reach availability; self placement uses `0.60`.

Electrified adds `0.18` per cardinal link, capped at three. Spaced or diagonal
cells receive no connectivity value. Intrinsic Chain retains its `0.45` extra
expected target bonus; the printed number remains hop reach. Lightning receives
`0.55` extra component occupants at `0.35` network availability, halved when
Chain already accounts for some of the same targets. Targets are a union.

Local surface conditions use `0.50` availability, or `0.80` when an earlier
same-card action supplied that surface; geometry still has to overlap. Newly
painted Ice under a target counts as an earlier painter for its "On Ice"
Stagger only when geometry overlaps. Electrified-assisted
Shock receives `0.35` availability, increased by `0.20` for earlier wiring.

Burst values one source's cross at `1.35` expected targets
(`burst_cross_targets`), one on the fuel tile plus `0.35` from its four
neighbors. Each additional useful fuel cell adds `0.30`, capped at `2.5`
targets. Fuel expectation is capped at `2.5` cells; `sources: "hits"` (Plasma
Arc) expects `1.25`. Each fuel cell costs `0.35` in foregone setup plus a `0.45`
shared-hazard cost per Burst, weighted by availability. A Burst that always
covers your tile (a follow-up at a range-1 melee target, a range-0 Burst around
you without `spare_player`, Worldbreak's adjacent Outcrop) instead pays its
damage as a Health cost (`health_cost_per_point`) at its availability. A
previous-target Burst inherits the initiating attack's reach; `leave_surface`
covers the destroyed tile, or the whole cross with `leave_surface_on: "tiles_hit"`.
`spare_player` removes the hazard. Discharge's union of crosses expects `1.60`
targets in a typical two-tile network and pays the shared hazard. Terrain and
illusion Bursts use `burst_cross_targets`. The powder keg expects `1.40`.
Consume-surface rewards use
their ordinary coefficients, weighted by setup availability and charged at least
one fuel cell. These are conservative initial values to review against seeded
mixed-element playtests, not a simulation of a prepared perfect board.

Flurry repeats damage and other ordinary effects, but each extra surface painting
receives only `35%` extra value because repainting the same ground is idempotent.
Fuel costs recur per repetition. Consumption and setup across repeats require
separate playtest checks: an earlier discharge cannot leave reusable wiring.

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
Push and pull get a small directed-force bonus because the player can Rotate
between the two straight cardinal lines of an off-axis target (away from or
toward the caster) before committing:

- Range `1`: `0.35`
- Range `2`: `0.65`
- Range `3`: `0.83`
- Range `4`: `0.92`
- Range `5`: `0.96`
- Range `6`: `0.98`
- Range `7+`: `0.99`

The `short_reach_v1` factors use rounded structural legality anchors from
`tools/reach_playability_probe.gd`: 48 seeded rooms across six elements and depths
1/3/9/19, with 1,570 unoccupied inner-floor anchors per visibility cohort.
Immediate enemy-target availability in Clear was .334/.656/.827/.920/.966/.981/.989
for ranges 1–7. Deep plateaued at .827 after range 3; Heart at .656 after range 2.
These are unweighted board snapshots, **not realized hit rates or a universal
fog discount**. Shared movement is not credited to each card. The melee curve
remains a conservative routing/commitment discount relative to the new projectile
curve; unchanged melee damage and Time should be revisited through human play,
not automatically inflated to compensate for shorter projectiles.

Ordinary enemy direct threat is now 2–3, with named approaches/rays up to 4.
The player retains two independent movement tiles plus paid card movement.
See [the reach balance contract](reach_balance.md) for exceptions and save policy.

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

## crd-02 — rarity balance batch 1

Balance revision `crd02_cards_v1` supersedes `dragon_pressure_v3` in
`GameData` and the scorer. These director-authored card values change printed
Time and amounts, using existing actions; all scoring coefficients and combat
semantics remain unchanged. Ember Guard now uses Ember Ward's existing
`surface_adjacent_enemies` Fire action. Faces and card panels derive from the
same definitions. Existing card-play, draw and surface analytics record the
new values without a schema change.

| Card | Authored change | Score before → after |
| --- | --- | --- |
| locket_chill | Damage 3 → 5; range 2, Time 4 retained | 2.9737 → 3.6835 |
| far_draw | Time 3 → 2; draw 1 → 2 | 2.1235 → 3.4235 |
| shield_wall | Block 9 → 12; no_move retained | 2.6500 → 3.4000 |
| shield_charge | Time 4 → 3; damage 3 → 5; Push 2 retained | 2.3153 → 3.1475 |
| mossglass_elixir | Time 4 → 3; heal 2 → 3; Stoneskin 1 → 2 | 2.6500 → 4.4000 |
| bone_ward_charm | Time 4 → 2; Stoneskin 2 → 4; Block 3 → 4 | 2.0000 → 3.9500 |
| cinder_patch | Heal 2 → 3; Block 4 → 5; Time 3, Exhaust, clear Fire retained | 3.1500 → 4.3000 |
| crank_reload | Time 3 → 2 | 2.9000 → 3.3500 |
| overclock | Time 3 → 2; Empower retained | 2.9000 → 3.3500 |
| ember_guard | Block 7 → 10; Fire under each adjacent enemy | 2.4940 → 3.7060 |
| raise_the_anvil | Stoneskin 4 → 6; outcrop retained | 3.8500 → 4.6500 |

### Common gear and reward tuning (crd-06)

Director-authored card Time, damage, movement and draw updates use the existing
coefficients unchanged. Item scores sum every provided card (including the
unchanged Flowing Step in Monk's Wraps). This batch changes thirteen balance
cards; Rooted Kick's definition is unchanged by its surface-placement fix.

| Item or reward | Before | After |
| --- | ---: | ---: |
| War Maul | 5.6278 | 8.1393 |
| Iron Cleaver | 6.4392 | 8.0041 |
| Frostwalkers | 4.7900 | 6.1400 |
| Monk's Wraps | 5.0143 | 5.6796 |
| Grapple Hook | 5.3038 | 6.2230 |
| Buffet | 2.5187 | 3.4027 |
| Skate | 2.5500 | 3.6500 |

The values strengthen the weakest common gear and Time-2 rewards against their
existing peers. No progression, relic, draw-per-turn or fatigue assumption is
added by the two printed draw riders.

## Maintenance Rules

Balance revision `status_payoffs_v1` (crd-08): `state_bonus` conditions
`exposed`, `immobilized`, `staggered`, and `shocked` share a `0.30`
conditional availability, including when that weight is overridden. Each condition adds
the damage delta over the printed hit before impact, per target and per hit.
Exposed checks positive Expose, Immobilized checks the movement lock, and
Shocked checks positive Shock. Staggered checks a positive outstanding delay on
the enemy's next queued turn (or a pending delay awaiting scheduling); the slot
owns this marker until activation, independently of the per-player-turn cap.
This revision adds the supplied payoffs to Spear Thrust (+4 Immobilized),
Serrated Slip (+4 Exposed), Hobnail Drive (+3 Staggered), and Jolt (+3 Shocked).
Status application, timing, and existing damage/state-delta analytics are
unchanged; these conditions reuse the per-hit resolver and forecast path.

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
- surface creation, contact timing, consumption, connectivity, trap wakes, or enemy use

If you change the rules above and do not update the heuristic, future card work
will drift against stale assumptions.

### Epic and legendary equipment batch 2 (crd-03)

Balance revision `crd03_gear_v1` (GameData and scorer) records the director's
fourteen-card data revision. Rime Hack/Frozen Bite/Shatter Swing now cost
3/2/4 Time and hit for 7/5/10. Frozen Bite grants one Card Play and draws one
when the target stands on Ice. Shatter Swing Bursts the Ice for 6, sparing you.
Grave Cleave/Blood Price/
Tombsplitter cost 4/5/6 and hit for 8/14/14, preserving their riders and Empower.
Quarry Plating costs 3 for 6 Stoneskin; Shrug Off grants 3 Block before conversion.
Hoarfrost Wall costs 3 for 8 Block; Cold Shoulder costs 2 for 6 damage and Push 2.
Cloudstep Loop costs 2 and draws one after Blink; Zephyr Feint costs 3 for 4 Block.
Worldroot Stride costs 4 for 6 Stoneskin plus 3 on existing Rubble; Rooted Kick
costs 3 for 8 damage. All other ranges, riders and costs remain authored.
Existing tempo, result-reward, surface-bonus, draw and defense coefficients score
these values directly; no coefficient or combat semantic changes accompany this
batch. Existing analytics report the resolved amounts and ordered reward list.

### Cloudstep Loop Follow-up (crd-11)

Cloudstep Loop retains Time 2, Blink 3, then draw 1. Its one Card Play now
comes from the shared Follow-up append after a prior card finishes this turn,
replacing the Blink's `if_no_adjacent_enemies` rider. Existing coefficients score
the change at **3.89 → 4.1825** (CLI display: **4.18**): the Follow-up bonus
includes the appended Card Play and its draw/play synergies at the usual `0.55`
share. No weights change.
Existing `follow_up_active` and card-action play-gain analytics describe this
transition without schema or instrumentation changes.

The old `if_no_adjacent_enemies` scorer and runtime remain supported for
`maneuver_suite.gd`'s `w4b_cloudstep_loop`, `relic_u5_suite.gd`'s nested Block
suppression fixture, and `test_card_heuristic_maneuver.py`. No production card
uses the rider after this change; the historical card-pool authoring definition
and before-proof snapshot retain it.

### Weak reward-pool cards batch 4 (crd-14)

Scorer balance revision `crd14_cards_v1` records the director's thirteen-card
reward-pool revision. Existing action fields express every change; coefficients,
combat semantics, panel selection, and analytics payloads are unchanged. The
implementation unit owns data and scorer metadata only; the runtime
`GameData.BALANCE_REVISION` remains an integration-owner update.

| Card | Authored change | Score before → after |
| --- | --- | --- |
| stoke | Damage 3 → 5; Time 4 retained | 1.7622 → 2.7450 |
| hurricane_palm | Time 4 → 3; damage 3 → 4; Push 3 retained | 1.8528 → 2.4897 |
| venom_claw | Time 4 → 3; damage 8 and Rubble retained | 2.1665 → 2.6165 |
| tremor | Time 5 → 4; damage 3 → 4; Stagger 2 and Empower retained | 1.9787 → 2.8773 |
| grounding | Time 3 → 2; Stoneskin per tile 2 → 3; cap 8 → 9 | 1.3500 → 2.2000 |
| dust_devil | Time 4 → 3; Expose 2 → 4; Push 2 retained | 1.2685 → 1.9974 |
| stonefist | Time 4 → 3; damage 5 → 6; scaling and cap retained | 1.8956 → 2.5816 |
| thunderclap | Damage 3 → 5; Push 1 and Electrify retained | 2.0299 → 2.6768 |
| magma_vent | Damage 5 → 7 | 2.2046 → 2.9062 |
| vortex | Time 5 → 4 | 1.6932 → 2.1432 |
| cyclone_seal | Second-action damage 6 → 9 | 3.5124 → 4.5535 |
| rite_of_the_storm | Turn-start pulse damage 2 → 3 | 1.6100 → 2.6900 |
| rite_of_the_pyre | Time 4 → 3 | 1.5200 → 1.9700 |

### Fire player-surface synergy (crd-18)

Balance revision `crd18_fire_synergy_v1` (GameData and scorer) records Cinder
Wall's +4 Block and Hearth Rush's +3 melee damage while the player stands on
Fire. Each uses the existing player-subject `surface_bonus`, evaluated when its
action resolves: Cinder Wall paints before Block; Hearth Rush moves before its
strike. Kindle already permits self-targeting; its description now says so.
Existing surface-condition scoring applies unchanged: Cinder Wall's earlier
Fire placement gives its bonus `0.80` availability; Hearth Rush uses `0.50`
because its target Fire is painted after the strike, and Move alone does not
supply Fire. Salamander Heart prevents Fire damage without changing either
condition. Costs, coefficients, Fire contact rules and analytics are unchanged;
existing action and surface events retain the actual resolved outcomes.

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

### Repeated consuming payoffs

A Flurry copy cannot reuse Fire or Ice consumed by an earlier copy. Ordinary
Electrified remains available for every copy. Extra copies receive 35% availability
for an additional consuming payoff and matching fuel cost, representing a different
prepared target or component. An explicit painter earlier in each repeated action
sequence restores ordinary availability for a Burst. Ordinary direct hits and
native Chain continue to repeat normally.

### Rules v5 feedback calibration

Printed direct attack damage across the card pool is 80% of its prior value,
rounded half up with a minimum of 1. Burst keeps the printed damage because
Burst already pays for setup. Root Snare retains Rubble and costs 4 Time.

Fire has a coefficient of 0.84 for 5 combined entry and turn-start damage.
Ice keeps 0.60 for Expose 2 on entry or turn start, about one hit per enemy turn.
The scorer values each printed Ice Stagger separately. Rubble's 0.44 credits
the cost of leaving the tile after a melee painter. Electrified's 0.45 credits
reusable geometry. Displacement hazard is valued at 0.24 per tile.
Geometry/contact availability remains bounded. Reusable conduction no longer
receives a repeated-consumption penalty; Fire/Ice consumption still does.
Passive Fire damage leaves Expose available for direct damage.


## Optional Guardian cohort

Fresh maps replace one middle-group fight per section with an optional named
Guardian; the 66-room / 40-fight opportunity budget is unchanged. Each has a
30–66 HP leader and one or two initial 4–6 HP helpers, all occupying one tile.
Guardian repeat clocks use initiative 9–12 plus Time 4–7: Cantor is 11 and Roc
is 9. Bell Tender and Roc Fledgling use Guardian initiative 12; Cantor Wisps
use Guardian initiative 19 while ordinary Wisps remain 7 + 4. Other helpers
retain initiative 8–10 plus Time 4–6. The ordinary local and
completed-section HP, damage and support curves apply without a generic leader
multiplier. Original non-summoned helpers grant one player-card defeat play and zero Embers;
all summoned replacements and original Wisps/Shades grant neither. Initial
helpers are finite. Only authored Call the Spark and Snuff renew Wisps and
Shades, within their data-authored living-kind caps; each successful authored
summon grants one Card Play. Helpers advance on each intent and prefer
complementary safe flanks, keeping Guardian approach and strike tiles clear.
Reaver marks up to nine Fire tiles and leaves Fire after missed sword strikes.
Cantor/Tender extend one shared network toward the player; Peal fires the
Lightning Storm beat. Each Guardian installs its own data-authored cadence and
dials. Rimejaw's Frostbite Staggers occupants of live Ice tiles by 6.
Gallows Roc is Anchored in the Roc's wind. Craghide's beat raises owned 2-HP Outcrops, counted by
Groundsplit. Only hidden Wick Shades Shadowstep; the Lamplighter does not.
With the owner's area-02 storm update, the retained feedback-3 tuning is Rimejaw HP 34 / Pounce 6; Cantor HP 66 /
Lay the Choir 6 fresh linked tiles / Broken Rhythm 11 / Wisp cap 2 / Peal 4 with Chain 0 /
Guardian Bell Tender Staff Bolt 4 (ordinary Staff Bolt stays 3);
and Lamplighter HP 30 / Procession 6 / Shade cap 1 / Mourning Hook 3 /
Guardian-only Shade melee 1. Lamplighter still starts with one Shade: the ladder
stopped at rung 6, so its Procession-5 and empty-start rungs are not applied.
Lay the Choir now spends its remaining tile budget after reaching its target,
extending through adjacent legal nonconductive tiles. Walls, terrain, range, sight
and exhausted ground still limit placement; Bell Tender keeps its connector cap.
Ordinary Shade melee remains 2. These enemy intents have no intrinsic player-card
score in this heuristic. The matched ladders and band flags are recorded in
`peer_benchmark/encounter_redesign/measurements/bos-03-feedback-3/ladders.md`.
Only explicitly authored directional ground patterns retain orientation; ordinary attacks track live targets.
Displacement translates their approach and footprint; blockers/traps shorten the approach
and a surviving caster strikes from its actual arrival. Player dodges do not re-aim
the attack. Occupied summon reservations relocate within the existing summon range,
retaining roster caps and avoiding the caster’s attack footprint. Skipped slots advance.
Craghide guards connected floor at marking time. At the rise, placement and immovable
occupants are checked on the live board. All outcrops block movement and attack sight
and can be cleared by AI.

These optional fights and exclusive trophies are their own analytics cohort;
they do not inflate every printed card's intrinsic score. The scorer exposes
this contract in `guardian_encounters` under `--show-assumptions`. Its trophy
curves distinguish planning payoff from guaranteed value: Brand adds 25% base
Detonate damage per extra overlapping cross, once per actor at its best-covered
footprint cell; Clapper adds 25% base damage per native enemy hop, ignoring
empty relays and conduction-only victims. Both round the combined amount once,
halves up. Spur discounts straight Ice segments but preserves corners and
Rubble surcharges. Talon can yield N × F enemy-steps, bounded by formation and
obstructions. Gauntlet adds one 3-HP outcrop at the empty center of a ranged Earth spell,
with no added target, Move or Stoneskin cost. The useful delay varies with
routes and enemy damage; three terrain HP is not three guaranteed player HP. Lantern redirects existing independent Move to an Illusion without
adding health, vision or another card target. These are conditional synergies,
not flat intrinsic damage or tempo bonuses.


Surface-producing attacks may aim at legal empty ground. A preceding attack
may also share a Fire-ground target with a previous-target Detonate. Range,
visibility and sight still apply, and the attack's own damage requires a victim.
The scorer already values painted ground by ranged placement access separately
from occupant damage and inherits the initiating attack's reach for Detonate;
these coefficients remain unchanged. No additional Fire, forced contact or
owned Gauntlet is assumed in intrinsic card scores.

### Dragon element rules (bos-02; `dragon_pressure_v3` compatibility revision)

The six dragons retain their initiative and clock-12 openings. Zek-01 adds a
second Skybreak to Zekarion's cycle; the other primary cycles are unchanged.
Director feedback 1 tunes base HP, primary damage and boss-only
lieutenant counts through cumulative 50-sample ladders; the first in-band rung
is retained, or the last authorized rung when none qualifies. Each fight now installs one source-owned battlefield rule
from data. The approved context is in
[the dragon rules](peer_benchmark/encounter_redesign/boss_rules_draft.md) and the
[Round 0 measurement report](peer_benchmark/encounter_redesign/measurements/bos-02/measurement.md) and
[director tuning ladders](peer_benchmark/encounter_redesign/measurements/bos-02/feedback-1/measurement.md) and
[final Zekarion ladder](peer_benchmark/encounter_redesign/measurements/bos-02/feedback-2/measurement.md).

| Dragon | Rule and half-Health change | Lieutenants and retained pressure |
|---|---|---|
| Vyraketh | Wildfire spreads Fire in all four directions on Cinder Breath; every second source turn at half Health. | HP 52; Cinder Maw 8, Breath 6; one finite Cinder Droplet. Seven-cell Fire renewal retires source-owned spread Fire; Crownfire detonates only remembered marks. The adjacent-heat rider is removed. |
| Tharokh | Guarded `line_between` Upheaval, length 5 / Health 4, every second hero turn; every hero turn at half Health. | HP 72; two finite Burrow Grubs. Rule Outcrops replace the separate spire kind. Stonewake keeps range 4 with damage 6; Claw damage is 15 and Bedrock damage 10; Claw/Breath pulses and paired raises are removed. Faultline 8 consumes only source-owned stone at radius 1, then keeps shot 4. Flagged lanes preserve their stone and see through it as before. |
| Iskaldra | Frostbite 3 on Rime Talon; every second source turn at half Health. | Two finite Rime Spitters. Mantle, Shatterstorm and Whiteout's previous-trail replacement remain. Mantle absorbs the beat. Talon's surviving-trail rider is removed. |
| Vaeloryx | Clockwise Gust after every source turn, Push 1; Push 2 at half Health. | HP 50; one finite Gust Shrike. Skyhook 4, swept Dive 7, Gale 6 / Push 1, and Eye 8 / inner bite 4. The recorded wake and Gale wake hit are removed. |
| Zekarion | Lightning Storm 6 / Chain 0 on Overload; damage 7 at half Health. | HP 62; Skybreak 5 on nine separated scatter tiles, twice per five-slot cycle (Skybreak, Storm Lash, Call Wisps, Skybreak, Overload). Storm Lash 4. Two Wisps and Call Wisps remain. Overload retains shot 3; its neighborhood hit and Lash's charge pulse are removed. |
| Noctyrax | Void Claw Shadowstep Blinks hidden Veilbound Acolytes 3; no half-Health change. | HP 64; Void Claw 10. Acolytes, Last Eclipse replacement, darkness and braziers remain. The three player-anchored sweeps are removed. |

Battlefield rule beats use the live board, including foes-turn fuel changes.
Rule red shows the current footprint. The Pass forecast simulates the known
foes' turn through those changes. Gust pushes live occupants in its installed
direction, including after a Call in the same foes' turn. Upheaval guards routes
at marking time. At the rise, a mark stays flat only for impassable terrain,
a trap, a guardian brazier, or an occupant the throw cannot move. Raised
Outcrops can be broken. No storm Chains (pla-01 retired the dial). Player Chain and card
scores retain their existing values.

The ordinary completed-sequence curves still scale boss HP and primary attacks;
rule dials retain these authored values. Beat Fire, Ice and Outcrops belong to
the source. Bosses and helpers share their rule's consequences under existing
immunities and force rules. The `dragon_feedback_rules` and
`boss_encounter_roles` scorer metadata mirror this context. No printed-card
coefficient or guaranteed prepared-board uptime changes. The director supplies
the tier-3 policy-v2 tuning ladders; the measurements choose only the first
in-band rung or the final authorized rung.

The prior trophy/card balance remains: Worldheart converts at most 2 leftover
Block per turn, its half-gain Stoneskin pulse stays capped at 4; Gust Step Moves 1
before range-2 Pull 2 / damage 3 at Time 4, scored 2.71 (previous order 2.61).
Newly summoned helpers still wait beyond the next queued player activation.
Trophy and prepared-field benefits remain outside intrinsic printed-card scores.

### Dragon trophy Time and relay context

Winter's Hourglass banks 3 Time after the first Ice card of an activation, capped
at 3. Subsequent non-Ice cards spend only the reserve needed to lower their paid
Time to a minimum of 1; unused reserve persists within combat. This yields at
most 3 Time saved per activation after the initial bank, needs mixed-element
sequencing, and provides no extra plays, damage, or Ice-card discount. A free
Borrowed Time play preserves the reserve. The owned trophy is excluded from
intrinsic printed-card scores, as are other conditional relic synergies.

Stormroad Coil extends a single-target ranged attack through one visible
Electrified tile. Both legs obey printed range and ordinary line of sight; the
target is visible, direct legal contact is preferred, and the route is stable.
Its geometric upper bound is twice printed range, with no damage multiplier or
unbounded relay network. Intrinsic Chain/conduction may still resolve normally
from the selected target. This is conditional reach context, not a global range
coefficient. The scorer exposes both contracts in `dragon_feedback_rules` under
`--show-assumptions`; ordinary card scores remain unchanged.

### Wave-3 keywords and Rites

Scored by `tools/card_heuristic.py` (rules in `spec/card_keywords_wave3.md`):

- Retaliate: `0.35` per point (already folds in the chance of a melee hit before
  your next turn), Shock rider `1.0`, Push rider `0.20` per tile. Damage counts
  as offense, Shock and Push as control.
- Quicken: `0.40` tempo per Time point for the next card.
- Next attack: `0.40` per bonus damage point, `0.60` for Pierce, `0.45` per Chain
  hop. `per_tile_moved` expects the card's own Move/Blink tiles plus `1`, capped
  at its maximum.
- Rite: `breakdown.rite` sums per-effect estimates over `3` remaining
  activations; the only card cost beyond Time and health is the ordinary Exhaust
  penalty. Estimates per activation: Fire damage bonus `amount x 0.45 x 0.60`
  Fire hits; Fire immunity `3 x 0.40 x 0.50` avoided contacts; on-surface turn
  start rewards at `0.50` availability; Ice Stagger rewards at `0.50` Ice Staggers; surface
  pulse and adjacent player Outcrop pulse `damage x 0.45 x 0.80` targets; card Time discount
  `amount x 0.45 x 2 cards x 0.80` availability; independent movement `0.25` per
  tile; forced-movement bonus `0.28 x 0.60` forced moves; turn-start rewards at
  their ordinary reward values; target-in-Light damage `amount x 0.45 x 0.50`
  lit attacks; thorns at the Retaliate values. A player Light aura is scored as
  Illuminate with the radius and a 3-activation duration.

### Wave-4 movement, forces, flags, Stagger and Mantle

Scored by `tools/card_heuristic.py` (rules in `spec/card_mechanics_maneuver.md`;
tests `tests/test_card_heuristic_maneuver.py`):

- `force_area`: each tile of Push is `0.28 + 0.24 + 0.30` (push, displacement
  hazard, collision) and each tile of Pull `0.14 + 0.24 + 0.30`; there is no
  directed `0.03` bonus because an area has no Rotate. Expected targets are
  `min(2.5, 0.60 + 0.45 x radius)`. A tile-centered area uses ranged
  playability for its range; a self-centered one uses
  `min(0.95, 0.45 + 0.15 x radius)` availability. Expose adds `0.32` per point
  per target. `consume_center` scales the area by the `0.50` setup availability
  and costs `0.35 x 0.50` fuel.
- Squall's `force_mode: from_center` is priced like the AOE's Push rider.
- Swap: `0.25` mobility per range tile plus `0.60` control (repositioning an
  enemy) at ranged playability.
- `trail_surface` on Push/Pull adds the surface per tile moved (with the usual
  extra-tile retention) at the attack's playability; on Move it covers
  `0.67 x range` tiles. `origin_surface` is one tile. Both use the `0.50` setup
  availability.
- Self flags: Skate `+0.45` mobility, Rooted `-0.50` mobility, Anchored `+0.60`
  defense, Fireproof `+0.50` defense.
- Cleanse `0.35` defense per listed status; Block to Stoneskin expects `4` Block
  converted at `0.40 - 0.25` per point.
- Mantle `1.60` defense per layer (a layer cancels one whole direct hit after
  Block and lasts until broken).
- A targeted `stagger` action scores `N x 0.30` control at ranged playability.
- Move riders: `block_per_tile` prices `0.67 x range` tiles of Block;
  `straight_line` keeps `0.75` of the Move's tiles; `trail_light` is Illuminate
  with `1 + 0.35` per extra lit tile; `if_started_on_surface` rewards at `0.25`
  availability. Blink riders: `destination_requires_light` keeps `0.60` and
  `destination_adjacent_to` `0.85` of the Blink's tiles; `illusion_at_origin` is
  an illusion of that health; `if_no_adjacent_enemies` rewards at `0.60`.

### Owner card simplification (crd-09)

Hotfoot now uses the same current-position `surface_bonus` as Polar Guard:
2 Block plus 4 on Fire, before an ordinary Move 2, at Time 2. It draws no
cards. Existing Block, surface-availability, move/defense synergy and tempo
weights score it at **3.25** (previously **2.31**).

Joust now uses ordinary Move 4 followed by a required 7-damage Push 2 at
range 1, at Time 4. Existing movement, damaging Push, displacement and tempo
weights score it at **3.30** (previously **3.36**). Neither card needs a new
weight or card-specific scorer override.

The legacy `if_started_on_surface` and `straight_line` support remains because
the brief explicitly preserves rules used by test fixtures. `maneuver_suite`
still exercises both through `w4b_hotfoot` and `w4b_joust`; `relic_u6_suite`
and `relic_u7_suite` also exercise straight Moves with Glassway Compass and
Vaulting Sigil. Their runtime, face tokens, panel copy and scorer weights
remain unchanged. Neither production card uses those riders anymore.

### Wave-4 surface family

Scored by `tools/card_heuristic.py` (rules in `spec/card_mechanics_surfaces.md`):

- `surface_adjacent_enemies`: the surface's per-tile value over `0.90` expected adjacent
  enemy tiles (`+1` tile with `include_self`, extra tiles at the usual `0.45` retention).
- `consume` rider: bonus damage is the damage-value difference at the surface's setup
  availability (`0.50`, or `0.80` after an earlier painter), plus a `0.35` fuel cost at the
  same availability. `required` scales the whole attack by that availability instead.
- Detonate: availability and fuel use `detonate_surface` (Rubble for Magma Vent);
  `spare_player` drops the `0.45` shared-hazard cost; `leave_surface` adds the surface value of
  a five-tile cross at the Detonate's availability.
- `convert_surface`: at Ice availability, `damage` over `1.20` expected targets, Shock at
  `2.5 x 1.20` targets, the value of two connected Electrified tiles, minus fuel for `2` Ice
  tiles. With `source_optional`, the off-Ice share scores the damage and Shock on `1.00`
  expected target and one Electrified tile. Only the Ice share pays Ice fuel.
  `discharge`: at Electrified availability, `damage` over `1.60` targets, minus fuel
  for a `2`-tile network.
- `consume_surface` `per_tile` rewards expect `2` tiles removed (capped at `max`); fuel cost
  uses the same expected count. With `min_consumed: 0`, `base_amount` is guaranteed and
  counts toward `max`. Only the remaining reward and fuel cost use surface availability.
- `on_result`: the reward list's board-independent value (no Time or synergy terms) at
  `0.30` on Ice or `0.35` on a kill
  availability, times the attack's playability.
- `all_enemies`: targetless (playability `1.0`); expected targets `0.90` on Fire, `0.80`
  on Ice, `1.00` in Light, `0.80` on Electrified (`+0.20` after an earlier painter of that
  surface, `x0.85` with a printed range). Score Expose and Stagger per target.
  White Silence's `on_ice` strike Staggers each qualifying enemy by 6.
  The `visible` selector expects `2.00` targets. A target surface bonus adds the difference
  between the full one-hit value and the base value over the targets expected on that surface.
- `ignore_los`: `+0.08` playability (capped at `1.0`). `shock_all_hits` adds nothing: Shock is
  already priced per expected target, including Chain and conduction.
- `meteor_marks`: damage at the range playability `x 0.55` delayed hit rate over the area
  target multiplier, plus the full surface value of the marked pattern.

### Wave-4 illusion and terrain families

Scored by `tools/card_heuristic.py` (rules in `spec/card_mechanics_illusions_terrain.md`);
the base decoy keeps `0.48` per illusion health point and `0.12` per placement range tile.

- Retorts: an enemy damages a charged illusion before it fades `0.55` of the time.
  `on_damaged` is the retort damage at that playability with one target (offense) plus
  `2.5 x shock x 0.55` control; `reflect` is `min(health, 3) x 0.45 x 0.55` offense.
- `surface_ring`: the surface value of a four-tile cardinal ring at `0.60` retention.
- `ring_around_self`: `2.5` expected illusions (the extra `1.5` at the health value).
- `adjacent_to_enemy`: `0.60` control for the flanking placement plus Expose at `0.32`
  per point.
- `ranged_origin`: `1.60` control for a second firing position.
- `illusion_swap`: needs an illusion on the board (`0.55`); a Blink of at most `3` tiles
  (`0.33` per tile, mobility) plus `transfer_block` as `4` Block points moved onto the
  illusion at the illusion-health value.
- `destroy_illusion`: the Burst at `0.55` availability (an illusion on the board) and
  `burst_cross_targets`, plus the shared hazard. Shattered Reflection's `any_tile` Light
  happens on every play and is counted once at the ordinary Illuminate rider value.
- Refraction (`also_hits_near_illusions`): the hit again at its playability against `0.6`
  expected extra targets.
- `burst_terrain`: the Burst at `0.70` availability (crates are common) and
  `burst_cross_targets`; a Rockburst follow-up also scales by its attack's playability and
  leaves Rubble on the cross. Worldbreak needs your own adjacent Outcrop (`0.40`) and spares
  you (without `spare_player`, an adjacent Burst pays its damage as a Health cost). Stagger
  at `0.30` per point times availability and targets.
- A powder keg adds its Burst at `0.45` detonation chance and `1.40` targets to the
  ordinary outcrop value.
- Worldspine scores its four 4-Health Outcrop placements as defense and its
  turn-start pulse as a Rite. Its score stays `6.02`. The former independent
  spire pulse contributed `3.24` offense, and the Rite now contributes `3.24`.
  Extra coverage from combining Outcrop cards is a multi-card synergy outside
  the standalone score.


## Director-authored section enemies E1: en-02

Values come unchanged from `peer_benchmark/staged/enemies/wave_e1.json` and
`peer_benchmark/enemy_roster_v1.md`; this implementation does not tune them.
The scorer records the same assumptions in `section_enemies_e1_en02`.

| Enemy | HP / base initiative / Embers | Authored weighted cadence at local depth 2 | Closest existing comparison | Shared risk and counterplay |
| --- | --- | --- | --- | --- |
| Hoarfrost Seer | 12 / 12 / 11 | Initial 17; repeat 16.667 including forced Icefall landing | Frostglass Lancer 12 / 11 / 11; Acolyte 12 / 12 / 10 | Range-5 three-tile delayed line, 5 damage per tile, then Ice ground (el-02); leave the marks or place enemies on them |
| Gale Herald | 14 / 13 / 11 | 18.167 | Chainbound Gaoler 14 / 13 / 12 | Two enemy-turn boundaries of shared Push 1, including Call's own turn; downwind-first ordering, ordinary collision/surface/trap rules; stand upwind or kill the Herald |

Cadence is base initiative plus authored intent time, before initial index
stagger, sequence scaling or status skips. Seer random weights are 3:2:1 for
mark / bolt / withdraw. Mark always adds a zero-random-weight landing slot:
mean time is `(3*(6+4)+2*4+1*4)/(3*2+2+1) = 4.667`. Herald mean time is
`(3*6+2*4+1*5)/6 = 5.167`. Illegal ranged intents and out-of-range marks are
removed before a seeded weighted roll. These are roster assumptions, not new
card coefficients. Gust resolves after the source's turn, including skipped turns.
Only Anchored protects a unit; rank and construct labels confer no exemption.
The immobile forced-movement guard still applies. Icefall leaves Ice ground;
Bramble and Ice Pillar terrain are retired in el-02.
Enemy kills retain existing reward
rules and never gain a player-card kill bonus. Per director feedback 1, enc-01
has landed; the director adds these enemies to spawn pools after merge.
### Section wave E1: en-03

| Enemy | HP / initiative / Embers | Authored cadence before spawn stagger | Reach and counterplay | Closest comparison |
| --- | --- | --- | --- | --- |
| Arc Thrall | 10 / 11 / 9 | Arc Bolt 16 (3/5), Arc Jab 15 (2/5); weighted 15.6 | Arc Bolt: Move 2 + ranged lightning 3, range 3, leaving Electrified on the target tile. Arc Jab unchanged: Move 2 + melee 3 + Shock 1. No pairing constraint. | Storm Lash uses the same movement and ranged primitives; Lightning Wisp provides the existing Shock comparison for Jab. |
| Gloam Stalker | 11 / 10 / 10 | Fade 15 (3/5), Slash 14 (2/5); Fade forces Ambush 15. Including that forced step, (3×30 + 2×14)/8 = 14.75 per activation. | Fade Blink ≤4 behind the hero's visible facing, with a legal adjacent fallback; no Veiled status or targeting restriction. Ambush re-Blinks if needed, melee 7; Slash Move 2 + melee 4. Normal movement, blocking and attacks remain available during wind-up. | Tunnel Crawler's melee closure, with positional Blink and a revealed high-damage follow-up. |

The Thrall follows owner-approved `thrall-rework-v1` (2026-10-30); the Stalker
retains its protected staged values with the approved removal of Veiled. The
cadence calculations are authored-weight comparisons, not estimates of uptime. Arc Bolt uses ordinary ranged damage
scaling and the existing Electrified surface rider. Movement blockers, range,
line of sight, Shock and blocked Blink destinations reduce realized
pressure. Enemy kills preserve existing Ember drops without player-card kill
bonuses. Intrinsic card coefficients are unchanged.
The matching rows are exported by `tools/card_heuristic.py` under `en03_enemies`.
## Section regulars: EN01 (director roster v1)

These are encounter-context rows, mirrored in `tools/card_heuristic.py`
`SECTION_ENEMY_ROSTER`; intrinsic printed-card coefficients are unchanged.

| Enemy | Base HP / initiative / Embers | Weighted cadence before spawn stagger | Reach and pressure | Comparison / counterplay |
| --- | --- | --- | --- | --- |
| Burrow Grub | 12 / 10 / 10 | First choice 14.6; steady activation mean 14.75 including forced Erupt | Gnaw Move 2 + melee 3. Burrow snapshots hero tile; Erupt 6, displaces center and pushes cardinal neighbors, Rubble, self-Expose 2; no exit means center stays and grub surfaces nearby | Frostglass Lancer's baseline HP and cadence, with held positional pressure instead of Ice lanes. Leave mark, push an enemy onto it, punish Expose. |
| Ember Tick | 6 / 8 / 6 | 12 | Scuttle Move 3 + melee 2; death Burst 4 on its tile and four neighbors, Fire on own tile. Kindle +2, cap +4; breadth-first friendly-fire chains. | Tunnel Crawler's fast cadence, with lower HP and explicit kill-order pressure. Kill at range, place beside allies, Block bursts. |

Burrow's selectable weights are 3 (Time 5) and 2 (Gnaw Time 4).
Its forced Time-5 Erupt has weight zero: the steady mean is
`10 + (3 * (5 + 5) + 2 * 4) / (3 * 2 + 2) = 14.75`.
Kindle and Scuttle both cost Time 4. The Kindle cap removes a no-op choice.
Generic `next_intent` forces the following declaration; weight-zero declarations
are never sampled randomly. Both enemies remain staged until `enc-01` provides
`data/encounters.json`; no existing pool was changed in this base.
Enemy-caused kills retain the existing Ember policy; only the initiating
player-card kill grants the existing bonus card play. No new analytics event
is needed: resolution uses existing enemy actions, deaths, and ground events.

## Section regulars: EN05 (director roster v1)

Authored values are protected by `peer_benchmark/staged/enemies/wave_e2.json`;
matching assumptions live in `tools/card_heuristic.py` `en05_enemies`. These
are encounter comparisons, without new intrinsic card coefficients.

| Enemy | HP / initiative / Embers | Authored weighted cadence | Reach and counterplay | Existing comparison |
| --- | --- | --- | --- | --- |
| Glacial Mirror | 20 / 15 / 13 | 20.5 | Reflect returns a damaging attack from a non-adjacent origin once per Mirror before its Block. Area, Chain and damaging Push or Pull attacks reflect. Adjacent hits, pure status and movement, ground and Bursts land. Four-tile Refraction deals 4 damage to both teams and Staggers targets on Ice by 6. A bounced Refraction returns the damage and rider to the caster. Crystal Guard 6 to least-Block adjacent ally, itself only without allies. Only Anchored prevents Gust. | Warden's heavy support role; Frostglass Lancer's oriented ice pressure. |
| Gust Shrike | 9 / 9 / 8 | 13.5 | Flying ignores ground costs/contact; ordinary terrain blocks its route and ordinary Push still applies. Move Toward 4 then shared swept_path AoE 4 Air / Push 1; actual held route and existing one-tile reach. Shared Push away from source includes hero; allies block movement without side pushes. Talon Rake Move 2 + melee 4; Hover away 2 + Block 3. | Harrier's mobile melee role at light HP/cadence. |

Cadence is `base_initiative + sum(weight*time)/sum(weight)` before spawn
stagger and legality filtering. Neither entry is added to encounter pools by
this unit: the director owns `ice_mirror` and `air_shrikes` after merge.
sta-01 replaces the special line/side-push resolver with the shared swept-path
shape used by Razor Dive. Normal hover previews, movement blockers, actual-path
clipping and Push collision rules apply. AoE targets hero/illusions; no friendly
side pushes remain. Existing enemy action analytics remain authoritative.
Intrinsic player-card coefficients are unchanged; `tools/card_heuristic.py`
exports these encounter assumptions alongside the unchanged cadence values.

## Director-authored section enemies E2: en-04

Original protected source: `peer_benchmark/staged/enemies/wave_e2.json`; enc-03
overrides only Slag Mortar availability, Lob weight and Brace movement in
`data/enemies.json`. Assumptions are mirrored by `tools/card_heuristic.py` under
`section_enemies_e2_en04`; intrinsic card coefficients are unchanged.

| Enemy | HP / base initiative / Embers | Authored mean cadence at local depth 2 | Comparison and positional counterplay |
| --- | --- | --- | --- |
| Briar Weaver | 14 / 12 / 11 | 17.5 when all three intents are legal: 12 + (3×6 + 2×5 + 5)/6 | Hoarfrost Seer 12 / 12 / 11 and its terrain control. Thornwall marks three front-line tiles, then on the Weaver's next turn Upheaval raises health-3 Outcrops with ordinary displacement; move before the rise or destroy the Outcrops. Lash 4 within 3; heal most wounded other ally within 3 for 4, otherwise Lash. |
| Slag Mortar | 18 / 14 / 13 | enc-03, range 2–6: 20 initially (14+6), 19 steady including forced landing: 14+(6+4)/2. Adjacent: 19 (Scatter/Brace both Time 5). | Hoarfrost Seer delayed geometry and Warden 20 / 14 / 12 heavy anchor. Lob snapshots a cross ignoring sight; centre 5, arms 3, then Fire, retaining depth scaling. Leave the cross, push enemies onto it, become adjacent to deny new marks. Adjacent Brace Block 6 without movement; adjacent Scatter ranged 3 + Push 1. The Warband captain retains only its existing keep_distance retreat. |

enc-03 changes Lob weight 3→4, minimum range 3→2, and gates both Brace and
Scatter to adjacency. At distance 2–6 only Lob is eligible, so the weight does
not change its conditional share: the mark/land cycle is 20/18 Time, mean 19.
Adjacent authored weights remain Scatter 2 and Brace 1; both cost 19 Time with
base initiative. Removing Brace's Retreat 2 removes that movement; the captain's
separate keep_distance step remains. Damage, health, Fire and both lob turns
retain their existing values and scaling. Intrinsic card coefficients are
unchanged; the matched revision-7 encounter report is in
[enc-03](peer_benchmark/enc-03/measurement.md).
Thornwall now marks once and uses the shared Upheaval resolver on
the Weaver's next turn; Outcrops have health 3 and ordinary durability, sight,
displacement and collision rules. Friendly-fire rewards retain existing Ember
rules and never player-card bonus credit. Pending marks round-trip through the
save decoder; retired terrain is removed at load. Existing primitive analytics
remain sufficient; encounter beats use `battlefield_rule_fired`.
The design owner adds encounter groups after merge.
## Section regulars: EN06 (director wave E2)

Baseline values come from `peer_benchmark/staged/enemies/wave_e2.json` and
`peer_benchmark/briefs/en-06.md`; owner-approved mim-01 replaces the Mimic
copy mechanic with Echo/Retaliate. No intrinsic card coefficients change.

| Enemy | HP / initiative / Embers | Authored local-depth-2 cadence | Existing comparison | Pressure and counterplay |
| --- | --- | --- | --- | --- |
| Storm Capacitor | 22 / 16 / 13 | Three 20-Time Charge turns, then a 21-Time Discharge; mean 20.25 | Stone Warden's durable anchor; Lightning Wisp's electrical reach | Persistent Charge 0–3; nearest target within 4, then side-adjacent hops for 6/5/4/3. Every tie prefers the hero, then lowest current HP, tile y, tile x. Immobile and anchored; becoming Shocked removes one Charge. Kill before three pips, Shock, or separate units; chain can kill allies under the existing friendly-fire reward rules. |
| Hollow Mimic | 14 / 12 / 11 | Authored weighted mean 17 | Veilbound Acolyte's ranged pressure; Gloam Stalker's positioning | Echo: 3 shadow damage at range 4, then Retaliate 3 until the Mimic's next turn. Melee or adjacent hero attacks trigger one Retaliate. Block and Stoneskin absorb Retaliate damage. Expose leaves Retaliate damage unchanged. Distant ranged/area attacks avoid Retaliate. Shade Bolt 4/range 4; Recede moves away 2 without Block. |

The scorer's `en06_enemies` context mirrors these assumptions. The director owns
encounter additions after merge. Existing enemy-action events, source attribution,
death rewards and save storage carry these mechanics without new analytics types.


## Warbands (spx-03)

Revision-6 specials use the protected `data/special_encounters.json` (or its
staged copy before spx-02). Warbands use a specific biome captain and the first
3/4/5 ordered escorts by local tier before the shared five-starter cap; the
last tier-3 escort is removed, giving all remaining starters ×1.2 Health.
Captain HP is the ordinary depth-scaled
HP ×1.25, rounded up; Stoneskin is 2/3/4, replacing generic leader bonuses.
There is no art/footprint scaling. Per director feedback 1, Manhattan ranges
govern the captain's 5–7-tile opening and every escort's minimum entry distance
of 3, also outside the ordinary spawn halo. The screen lies on a Manhattan
shortest segment, with reachability checked separately from that equality;
other escorts start within 3 of the captain. After 20 seeded rerolls the
deterministic fallback relaxes escort clustering first, never entry safety.
The protected data's original 4–6 range is overridden in `WarbandRoomRules`
without rewriting that owner-supplied file. Manhattan ranges also govern
Command radius 2 (+1 damage to every follower damaging action), and the
keep-distance trigger at range 2 (one normal movement tile before the ordinary
intent, favoring a follower screen; immobile captains skip it). Captain death
ends combat; surviving followers flee without death effects or individual
rewards. Individually killed followers also award no Embers. These assumptions
are mirrored by `tools/card_heuristic.py --show-assumptions`; intrinsic card
coefficients remain objective-neutral and unchanged. No card mechanic changed,
so no card score is recalibrated. Compare realized AOE/execute/control value by
the existing objective cohort. Variant orders are outside this unit.

## Ember Hoarder (spx-09)

The Ember Hoarder room is the Hoarder plus four Ember Ticks at every tier, in
the Warband captain's back-line formation. The Hoarder is an Ember Tick with
3× the room's scaled Ember Tick Health, no Stoneskin, Kindle (weight 1) and
Scurry (`move_away` 2, Time 4, weight 2), and no attack. It takes the captain's
keep-away step when the hero is within 2. After the hero's 5th turn (tier 1) or
4th (tiers 2–3) it dissolves silently and the fight continues as Defeat All with
standard rewards. Killing it first wins at once: the brood flees without death
effects and its own death burst fires. A catch pays the shared special reward
plus one standard fight's Embers. These assumptions are mirrored by
`tools/card_heuristic.py --show-assumptions`; no card mechanic changed, so no
intrinsic card score is recalibrated. Compare realized burst/execute and
movement value by the existing objective cohort and `hoarder_result`.


## mrk-01 — Marked vocabulary consolidation

Icefall (Hoarfrost Seer), Lob Slag (Slag Mortar), and Burrow/Erupt (Burrow
Grub) retain their names as moves but share the single glossary keyword
**Marked**: “These tiles take the hit on this enemy's next turn.” Their old
names resolve as aliases. No number, shape, range, target, activation timing,
surface, status, element rule or hit reaction changes. Existing comparison
rows above remain applicable. `tools/card_heuristic.py` labels these three
assumption records with `keyword: marked`; intrinsic scoring coefficients
and combat assumptions are unchanged, so no changed mechanic needs rescoring.
Permanent timing, shape and old-save checks live in `tests/mrk01_marked_test.gd`;
`tests/enc03_slag_test.gd` checks resolved damage and barrage presentation.

## Four difficulty tiers (tune-01)

Normal rooms retain section Health/damage scaling. Every generation path caps
non-summoned starters at five, removing from the existing tail order while
preserving leaders, captains, jailers, Sealbinders, Hoarders, Guardians and dragons.
Each newly removed starter grants ×1.2 Health to the remaining starting roster
before the tier table. Hunted adds an enemy below five when a legal spawn tile
is free; if the cap or tile availability prevents the spawn, it multiplies each
starter's final Health (including trim and tier scaling) by 1.2 and rounds up.
Table capacity trims that already occurred at
three/four/five units do not gain a new compensation.

`data/difficulty_tiers.json` stores per-section objective/kind, Guardian and boss
dials. Generated layouts freeze those dials. After existing local, section,
leader/special and Umbra Depth rules, tier Health multiplies final max Health
once, rounding up. Hoarder Health is then derived as 3×the scaled brood, before
any full-room Hunted bonus.
All later arrivals use the room's frozen Health percentage. Tier damage adds
through the existing section-damage applicability rules; support is unchanged.
Old generated rooms without dials retain identity scaling. Unmeasured s1/s3
Health is the neighbour mean rounded to five; s5 copies s4.

This changes encounter context, not card mechanics or intrinsic card coefficients.
The scorer reports the count caps and table source in `--show-assumptions`;
relative Health-cost measurements live in the tune-01 report.
