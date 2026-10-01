# Card mechanics, wave 4 family B: movement, forces, self flags, Petrify, Mantle

Owning spec for the wave-4 family B mechanics of the
[card pool overhaul](card_pool_overhaul/README.md). Data shapes:
`spec/card_pool_overhaul/card_defs.py`. Rules code: `scripts/maneuver_rules.gd`
(`ManeuverRules`) with one-line hooks in `CombatEngine`, `GuardianRelicRules`
(Skate step cost), `CombatBoardView` (badges) and `RunScene` (presentation).
Tests: `tests/suites/maneuver_suite.gd` (wrapper `tests/maneuver_test.gd`),
`tests/test_card_heuristic_maneuver.py`.

Every displacement uses the engine's straight-line mover with collision
(`_force_move_enemy_from` / `_force_move_actor`, see
[forced movement](forced_movement.md)); every arrival uses
`surface_actor_arrival`. Hover forecasts run the same resolver on a copy, so
preview equals commit.

## Area forces (`force_area`)

`{"type": "force_area", "center": "self" | "target", "range": R?, "radius": r,
"push": n | "pull": n, "expose": n?, "consume_center": S?}` (Gale Ward, Dust
Devil, Vortex, Cyclone Seal, Unsealed Gale, Bottled Gale).

- Center: the hero's tile, or a chosen tile within `range` that is visible,
  passable and in line of sight (empty floor is fine). With `consume_center`
  the tile must hold that surface, which is removed first (event
  `surface_removed`, reason `consumed`).
- Affected: every live enemy whose footprint tile nearest the center is within
  Manhattan `radius`. A pull skips an enemy standing on its center.
- Each moves along its own default straight line away from (push) or toward
  (pull) the center, the center acting as the force source. There is no Rotate
  and no `force_direction`. Pushes resolve farthest first, pulls nearest first,
  ties by enemy id ("Several targets at once" in the forced-movement spec).
  Collisions, surfaces and traps apply; a pull that reaches the center (or the
  enemy on it) stops without colliding. Deaths flush once after the area.
- `expose` applies to each affected survivor (status relics fire).
- Legality: a tile-centered area needs at least one visible enemy that would
  move, collide or be Exposed. A self-centered area with no such enemy cannot
  resolve, so a card made only of it (Bottled Gale) is unplayable then; Gale
  Ward still plays its Block.
- The chosen center becomes `last_action_target`, so Cyclone Seal's
  `aoe ... target: previous_target` blast is centered there (a range-0 area
  with `previous_target` centers on that tile, not on the hero).
- Board event `force_area` `{center, radius, force, amount, expose, consumed,
  enemies: [{enemy_id, from, to}], source}`.
- Preview: the hover forecast draws each displaced enemy's straight path, a
  ghost at its landing tile and the collision marker (`_append_forced_displacement_preview`).
  A targetless card in its confirmation stage shows its resolved board plus
  the same paths and collision markers (no ghosts).

## Squall (`force_mode: "from_center"`)

On an AOE with `push`: each enemy in the pattern is pushed away from the
pattern's center tile; the enemy whose footprint covers the center is pushed
away from the attacker. Hits (and their pushes) resolve farthest from the
center first.

## Swap (`swap`)

`{"type": "swap", "range": R, "targets": ["enemy", "illusion"]}` (Changing
Winds). Target: a visible one-tile enemy (2x2 bodies are illegal) or one of the
hero's illusions within range, with line of sight beyond range 1. The two
exchange tiles; the hero arrives first (loot, traps, surfaces), then the other.
Not forced movement: nothing collides and Anchored does not stop it. Counts as
tiles moved (Manhattan distance). Event `swap {from, to, other_kind, other_key}`.

## Forced-movement trail (`trail_surface` on Push/Pull)

Fan the Flames: after the target is pushed or pulled, the surface is placed on
every footprint tile of every anchor it entered, including the final one, never
its start. Placement happens after movement, so the target does not take entry
damage from its own trail but stands on it.

## Sleet Squall ordering and `previous_target`

Card actions resolve in order: the Push fully resolves (arrival on Ice Chills)
before the Ice hit, which then Freezes. A follow-up attack at
`target: previous_target` follows the enemy that was targeted (its new anchor
plus the original footprint offset) when that enemy is alive; Detonate,
surface and consume follow-ups keep the impact tile (Cinderline Tempo).

## Self flags (`self_flag`)

`{"type": "self_flag", "flag": F}`; stored in combat `self_flags`
`{flag: {expires, sources}}` and shown as player status badges.

| Flag | Card | Effect | Ends |
| --- | --- | --- | --- |
| `ice_skate` | Skate | A step onto Ice costs 0 movement (player navigation uses the Ice-aware search, as with Winter's Spur); entering Ice does not Chill; Ice is not a pathing hazard. | `finish_player_activation` |
| `no_move` | Rooted Stance, Shield Wall | Move and Blink cannot resolve, including independent movement; the movement meter dims with a Rooted reason; Move/Blink cards become unplayable. | `finish_player_activation` |
| `anchored` | Windbreak | Forced movement against the hero has 0 distance and never collides (Air traps and enemy shoves included). The hero can still block others. | start of the next player turn |
| `fire_immune_turn` | Cinder Trail | Fire tile damage to the hero is 0 and Fire is not a pathing hazard. | `finish_player_activation` |

## Cleanse (`cleanse`)

`{"type": "cleanse", "statuses": [...]}` (Unpick, Smelling Salts). Removes
from the hero: `bleed`, `immobilize` (the stored status and this turn's
restriction), `chilled`, `shock` (stored Shock and this turn's restriction). A
cleanse that lists Shock may resolve while Shocked. Removing Chilled on Ice
keeps the hero unchilled until a later Ice entry or turn start. Event
`statuses_cleansed {statuses}`.

## Block to Stoneskin (`convert_block_to_stoneskin`)

Shrug Off: all current Block becomes Stoneskin (Stoneskin relics trigger).

## Move riders

- `trail_surface`: the surface on each tile the hero left (not the destination).
- `origin_surface`: the surface on the tile the hero started this Move on, if it moved.
- `block_per_tile`: Block for each tile actually traversed.
- `if_started_on_surface {surface, rewards}`: rewards if the hero started this
  activation on that surface (`activation_start` is recorded after the
  turn-start resolution and at combat creation).
- `straight_line`: destinations on a clear cardinal line from the hero (known
  enemies and terrain block; Rubble/Ice costs still apply). Targets, paths and
  the move-then-attack plan share `ManeuverRules.straight_line_navigation`.
- `trail_light {radius, duration}`: Light on each tile entered, via the
  Pilgrim Boots / Sunpath path-light machinery (`illuminate_position_mode: path`).

## Blink riders

- `destination_requires_light`: the destination must be in Light.
- `destination_adjacent_to: ["enemy", "terrain"]`: the destination must be
  orthogonally next to a visible enemy footprint tile or live terrain.
- `illusion_at_origin: H`: an H-health illusion on the tile left
  (`_create_illusion`, as Afterimage and Glassway Compass).
- `if_no_adjacent_enemies: [rewards]`: rewards when no visible enemy is
  orthogonally next to the hero after the Blink.

## Petrify (`petrify`)

`{"type": "petrify", "range": R, "block": B}`. Target: a visible enemy (any
footprint tile in range, line of sight beyond 1); dragons are illegal. The enemy
gains B Block and `petrify: 1`. Its next activation start keeps its Block (the
ordinary reset is skipped), consumes Petrify (and Freeze, if also Frozen), takes
no action and reschedules after its normal intent Time (Freeze keeps its
time-cost-0 return). The Block therefore lasts through the player's following
turn and clears at the enemy's next real activation. It is not Freeze: no damage
multiplier, no Chill, and Freeze immunity does not apply. Threat previews treat
it like Freeze. UI: enemy badge, turn-order `Skips` marker and tooltip line,
status step `Petrified`. Event `petrified {enemy_id, block}`.

## Crystal Mantle for the hero (`mantle`)

`{"type": "mantle", "amount": N}`: N layers in `player.frost_armor`, Iskaldra's
field. A direct hit (`_damage_player` with the direct multiplier and cause
`enemy_attack` or `direct_attack`) breaks one layer before Block and deals no
damage (event `crystal_mantle_broken`, actor `player`). Fire, Bleed, collisions,
traps, fatigue and health costs ignore it. Layers last until broken or the
combat ends. `_actor_target_losses` reports `mantle_loss`, so a fully absorbed
enemy attack still builds its step and animates; the floating text reads
`Mantle N → M`. The board shows the shared Crystal Mantle badge.

## UI, icons and grimoire

Icons (`ActionIcons.ACTION_ICON_ALIASES`): `force_area` → Push (Pull when it
pulls), `mantle` → Crystal Mantle, `convert_block_to_stoneskin` → Stoneskin,
and the purpose-built `swap`, `cleanse` and `petrify`. `self_flag` resolves per
flag through `ActionIcons.SELF_FLAG_ICON_KEYS` (Skate, Anchored, Fireproof;
Rooted uses the exact Immobilize icon), shared by card rows, action steps (named
by the flag label) and the player's stance badges. The enemy Petrify badge uses
the Petrify icon. See the [icon identity policy](icon_identity_policy.md).
Grimoire: `combat:area_force`, `combat:swap`, `combat:stances` (Anchored icon),
`combat:cleanse`, `combat:petrify`, and the extended `combat:crystal_armor`.
Card role emblems: Swap and Skate/Fireproof are mobility; Rooted/Anchored,
Crystal Mantle and Shrug Off are block; Petrify and area forces follow the
attack range rule; Cleanse chooses block only when nothing else on the card has
a role. Gale Ward authors `role_emblem: "block"`: its damage-free shove is a rider
on the Ward's Block, like its Fire, Ice, Rubble and Electrified siblings.

## Analytics

Additive `card_played` fields (RunScene and `tools/headless_playtest.gd`,
`ManeuverRules.analytics_fields`): `self_flags_gained`, `statuses_cleansed`,
`mantle_gained`, `petrified_enemy_ids`, `swapped_with` (`enemy`/`illusion`/null),
`force_area_displaced`. New surface events (`force_area`, `swap`, `petrified`,
`statuses_cleansed`, `mantle_gained`, player `crystal_mantle_broken`) use the
existing append-only `surface_event` stream.

## Heuristic

See "Wave-4 movement, forces, flags, Petrify and Mantle" in the
[card balance heuristic](card_balance_heuristic.md).

## Deferred

- Area forces animate as a single result beat (collision flash and damage
  floats), not per-enemy slides.
