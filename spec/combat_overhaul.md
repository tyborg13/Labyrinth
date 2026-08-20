# Combat Overhaul: Committed Patterns And Elemental Surfaces

## Status

This is the authoritative implementation and migration contract for the 2026 committed-pattern combat overhaul. It supplements the task contract recorded by `tools/parallel_task.py`; it is not a future-design wishlist.

Current phase: **live shared foundation and player-loop integration**.

Implemented checkpoint:

- deterministic Field/Surface state, replacement, refresh, coexistence, and initiative-clock expiry;
- live environmental traversal/start effects, Bramble truncation, Poison movement arming, Electrified discharge/attack suppression, Ice continuation/collision, Snowdrift vulnerability, and Combust;
- one free unsplit Move 2 per player activation with no card-play or Time cost;
- player-facing Move 2 selection, board preview, committed animation/persistence, and direct authored-card play with no fallback selector or drag zones;
- reusable committed-pattern stencil, translation, rotation, overlay, and short-circuit helpers;
- focused engine integration tests plus a passing full baseline suite.

Not yet migrated at this checkpoint: engine/data/skill fallback retirement, stored enemy plans/setup movement, content data, save schema, analytics/heuristic, final visuals/tutorial, and exhaustive verification.

Live inventory at the start of the branch:

- 159 cards: 72 elemental and 87 neutral/equipment cards
- 18 enemy definitions, including the elemental dragons and Noctyrax
- 60 relics
- 42 equipment definitions
- 30 learned skills/abilities
- 43 card intensity actions, 5 enemy intensity actions, 5 top-level card intensity costs
- actor-status uses of Burn, Poison, Freeze, and Shock across cards, enemies, traps, relics, skills, upgrades, analytics, fixtures, and UI

Run `python3 tools/combat_overhaul_audit.py` for the current migration inventory. The task is not complete until `python3 tools/combat_overhaul_audit.py --strict` passes along with the full proof contract.

## Player-facing design statement

- **Surface:** combat board, cards, enemy intents, turn clock, contextual tooltips, tutorial/Grimoire, rewards, loadout, abilities, and relic detail.
- **Player question:** “What will happen on the board if I commit this movement/card, or if I let this enemy intent resolve?”
- **Primary action:** select one card pattern or use the once-per-activation free Move 2, inspect the complete consequence preview, then commit.
- **Hierarchy:** actors, movement routes, damage, collision, and resulting Field/Surface tiles are immediate board information. Card/relic/ability rules and exact timings are focus/pin detail. Tutorial prose is contextual and never persistent over the board.
- **Interaction paths:** preserve pointer, keyboard, controller, and active-input handoff behavior currently supported by combat. No required rule may exist only on hover or by color.
- **Proof matrix:** fresh real-renderer captures at 1920x1080 and 100% UI scale for normal, focused, selected, interrupted, dangerous-route, reduced-motion, and before/after resolution states. Logic tests separately prove every consequence.

## Combat vocabulary

The overhaul removes elemental intensity, its builders/spenders/gates, fallback Attack/Move card modes, and the actor-status versions of Burn, Poison, Freeze, and Shock. It must not preserve those systems behind compatibility UI or new names.

The recurring combat vocabulary is:

- **Move:** voluntary path traversal.
- **Blink:** teleport to a destination without traversing intermediate tiles.
- **Pattern:** a committed, rotatable spatial stencil containing ordered movement, attack, force, Field, and Surface segments.
- **Collision:** the shared consequence of attempted movement into a blocking actor or solid tile.
- **Field:** factional tile alignment. A tile has at most one Field.
- **Surface:** actor-neutral tile physics. A tile has at most one Surface.
- **Support:** Block, Stoneskin, healing, draw, Illusions, and other non-attack actions that remain within the small shared vocabulary.

Content variety comes from pattern shape, orientation, reach, sequence, timing, damage profile, and placement footprint—not one-off statuses.

## Tile state

Combat state owns two independent collections:

```text
Field:   Neutral | Corrupted | Radiated
Surface: None | Bramble | Poison | Ice | Snowdrift | Electrified
```

A tile may contain one Field and one Surface. Applying the opposite Field replaces the current Field. Applying a Surface replaces the current Surface. Reapplying the same state refreshes its expiry and never stacks.

Every placed Field and Surface records an absolute `expires_at` value on the initiative clock. Expiration is origin-independent, survives originator death, and occurs deterministically when the clock advances. Cards and intents may specify a duration, but the initial live pool should use shared standard durations rather than a forest of bespoke values.

The board presentation uses Field tint/atmosphere beneath one readable physical Surface treatment. Actors, routes, target contours, and impact previews always render above atmosphere.

### Corruption

- Entering/traversing a Corrupted tile deals 1 damage to the player per tile.
- Starting a player activation on Corruption deals 1 damage.
- An enemy starting its activation on Corruption heals 1, capped at maximum HP.
- Field and Poison damage is environmental HP damage: it bypasses Block and Stoneskin and never inherits attack modifiers.
- Enemy corruption footprints are committed parts of their intent sequences.
- Only the actually resolved prefix of an interrupted sequence leaves Corruption.

### Radiance

- Light actions Radiate their affected tiles. Radiating Corruption replaces it.
- Entering/traversing a Radiated tile deals 1 damage to an enemy per tile.
- An enemy starting its activation on Radiance takes 1 damage.
- Radiance locally suppresses Umbra through the existing visibility/light presentation rather than creating a separate Light-tile state.
- Radiance does not heal the player; repeatable combat healing remains explicit card/relic/ability value.

### Bramble

- Entering Bramble ends the current movement immediately on that tile.
- Starting on Bramble does not prevent moving away.
- Bramble affects voluntary, forced, charging, and sliding movement for either faction.

### Poison

- Entering Poison arms the current movement only.
- Every subsequent tile traversed during that same movement deals 1 damage.
- The armed state ends with the movement and is not stored as an actor status.

### Ice

- Entering Ice locks the current direction.
- The actor continues through the connected Ice strip and attempts to land on the first non-Ice tile.
- A blocked continuation resolves through the universal Collision rule.
- Sliding is one movement sequence, so Poison, Fields, and Electrified evaluate along the complete traversed route.

### Snowdrift

- Attacks against an actor standing on Snowdrift deal the shared Snowdrift bonus.
- Snowdrift does not amplify Field ticks, Poison traversal, collision, or other environmental damage.

### Electrified

- Entering or starting an activation on Electrified discharges the tile.
- The affected actor's attack segments are suppressed for its current activation, or its next activation when triggered outside its own activation.
- Movement, support, card play, and the remainder of an intent still resolve.
- The Surface is consumed when discharged, preventing repeatable stun terrain.
- This is board-triggered attack suppression, not a persistent Shock actor status.

### Collision

- Collision is actor-neutral and uses one shared damage rule for Ice, Air displacement, charges, and other forced movement.
- A moving actor stops before an impassable tile and at the last legal tile before another actor unless the authored sequence explicitly occupies the contacted tile after destroying/removing it.
- Actor collision applies the same previewed result regardless of the originating element.

## Element identities

No card, relic, ability, upgrade, or room rule checks elemental intensity or same-element counts. Each element contains internal setup and payoff, while cross-element synergy emerges through shared geometry.

### Earth: stop and punish movement

- Places Bramble and Poison in authored patterns.
- Uses defensive placement to break committed routes or hold enemies in attack patterns.
- Uses forced movement and enemy charges to cash out Poison routes.

### Ice: redirect and expose

- Places Ice strips and Snowdrifts.
- Slides either faction through Fields/Surfaces or into collision.
- Holds high-value attack destinations with Snowdrift rather than applying Freeze.

### Air: translate

- Push and Pull vectors are embedded in the selected pattern.
- Selecting the card anchor/orientation is the only directional input; there is no second direction click.
- Air turns existing Fields, Surfaces, actors, obstacles, and Illusions into geometry.

### Lightning: connect and interrupt

- Chain remains an exact, fully previewed payoff for grouping actors.
- Electrified is the board replacement for Shock.
- Chain selection and order must be deterministic before commit.

### Fire: broad damage and cash-out

- Fire owns the broadest/highest-damage attack patterns.
- **Combust:** a Fire attack deals the shared Combust bonus to an actor standing on a Surface, then removes that Surface.
- Combust consumes Surfaces, not Corruption/Radiance Fields.
- Fire creates no Burn actor status or generic burning-floor Surface.

## Pattern contract

Player cards and enemy intents resolve through one canonical plan representation. Authored data may use concise action primitives, but preview and resolution must consume the same canonical plan.

A plan records:

- origin and cardinal orientation;
- the selected anchor/target used to choose that orientation;
- ordered segments;
- movement route and destination;
- attack tiles and damage profile;
- forced-movement vectors;
- Field placement tiles;
- Surface placement tiles;
- collision/short-circuit boundaries;
- support footprint where relevant.

One selection determines anchor and orientation. Cards do not ask for a separate push/pull direction. The board preview exposes movement, damage, force arrows, resulting tile state, route damage, collision, and cancelled sequence suffixes before commit.

### Enemy commitment

Enemy intent selection stores a committed plan. It does not recalculate a target at resolution.

- Moving the player does not move the plan.
- Displacing the enemy translates the plan from its new origin while retaining its committed orientation and sequence.
- Rotation only changes when an explicit effect rotates an actor/plan.
- The first blocking actor or solid object short-circuits applicable movement/projectile segments.
- Downstream damage, movement, and Corruption from a cancelled suffix do not occur.
- Illusions and other enemies are valid interceptors and receive normal committed attack consequences, including friendly fire where the sequence allows it.

Enemy activation order is:

1. Apply start-of-activation Field/Surface effects.
2. Resolve the currently committed plan.
3. Reposition up to one legal orthogonal tile with no damage or Corruption.
4. Select and commit the next plan from the new position.
5. Reschedule on the initiative clock using the next intent's authored timing.

Immobilize/Bramble and board physics can prevent or truncate movement. Support intents remain legal variety: self/ally Block, Stoneskin, and healing should use committed self or spatial support geometry where displacement can create meaningful counterplay.

## Player activation and card economy

- Base card plays remain 2 during the first balance pass.
- At activation start the player gains one unsplittable free orthogonal Move of up to 2 tiles.
- The free move may be used once before, between, or after cards, costs no card play, and does not add card Time.
- It follows normal path traversal and Surface/Field rules.
- Blink traverses no intermediate tiles and only evaluates its destination.
- Printed movement cards remain valuable through longer routes, Blink, attack+movement sequences, Surface interaction, and forced movement.
- Cards have only their printed behavior. Contextual fallback Attack/Move modes and their selector placards are removed.
- Existing transformative fallback skills are migrated to modify the free move or printed patterns instead of restoring hidden card modes.

## Content migration rules

### Cards and equipment

- Preserve names, rarity, art, equipment ownership, and role when the existing identity still fits.
- Replace intensity actions/bonuses/costs and actor statuses with patterns, Fields, Surfaces, force, Chain, Combust, Illusions, Blink, Block, healing, draw, and timing.
- Every attack card receives an explicit pattern and preview contract.
- Every elemental package must contain setup, conversion/movement, and payoff cards without requiring another element.
- Equipment continues to shape the deck and every equipment card is included in the exhaustive audit.

### Relics

- Preserve rarity as a conditional-power ladder.
- Reuse strong Illusion, Blink, Radiance/Umbra, Defiance, and card-economy identities when compatible.
- Replace intensity/status hooks with reusable hooks over Field placement/clearing, Surface placement/consumption, traversal, collision, intent interruption, committed patterns, Chain, Combust, and free movement.
- Do not add per-relic id branches or private mechanics.

### Skills and abilities

- Preserve run/reward/loadout skills unrelated to combat when compatible.
- Replace fallback/intensity skills with qualitative modifications of free Move, Blink, Fields, Surfaces, Illusions, and pattern commitment.
- Skills remain monotonic and may not make a previously legal action worse.

### Enemies and encounters

- Preserve silhouettes, names, art, HP bands, cadence roles, and support identities where compatible.
- Every damaging enemy intent becomes a committed plan with authored movement, damage, Corruption, and interruption behavior.
- Healing/Block/Stoneskin/summoning remain variety, but support footprints are previewed and use shared rules.
- Bosses may combine or sequence the same core rules; they may not create unaudited private tile statuses.
- Room-element specialist gating may remain only when it affects encounter composition, not player intensity.

### Saves, analytics, balance, and tutorials

- Loaded legacy saves migrate intensity/status/fallback state once at the load boundary and persist only the new schema afterward.
- Analytics remain additive and local-first; new events/fields measure Field/Surface placement, traversal, expiry, conversion, interruption, collision, free movement, Chain, and Combust.
- `spec/card_balance_heuristic.md` and `tools/card_heuristic.py` are rewritten for pattern coverage, setup burden, traversal, control, and payoff.
- Grimoire/tutorial/icon registries remove retired player-facing concepts and teach one board decision at a time.

## Visual direction

- Reuse current actor, card, equipment, relic, Blink, Illusion, Umbra, Light, and UI art when the identity remains truthful.
- Use the built-in image-generation workflow for final raster Corruption and new Surface assets/icons, then copy selected outputs into the project.
- Corruption: violet-black organic seep/cracking distinct from global billowing Umbra, readable beneath routes and actors.
- Radiance: warm gold-white emanation using the established soft Light language, without hard construction outlines.
- Surfaces: grounded physical textures with distinct silhouettes/patterns at board scale; hue is secondary.
- Composite previews use route material/arrows, red damage contours, violet corruption hatching, Surface silhouettes, and cancelled-suffix fading without covering actor silhouettes.
- Every new icon-bearing concept owns a distinct purpose-built icon and passes the icon identity audit plus native-size contact-sheet review.

## Implementation phases

1. **Inventory/specification:** authoritative rules, audit tool, migration lists, baseline proof.
2. **Foundation:** pure pattern and tile-rule helpers, state schema/migration, deterministic engine tests.
3. **Player loop:** free Move 2, one-selection patterns, collision/traversal, fallback removal, card UI/previews.
4. **Enemy loop:** committed plans, short-circuiting, setup movement, support geometry, all enemy/boss migration.
5. **Content:** all cards, equipment, relics, skills, upgrades, rewards, rooms, fixtures, analytics, heuristic.
6. **Visuals/tutorial:** image-generated final assets, rendering, icons, animation, tooltips, Grimoire/tutorial, accessibility.
7. **Verification:** strict inventory audit, full tests, visual probes, headless playtests, balance pass, peer review, inspection fixtures.

No phase is the final deliverable by itself. The task remains active until every phase and the high-risk proof contract are complete.
