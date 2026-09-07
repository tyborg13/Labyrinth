# Playing the surface refactor

The task-local fixture opens before any action. It uses a separate save, three enemies, seven relevant cards, four reworked relics, and a legal level-10 skill selection including Prismatic Instinct and Confluence. Regenerating it restores the same starting choice.

Useful things to inspect:

- Hover ground, keywords and relics: descriptions are short reminders. Check Wildfire Halo, Firebrand Volley and conditional cards in the Grimoire; drag equipment/items in the loadout to inspect the fixed held labels.
- Rubble costs extra movement to leave. Fire deals 2 on entry and 3 at turn start; Chilled adds 2 attack damage and Frozen triples attack damage.

- Push the Crawler toward the existing Ice, then use Frostbolt. Entry activates Chill; a successful Freeze consumes the old supporting Ice. Frostbolt then paints fresh Ice, which cannot Chill the Frozen unit. Placing new Ice under an unmoving unit would not activate it.
- Aim Spark Dart at the Shale Bloomer standing on Electrified ground. The connected three-tile patch reaches the other occupied endpoint. Compare Chain Bolt: it can also make ordinary enemy hops and use separate relay tiles. Ordinary Electrified remains for another attack; Stormcoal Fire is consumed.
- Cinder Bloom creates territory; Rekindle Edge can consume Fire for a shared blast. Its preview includes friendly danger. Rubble remains after elemental consumption. Stormcoal makes Fire available as a consumable conductor, and the optional relic techniques appear while aiming their relevant cards.
- Open Abilities to place a chosen surface with Prismatic Instinct or relocate one layer with Confluence. Try cancellation and mouse/controller targeting. The destination placement itself causes no contact damage or Chill.

The game rules, rewards, enemy responses and saved state are real; the opening loadout and sparse board arrangement are a deliberate inspection fixture. Normal new runs use the complete reworked content pools.

## Regenerate and launch

Run from the task worktree (use its absolute path in a handoff). This command recreates the opening, verifies persisted state in a second Godot process, then launches its isolated game. Select Continue if the title screen appears.

Generation and verification have bounded timeouts. The interactive game stays open until you close it, so the inspection does not end after the task runner's usual five-minute limit.

```sh
python3 tools/inspection_fixture.py --task-id board-surface-refactor --run-id board-surface-refactor-inspection --launch --scenario combat --seed 90626 --level 10 --skills quick_wits,discerning_eye,measured_breath,ghost_stride,rehearsed_escape,makeshift_tool,carry_the_guard,prismatic_instinct,confluence --hand updraft,cinder_bloom,frostbolt,chain_bolt,quarry_step,rekindle_edge,spark_dart --player-position 2:4 --enemy-types crawler,bile_bloomer,acolyte --enemy-positions 4:4,6:4,7:3 --surfaces fire@4:4,rubble@4:4,ice@5:4,electrified@6:4,electrified@7:4,electrified@7:3 --relics coalheart_crucible,updraft_bottle,briar_winch,basalt_calendar --equipment-inventory iron_cleaver,duelist_rapier --item-inventory crimson_draught,pitch_firebomb,storm_jar --magic-inventory wildfire_halo,firebrand_volley,static_lash --umbra-stage clear --summary 'Textured shared ground, reusable Electrified, stronger terrain payoffs and concise card rules.' --manifest output/board-surface-refactor/feedback-pass/inspection-fixture.json
```

The fixture includes spare weapons, consumables and magic in the loadout, so
item dragging and long card summaries can be inspected without finding loot.

For a fresh renderer receipt, run `tests/board_surface_inspection_probe.gd`
through the visual probe runner with `LABYRINTH_INSPECTION_SOURCE` set to the
verified fixture's user directory printed by the task runner. The probe copies
the save privately before capturing the opening, aiming, ability choice and
cancellation; it never spends the user's playable inspection save.
