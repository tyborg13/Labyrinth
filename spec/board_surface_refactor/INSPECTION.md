# Playing the surface refactor

The task-local fixture opens before any action. It uses a separate save, three enemies, seven relevant cards, four reworked relics, and a legal level-10 skill selection including Prismatic Instinct and Confluence. Regenerating it restores the same starting choice.

Useful things to inspect:

- Push the Crawler toward the existing Ice, then use Frostbolt. Entry activates Chill; a successful Freeze consumes the old supporting Ice. Frostbolt then paints fresh Ice, which cannot Chill the Frozen unit. Placing new Ice under an unmoving unit would not activate it.
- Aim Spark Dart at the Shale Bloomer standing on Electrified ground. The connected three-tile patch reaches the other occupied endpoint. Compare Chain Bolt: it can also make ordinary enemy hops and use separate relay tiles. Used conductors disappear.
- Cinder Bloom creates territory; Rekindle Edge can consume Fire for a shared blast. Its preview includes friendly danger. Rubble remains after elemental consumption. Stormcoal makes Fire available as a consumable conductor, and the optional relic techniques appear while aiming their relevant cards.
- Open Abilities to place a chosen surface with Prismatic Instinct or relocate one layer with Confluence. Try cancellation and mouse/controller targeting. The destination placement itself causes no contact damage or Chill.

The game rules, rewards, enemy responses and saved state are real; the opening loadout and sparse board arrangement are a deliberate inspection fixture. Normal new runs use the complete reworked content pools.

## Regenerate and launch

Run from the task worktree (use its absolute path in a handoff). This command recreates the opening, verifies persisted state in a second Godot process, then launches its isolated game. Select Continue if the title screen appears.

```sh
python3 tools/inspection_fixture.py --task-id board-surface-refactor --run-id board-surface-refactor-inspection --launch --scenario combat --seed 90626 --level 10 --skills quick_wits,discerning_eye,measured_breath,ghost_stride,rehearsed_escape,makeshift_tool,carry_the_guard,prismatic_instinct,confluence --hand updraft,cinder_bloom,frostbolt,chain_bolt,quarry_step,rekindle_edge,spark_dart --player-position 2:4 --enemy-types crawler,bile_bloomer,acolyte --enemy-positions 4:4,6:4,7:3 --surfaces fire@4:4,rubble@4:4,ice@5:4,electrified@6:4,electrified@7:4,electrified@7:3 --relics coalheart_crucible,updraft_bottle,briar_winch,basalt_calendar --umbra-stage clear --summary 'Shared ground, delayed Freeze, connected Lightning, consuming payoffs and terrain-shaping abilities.' --manifest output/board-surface-refactor/inspection-fixture.json
```
