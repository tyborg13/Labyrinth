# Card mechanics, wave 4 family B

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
  Manhattan `radius`. An enemy standing on the center has no line away from or
  toward it, so the area skips it (no movement, collision or Expose).
- Each moves along its own default straight line away from (push) or toward
  (pull) the center, the center acting as the force source. There is no Rotate
  and no `force_direction`. Pushes resolve farthest first, pulls nearest first,
  ties by enemy id ("Several targets at once" in the forced-movement spec).
  Collisions, surfaces and traps apply; a pull that reaches the center (or the
  enemy on it), or draws level with it, stops without colliding. Deaths flush once after the area.
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

## Area Push origin

Squall uses `force_mode: "from_player"`. The selected tile centers the damage pattern.
Direct hits resolve farthest from the hero first. All hits, including Chain hops,
push away from the hero. Chain forecasts use the resulting position to find the
next hop. An explicit `force_mode: "from_center"` measures Push from the
pattern center except for the enemy whose footprint covers that tile, which
is pushed away from the attacker.

## Swap (`swap`)

`{"type": "swap", "range": R, "targets": ["enemy", "illusion"]}` (Changing
Winds). Target: a visible one-tile enemy (2x2 bodies are illegal) or one of the
hero's illusions within range, with line of sight beyond range 1. The two
exchange tiles; the hero arrives first (loot, traps, surfaces), then the other.
Not forced movement: nothing collides and Anchored does not stop it. Counts as
tiles moved (Manhattan distance). Event `swap {from, to, other_kind, other_key}`.
Both swaps (this and Empty Husk's `illusion_swap`) relocate the hero by its own
action, so Immobilize and Rooted forbid them exactly as they forbid Move and
Blink.

## Forced-movement trail (`trail_surface` on Push/Pull)

Fan the Flames: after the target is pushed or pulled, the surface is placed on
every footprint tile of every anchor it entered, including the final one, never
its start. Placement happens after movement, so the target does not take entry
damage from its own trail but stands on it.

## Sleet Squall ordering and `previous_target`

The Push resolves before the Ice hit. Arrival on Ice applies Expose 2 and the
hit Staggers a target on Ice by 6. A follow-up attack with `target: previous_target`
follows a living enemy at the new anchor plus the original footprint offset.
Burst, surface and consume follow-ups keep the impact tile, as on Cinderline Tempo.

## Self flags (`self_flag`)

`{"type": "self_flag", "flag": F}`; stored in combat `self_flags`
`{flag: {expires, sources}}` and shown as player status badges.

| Flag | Card | Effect | Ends |
| --- | --- | --- | --- |
| `ice_skate` | Skate | A step onto Ice costs 0 Movement (the same path search as Winter's Spur). Free steps remain available at 0 shared Movement, including after the last card play. Ice contact applies no Expose while Skate is active. Ice is excluded from pathing hazards. | `finish_player_activation` |
| `no_move` | Rooted Stance, Shield Wall | Move, Blink and both swaps cannot resolve, including independent movement; the movement meter dims with a Rooted reason; Move/Blink/Swap cards become unplayable. | `finish_player_activation` |
| `anchored` | Windbreak | Forced movement against the hero has 0 distance and never collides (Air traps and enemy shoves included). The hero can still block others. | start of the next player turn |
| `fire_immune_turn` | Cinder Trail | Fire tile damage to the hero is 0 and Fire is not a pathing hazard. | `finish_player_activation` |

## Cleanse (`cleanse`)

Unpick and Smelling Salts use `{"type": "cleanse", "statuses": [...]}` to remove
Immobilize and Shock from the hero, including the current turn restrictions.
A cleanse that lists Shock may resolve while Shocked. The event is
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
  the move-then-attack plan share the same search. U7 movement relics use
  `SurfaceVarietyRules.navigation` with the straight-line constraint; otherwise
  they use `ManeuverRules.straight_line_navigation`.
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

## Targeted Stagger (`stagger`)

The Time 3 card uses `{"type": "stagger", "range": 3, "stagger": 6}`.
`ManeuverRules.stagger_targets` accepts visible enemies, including dragons,
with a footprint tile in range and line of sight beyond range 1.
The Stagger resolves through `CombatEngine._apply_card_stagger` (the ordinary
Stagger rule: the next queued turn moves later, dragons take half, at most 6
per enemy between its turns, including other Stagger sources). The card row shows the Stagger amount and range.

## Crystal Mantle for the hero (`mantle`)

`{"type": "mantle", "amount": N}`: N layers in `player.frost_armor`, Iskaldra's
field. A direct hit (`_damage_player` with the direct multiplier and cause
`enemy_attack` or `direct_attack`) breaks one layer before Block and deals no
damage (event `crystal_mantle_broken`, actor `player`). Fire, collisions,
traps, fatigue and health costs bypass Crystal Mantle. Layers last until broken or the
combat ends. `_actor_target_losses` reports `mantle_loss`, so a fully absorbed
enemy attack still builds its step and animates; the floating text reads
`Mantle N → M`. The board shows the shared Crystal Mantle badge.

## UI, icons and grimoire

Icons (`ActionIcons.ACTION_ICON_ALIASES`): `force_area` → Push (Pull when it
pulls), `mantle` → Crystal Mantle, `convert_block_to_stoneskin` → Stoneskin,
and the purpose-built `swap` and `cleanse`. `self_flag` resolves per
flag through `ActionIcons.SELF_FLAG_ICON_KEYS` (Skate, Anchored, Fireproof;
Rooted uses the exact Immobilize icon), shared by card rows, action steps (named
by the flag label) and the player's stance badges. See the [icon identity policy](icon_identity_policy.md).
Grimoire: `combat:area_force`, `combat:swap`, `combat:stances` (Anchored icon),
`combat:cleanse` and `combat:crystal_armor`.
Card role emblems: Swap and Skate/Fireproof are mobility; Rooted/Anchored,
Crystal Mantle and Shrug Off are block. Targeted Stagger and area forces follow the
attack range rule; Cleanse chooses block only when nothing else on the card has
a role. Gale Ward authors `role_emblem: "block"`: its damage-free shove is a rider
on the Ward's Block, like its Fire, Ice, Rubble and Electrified siblings.

## Analytics

Additive `card_played` fields (RunScene and `tools/headless_playtest.gd`,
`ManeuverRules.analytics_fields`): `self_flags_gained`, `statuses_cleansed`,
`mantle_gained`, `swapped_with` (`enemy`/`illusion`/null),
`force_area_displaced`. Surface events (`force_area`, `swap`,
`statuses_cleansed`, `mantle_gained`, player `crystal_mantle_broken`) use the
existing append-only `surface_event` stream.

## Heuristic

See "Wave-4 movement, forces, flags, Stagger and Mantle" in the
[card balance heuristic](card_balance_heuristic.md).

## Deferred

- Area forces animate as a single result beat (collision flash and damage
  floats), not per-enemy slides.

## Relic movement search (R1 fixes)

U7 uses a uniform-cost search over tile, Beacon refunds used, and incoming
cardinal direction only for straight Move or Winter's Spur. Predecessor labels
preserve the existing preference for fewer hazards, more pickups, then lower
movement cost. Light jump neighbours, step costs and hazard/pickup scores are
computed once per search. Glassway illusion tiles are allowed endpoints in that
same search, never intermediate steps, including straight Move and Ice movement.
Beacon refunds at most the positive cost of its landing step; a free Skate step
uses no refund. Forecast and commit use the same clamp, and independent movement
remaining is capped at capacity.
