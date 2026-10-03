# Card mechanics, wave 4 family C: illusions and terrain

Owning spec for the illusion and terrain mechanics of the [card pool overhaul](card_pool_overhaul/README.md)
(cards: Ice Sculpture, Ball Lightning, Reflected Threat, Mirror Feint, Hall of Mirrors,
Doppelganger, Empty Husk, Shattered Reflection, Refraction, Rockburst, Worldbreak, Powder
Keg, Worldspine, Earthen Rampart; exact data in `spec/card_pool_overhaul/card_defs.py`).
Rules code: `scripts/illusion_card_rules.gd`, `scripts/terrain_card_rules.gd`, with small
hooks in `CombatEngine` (targeting, `_apply_player_action`, `_resolve_board_attack`,
`_create_illusion`, `_damage_terrain`, `outcrop_tiles_for_player_action`,
`prepare_next_player_turn`), `CombatTerrainRules.raise_outcrop` (optional field overrides),
`RunScene` (hover, prompts, hand chips, Rotate, animation), `CombatBoardView` (terrain art,
illusion badges) and `chain_attack_feedback.gd` (Refraction beams).
Tests: `tests/suites/illusion_terrain_suite.gd` (wrapper `tests/illusion_terrain_test.gd`);
real-renderer proof `tests/illusion_terrain_probe.gd` (keg, Worldspine cage, trait badges,
Mirror Feint ghost, Doppelganger arc, Rockburst hover) via `tools/visual_probe_runner.py`.

## Illusion creation options (`illusion` action)

An illusion keeps its creation traits on its own state entry (`on_damaged`, `reflect`,
`ranged_origin`, `source_card_id`, `source_name`); they last while it lives and show as
board badges with the card name.

- `surface_ring: S` — after creation, S on each orthogonal neighbor of the illusion that can
  hold ground and has no hero, enemy, illusion or terrain on it.
- `on_damaged: {damage, element, shock}` — when an enemy attack (`_resolve_board_attack`,
  melee/ranged/area) deals damage to the illusion, the attacker takes `damage` as
  non-direct damage (Block and Stoneskin absorb; no Chill/Freeze, Crystal Mantle or Expose)
  and the riders (Shock). Once per illusion per enemy attack, resolved after the attack's
  hits inside its damage batch (beside Retaliate). The element is recorded for presentation.
- `reflect: true` — same trigger; the attacker takes the damage the illusion was dealt after
  its own modifiers (Freeze/Chill on the illusion, Witchglass Carapace's cap), not clamped to
  the illusion's remaining health.
- Retort context `{actor_kind: player, source_kind: illusion_retort, player_card: false,
  causal_owner: player}`: kills pay embers and death relics but grant no card play.
- `place: "adjacent_to_enemy"` + `expose_adjacent: N` — the decision is a visible enemy with
  any footprint tile within `range` (every footprint tile is clickable). The illusion
  appears on the free, visible tile orthogonally next to that footprint nearest the hero
  (ties: lower y, then lower x); an enemy with no free neighbor is not a legal target. The
  enemy then gains Expose N. Hover shows the illusion ghost on that tile.
- `place: "ring_around_self"` — targetless; one illusion of the given health on each free
  orthogonal neighbor of the hero (up to four).
- `ranged_origin: true` (Doppelganger) — while it lives, a hero `ranged` action's targets are
  the union of those legal (range + line of sight, from the visible origin tile) from the
  hero and from each ranged-origin illusion. `action_with_automatic_origin` picks the origin
  that makes the clicked target legal: the hero's tile first, then illusions by id; the
  chosen illusion is written as `_origin_tile` (+ `_ranged_origin_illusion`), so hover arrows,
  the attack animation, push direction and range relays measure from it. Chain and conduction
  start from the hit target as usual. Worldroot's remote origin keeps its own rule. Each shot
  from an illusion records `illusion_ranged_origin`.

## Illusion actions

- `{"type": "illusion_swap", "range": R, "transfer_block": bool}` (Empty Husk) — click one of
  your illusions within R. The hero and the illusion trade tiles; the illusion arrives first,
  then the hero (both trigger ground and traps; the hero collects loot). `transfer_block`
  moves all current Block onto the illusion as **extra health** (`hp` and `max_hp` grow by
  that much; the hero's Block becomes 0) — the husk then soaks those hits whatever their
  timing. Immobilize and Rooted forbid the swap, as they forbid Changing Winds' `swap`; it is not counted as tiles moved and fires no Blink
  relics. Event `illusion_swapped`.
- `{"type": "destroy_illusion", "range": R, "damage": N, "illuminate_radius": r,
  "illuminate_duration": d}` (Shattered Reflection) — click one of your illusions within R.
  It is destroyed through `_damage_illusion` (actor_death, Living Shadow, Afterglow, Umbra
  hooks fire normally), then a card blast deals N to each enemy orthogonally next to its tile
  (footprint-aware, each enemy once), then radius-r Light for d turns on that tile. Event
  `illusion_shattered`.
- `also_hits_near_illusions: true` on `ranged` (Refraction) — after the attack's planned hits
  (target, Chain, conduction), one extra hit with the same per-hit rules on each other visible
  enemy orthogonally next to any of your illusions; each enemy at most once and never again if
  already hit. The trace carries one `refraction` beam per extra hit, drawn from the illusion.

### Card blasts

Shattered Reflection, Rockburst and Worldbreak deal their damage through
`IllusionCardRules.blast_action`: an `aoe` with supplied impact tiles resolved by
`_resolve_board_attack`. Ordinary attack bonuses (first-attack relics, conditional relic
bonuses), Expose and target modifiers apply and the first attack is marked used; the blast
hits enemies only (no terrain damage or trap triggers on its tiles), never conducts, and
does not take or spend next-attack buffs (the outer action is not an attack type). The hand
chip and hover use the same derived action (`blast_action_for_player_action`).

## Terrain

- `{"type": "burst_terrain", "range": R, "damage": N, "surface"?, "surface_pattern"?}`
  (Rockburst) — click a live terrain piece (crate, box, outcrop, keg, spire) within R and line
  of sight (the target itself never blocks). It is destroyed (its own destroy effects run: an
  outcrop leaves Rubble, a keg bursts), then the blast hits each enemy next to it, then the
  card's surface rider is placed with its pattern around the tile. Event `terrain_shattered`.
- Worldbreak variant `owned_outcrop_only: true, line_damage: N, line_length: L, stagger: S`
  (range 1) — only an adjacent crag outcrop or Worldspine the hero raised. The blast hits each
  enemy on the L tiles beyond it in the direction hero → outcrop (stopping at a wall) and
  Staggers them S (wave-2 Stagger).
- Outcrop `kind: "powder_keg", burst_damage: N` — a keg (terrain kind `powder_keg`, blocks
  movement, not sight, no Rubble). When anything destroys it (`_damage_terrain` reaching 0),
  it deals N, non-direct, to every actor (hero, illusions, enemies; footprint-aware, once each)
  on its tile and orthogonal neighbors and N to every terrain piece there, so kegs chain. A
  hero-placed keg sets `causal_owner: player`; whether a kill refunds a card play follows the
  triggering context (`player_card`), like any other damage. Event `powder_keg_burst`.
- Outcrop `kind: "worldspine", pattern: ADJ, around_target: true, pulse_damage: N` — the
  target is any visible, in-sight floor tile within range except the hero's; spires (terrain
  kind `worldspine`, Tharokh's spire art, block movement not sight, Rubble on destroy) rise on
  each empty orthogonal neighbor. Route preservation applies to every spire, except that the
  caged center may be sealed when it is not a chokepoint (its open neighbors stay connected
  without it, or it is a dead end); a chokepoint center stays open because the spire that
  would seal it is skipped. At the start of each hero turn (after Rites) each enemy next to at
  least one hero Worldspine takes the largest adjacent pulse once, non-direct, player-credited
  without a card play. Event `worldspine_pulse`.
- Patterned outcrops with `rotate: true` (Earthen Rampart) rotate with the shared area aim:
  `RunScene.AIM_ROTATABLE_ACTION_TYPES` includes `outcrop`, so the Rotate command, keys and
  sticks orient the pending line, hover shows every raised tile, and the click commits that
  orientation. Empower's `pattern` override (LINE5) uses the same path.

## Presentation, icons, Grimoire

- Icons (`ActionIconLibrary.ACTION_ICON_ALIASES`): `burst_terrain` → `terrain_burst`;
  purpose-built `illusion_swap` → `illusion_swap` (Swap Illusion) and `destroy_illusion` →
  `shatter_illusion` (Shatter Illusion), each leading its card row. See
  [icon identity policy](icon_identity_policy.md).
- Card role emblems: powder kegs and Worldspines are offensive outcrops and follow the
  attack range rule; crag outcrops stay block; Empty Husk is illusion. Hall of Mirrors
  authors `role_emblem: "illusion"` over its Block; Mirror Feint, Reflected Threat and
  Empty Husk are pure illusion cards since wave 4 and need no override.
- Powder kegs draw `assets/art/tiles/powder_keg.png` (the wooden box's 128px framing) with
  a soft warning glow on its lit fuse, and break apart with the wooden box destruction
  sheet (`TERRAIN_DESTRUCTION_SHEET_LAYOUTS.powder_keg`); the burst's fire impact is
  unchanged.
- Grimoire: `illusion_swap`, `destroy_illusion` → `keyword:illusion`; `burst_terrain` →
  `combat:outcrops` (bodies cover the new options); `expose_adjacent` → `keyword:expose`;
  `surface_ring` teaches its surface.
- Retorts add a `status_damage` enemy-turn step labelled with the illusion's card name.

## Analytics

All outcomes use the append-only `surface_event` stream; see [analytics](analytics.md).

## Illusion and Lightning relics (relic pool overhaul U6)

`scripts/illusion_relic_rules.gd` owns effect-type hooks for death damage, an
attack destroyer's Stagger/Expose, single-target Push/Pull of allied illusions,
Move/Blink endpoint exchange, first attack-card echoes, virtual Lightning
construct relays, and Chain rebound. All use the engine's damage, arrival,
straight-line force and attack planning paths. Area forces keep their original
rules. With Glassway active, illusion tiles are terminal Move destinations;
independent endpoint routes never traverse another illusion. A Move that ends on
an illusion is a teleport trade. A second navigation search prices each
illusion endpoint by its cheapest route, ignoring hazards and pickups and
counting no Light refunds, and the commit spends exactly that. The trade enters
only the landing tile: the tiles between give no hazard, loot, Vault Stagger,
refund or hidden-body interruption. The illusion lands on the Move's origin,
per-tile rewards (Catch the Wind, long-move relics) count the Manhattan distance
like a Blink, and the board plays one exchange Blink. Ordinary movement without
Glassway retains the existing endpoint-dispel behavior.

Mirror Triptych records the first attack action while the card resolves and
executes its echoes after all card actions. `illusion_relic_pending_echo` is the
saved action and `turn_flags.illusion_relic_attack_used` claims the first attack
card even when no illusion can echo. A new hero turn resets that flag with the
ordinary turn flags. Preview resolves known automatic follow-ups before echoes;
it cannot predict an additional targeting decision the player has not made.
Attack classification follows the existing card rules: pure zero-damage forces
do not claim the first attack, while Detonate does. Detonate echoes require legal
fuel at their new target but repeat only the damage footprint, leaving that fuel.
Echo origins are ordered by hero distance then illusion id, targets by footprint
distance then enemy id. Each actual echo loses one health. Damage is half the
attack's computed amount before defenses, rounded down, including target
Expose/Chill/Freeze; target defenses absorb normally. Only Push/Pull repeat as
riders, and no card ground, status, light, health-cost, or resource actions repeat.
Death relics still apply when echo wear destroys an illusion.

Storm Crown stores each forward enemy hit's computed damage before defenses,
then halves that amount once for the return. Return hits do not recalculate
Expose, Chill, Freeze or relic damage bonuses, consume Expose, add Chain hops,
conduct, or reapply riders. They remain credited to the original card. Copper
creates a geometry-only conduction view; it never paints Electrified on the
constructs or changes sight/collision geometry. Virtual relays do not consume the
real ground beneath them. Enemy Lightning and non-Lightning forces are unchanged.

Presentation reuses target curves, normal attack effects, Chain hop traces,
`illusion_preview` ghosts, and force collision markers. The marker for a Hollow
Puppet enemy collision displays remaining illusion health; normal collision
damage is replaced for both parties. Illusion destruction still runs its ordinary
hooks, including Mirror Shard.
