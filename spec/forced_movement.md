# Forced movement

Push and Pull are one law for every source: player cards and keyword riders,
enemy intents, guardian and dragon attacks, Chain hops, Detonate riders, Air
traps and Galehook Talon groups. Code: `CombatEngine._resolved_force_direction`,
`_force_move_actor` and `_apply_force_collision`; Galehook groups in
`GuardianRelicRules.force_group`.

## Line

- A Push or Pull moves its target in one cardinal direction for its full
  distance. It never turns, slides sideways around an obstacle or pathfinds.
- Push travels away from the source, Pull toward it. The source is the player
  tile (or the action's `_origin_tile`, or a Chain hop's origin). An enemy
  source uses its footprint tile nearest the target.
- `d = (target footprint tile nearest the source) - source`. An aligned `d`
  gives one direction. Otherwise both axis directions are candidates; the
  default is the larger component. An exact diagonal defaults to the line with
  more free travel before a blocker, then horizontal.
- `_allow_sideways_force` (Quarry Winch) makes all four directions candidates,
  default first.
- Enemy force against the player takes the candidate that hurts the player
  more (collision plus hazard damage along the line, measured by the real
  mover on a copy); ties keep the default. Committed dragon directional shapes
  keep their authored `force_direction`.
- The chosen line is stored as the action's `force_direction`. Resolution uses
  it when it is a candidate, otherwise the default. A blocked line is still a
  legal choice: it collides.

## Collision

- Before each step: a wall, pillar, door or the board edge; live terrain
  (crates, outcrops, dragon spires, raised cover); or any character footprint
  (enemy, player, illusion) stops the line.
- Lost tiles = distance - tiles moved. The target and each distinct blocker
  take `2 x lost tiles`. Walls and the board edge take nothing.
- A Pull that reaches its own source (any tile of the source actor) simply
  stops; no collision.
- Collision damage is non-direct, like Fire ground: Block and Stoneskin absorb
  it; Chilled, Frozen and Expose do not add to it (Expose is not consumed),
  Crystal Mantle does not break and no on-hit riders apply.
- The damage keeps the card's damage context (`source_kind` becomes
  `force_collision`), so a collision kill is that card's kill (+1 card play,
  death rewards). Deaths use the surface death batch.
- Surfaces and traps never block: the target enters them and they trigger. A
  target defeated on the way stops and does not collide.
- Illusions are never displaced by Push/Pull, but they block and take
  collision damage. A player pushed into their own illusion collides with it.
- Galehook Talon moves its line together and stops at the first obstruction;
  only the front member and its blocker take collision damage.
- Every collision records a `force_collision` board event: `tile` (the
  target's contact tile), `blocked_tile`, `direction`, target actor
  kind/key, `blocker_kind`/`blocker_key`, per-party `damage`, `blockers` and
  `total_damage`.

## Targeting

A Push/Pull target is legal when it is a visible enemy within range (and line
of sight past range 1) and the action does something: damage above zero, at
least one tile of travel, or a collision.

## Preview and Rotate contract

- `force_direction_options_for_player_action(state, action, target)` returns
  the candidates, default first. The run scene keeps an aim index for the
  last hovered legal target (reset when a different target is hovered or the
  card changes) and writes that line to both the hover preview action and the
  committed action, so forecast and commit agree.
- With two or more candidates, the action-context Rotate button, keyboard
  left/right and controller LB/RB cycle the aim. There is no separate
  direction step.
- The hover preview draws each displaced enemy's straight path and a ghost at
  its landing tile, plus the collision icon at the contact edge. Collision
  damage on both parties appears through the ordinary simulated damage
  preview. At commit the same event drives the board feedback flash.

## Rationale

Consistency: collision is universal, not a keyword. Every stopped line is
worth damage, so relics that add distance (Tailwind Fletching, Anchor Chain,
including keyword Push/Pull riders) add damage. Enemy force obeys the same
rules against the player, and a straight line is always readable from the
board before commit.
