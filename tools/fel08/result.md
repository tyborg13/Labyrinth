# fel-08 · Pillar pop-up and door audit

## Round 0 pop-up proof

1. **Pillar.** The shared tile stack reads `PathUtils.tile_id` from the combat grid. An unoccupied `pillar` square adds `Pillar` with `Blocks movement and sight.` at the front. The entry uses the same plain tooltip panel as Crag Outcrop, with an empty icon field and no health or loop metadata. The mouse and focus detail builders return the same entry. Ordinary controller and keyboard navigation still exclude these pillars. [Stack builder](../../scripts/board_tile_tooltip.gd#L18) · [Focus eligibility](../../scripts/combat_board_view.gd#L5166) · [Focus detail](../../scripts/run_scene.gd#L3149)
2. **Exclusions.** The witness compares fixture 02's door at `(4, 8)` and fixture 01's Tharokh at `(4, 7)` against the pre-edit worktree. The door has empty mouse and focus stacks. The unit has an empty mouse stack and the existing `Rubble` focus detail. A separate in-memory check covers a living unit's footprint on a grid pillar, an outer wall, and the off-board sentinel. Icefall pillars and Worldspine spires use the existing terrain entries. The 12 saved fights contain neither kind as placed terrain. [Passive mouse guard](../../scripts/combat_board_view.gd#L5296) · [Terrain copy](../../scripts/combat_board_view.gd#L9802) · [Witness](witness.gd)
3. **Doors.** The source audit below covers board display, interaction, and copy. The door implementation is unchanged.
4. **Regression.** Both census runs use the fel-07 probe and the same 12 saved fights. The base was captured before editing at `9775488ac`. The comparison reuses fel-07's normalization and square-ownership checks. The two `(7, 7)` Pillar panels are the only recorded differences across 46 hovers. This comparison includes hover fill, occluder fades, annotated intent and rail evidence, and the production Continue witness. The separate marked-pillar check verifies the stack order `[Pillar, Meteorfall]`. [Comparison](compare.py) · [Base census](captures/base.scVRk9/observations.json) · [Implementation census](captures/branch.3dgm39/observations.json)

| Fixture and tile | Mouse stack | Focus detail stack |
| --- | --- | --- |
| 01 `(7, 7)` | `Pillar` / `Blocks movement and sight.` | `Pillar` / `Blocks movement and sight.` |
| 09 `(7, 7)` | `Pillar` / `Blocks movement and sight.` | `Pillar` / `Blocks movement and sight.` |
| 02 `(4, 8)` | Empty | Empty |
| 01 `(4, 7)` | Empty | `Rubble` / `Leaving Rubble costs 2 Movement.` |

| Check | Result |
| --- | --- |
| [Base witness](captures/dry.HkPjy8/runner.log) | `FEL08 BASE PASS pillars=2 controls=2` |
| [Implementation witness and native dry run](captures/dry.AMFIj6/runner.log) | `FEL08 SPECIAL AUDIT fixture_saves=12 with_special_terrain=0`<br>`FEL08 EDGE PASS marked=[Pillar, Meteorfall] occupied=[Rubble] wall=[] off_board=[]`<br>`FEL08 DRY RUN PASS pillars=2 controls=2` |
| [Census and stack comparison](captures/comparison.log) | `FEL08 CENSUS DIFF PASS unchanged=44 pillar_popup_only=2 off_square=0`<br>`FEL08 STACK DIFF PASS unchanged_controls=2 exact_pillar_stacks=2` |
| [Board tile tooltip](captures/board_tile_tooltip_test.log) | `BOARD TILE TOOLTIPS: PASS checks=233 failures=0` |
| [Board tile tooltip routes](captures/board_tile_tooltip_route_test.log) | `BOARD TILE TOOLTIP ROUTES: PASS (12 capture states; real X input; native popup layout; headless, no pixels)` |
| [Board tile tooltip live](captures/board_tile_tooltip_live_test.log) | `BOARD TILE TOOLTIP LIVE: PASS (held mouse, idle controller, occupied tile, all mutation domains)` |
| [UI identity lint](captures/ui_identity_lint.log) | `Ran 25 tests in 24.404s`<br>`OK` |
| [Rules text lint](captures/rules_text_lint.log) | `Ran 3 tests in 0.354s`<br>`OK`<br>`PASS: Rules text lint (16 existing hits)` |

Godot logged `ERROR: Condition "ret != noErr" is true. Returning: ""` from `get_system_ca_certificates` in the base and implementation runs. The board tooltip suite reported the existing missing `bramble` and `ice_pillar` glossary definitions and returned exit code 0. [Board tooltip log](captures/board_tile_tooltip_test.log)

### Proof for the design owner

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fel-08 && bash tools/fel08/native.sh
```

The command uses `LABYRINTH_CEL_LOOK=all` and sends mouse motion directly to the 1920×1080 SubViewport at 100% UI scale. It prints each PNG path on its own line. Expected outputs are `01-s0-seed1-0-4_0-t9-C-hover.png` and `09-s3-seed12-3-16_0-t15-C-hover.png` under `tools/fel08/captures/native.*/`, alongside `visual-proof.json`, `stacks.json`, and `runner.log`. Native capture and inspection are pending. [Visual proof contract](proof_contract.json)

### Chosen defaults

- The native and headless witness reuse fel-06's tile-center projection, SubViewport motion, frame waits, and hover settle. The native wrapper uses the existing 180-second capture timeout and gives the board framing check five seconds to settle.
- The control uses Tharokh's census square `(4, 7)`. The edge check adds a 1-damage Meteorfall to the reported pillar and substitutes a grid pillar beneath that same unit square in a copied snapshot. The wall check uses `(0, 0)` and the off-board check uses `(-1, -1)`.

**TODO_DESIGN placeholders** — None.

## Doors

The board distinguishes a boundary **door** (`door_tile`) from the walkable **threshold** (`target_tile`) one tile inside it. The generator puts `door` in the grid for each connection. `PathUtils.BLOCKING_TILES` prevents ordinary actor movement onto that grid tile, regardless of the visual or travel state. Combat line of sight checks impassable *interior* points of the ray, skips both endpoints, and returns true for tiles at most one tile apart on each axis. These rules apply to every boundary door below. Enemy navigation uses the same passability and includes dynamically sealed thresholds among its blockers. [room_generator.gd:413](../../scripts/room_generator.gd#L413) · [combat_objective_rules.gd:137](../../scripts/combat_objective_rules.gd#L137) · [path_utils.gd:12](../../scripts/path_utils.gd#L12) · [combat_engine.gd:8422](../../scripts/combat_engine.gd#L8422) · [combat_engine.gd:11014](../../scripts/combat_engine.gd#L11014) · [combat_engine.gd:12231](../../scripts/combat_engine.gd#L12231) · [combat_engine.gd:13047](../../scripts/combat_engine.gd#L13047)

**Shared door art and hover.** Visible doors use `door.png`, flipped horizontally on the column edges. The closed body starts white and receives ordinary foreground obstruction and hover occlusion tint. A destination icon, when supplied, floats above it in a medallion. Room icon IDs come from `RoomIcons.icon_id_for_room`, including `unknown` for an unscouted mystery, the specific special encounter, guardian or boss icon, and the elemental icon for legacy elemental combat rooms. The board keys its markers by `exit_tiles` membership. The `N`, `E`, `S`, `W` values from the exit-label builders are inputs to that lookup. The visible marks are fills, rings, and the controller chevron. An otherwise bare door has no door panel. A picked door still gets the ordinary hover fill, and a door can fade while a covered tile is inspected. The threshold icon has its own registered tooltip. [combat_board_view.gd:15263](../../scripts/combat_board_view.gd#L15263) · [combat_board_view.gd:8952](../../scripts/combat_board_view.gd#L8952) · [combat_board_view.gd:9189](../../scripts/combat_board_view.gd#L9189) · [combat_board_view.gd:5156](../../scripts/combat_board_view.gd#L5156) · [room_icon_library.gd:45](../../scripts/room_icon_library.gd#L45) · [run_scene.gd:34183](../../scripts/run_scene.gd#L34183) · [combat_board_view.gd:8283](../../scripts/combat_board_view.gd#L8283) · [combat_board_view.gd:8347](../../scripts/combat_board_view.gd#L8347) · [combat_board_view.gd:5296](../../scripts/combat_board_view.gd#L5296) · [combat_board_view.gd:8544](../../scripts/combat_board_view.gd#L8544)

**Shared combat interaction.** A bare boundary-door click has no travel action. While movement is selected, an attempt to move onto a visible door is rejected with `Blocked`. With other cards or skills selected, the normal targeting rules apply. An open Reach the Exit threshold is floor that units can occupy under ordinary movement rules. Moving the living hero onto that floor tile satisfies the objective even while enemies remain. Only the hero's position counts. Enemies can occupy and obstruct the route or the threshold. Reach the Exit AI favors control intents and evaluates movement by proximity to an open threshold and whether the destination blocks the hero's route. [run_scene.gd:21312](../../scripts/run_scene.gd#L21312) · [target_click_feedback.gd:90](../../scripts/target_click_feedback.gd#L90) · [combat_engine.gd:3842](../../scripts/combat_engine.gd#L3842) · [combat_engine.gd:9258](../../scripts/combat_engine.gd#L9258) · [combat_engine.gd:10470](../../scripts/combat_engine.gd#L10470)

| Door state and when | Art, icon, and marker | Hover, action, enemies, and existing text |
| --- | --- | --- |
| **Active `exit_options` door in `room`.** The connected destination is revealed, unsealed and at least as deep as the current room. An intermediate cleared boss allows outward connections only. [run_engine.gd:889](../../scripts/run_engine.gd#L889) · [run_engine.gd:2285](../../scripts/run_engine.gd#L2285) | Shared closed art, destination medallion, gold fill and pulse. Pointer hover adds the exit focus fill. Controller focus adds the door pulse and chevron. [run_scene.gd:17487](../../scripts/run_scene.gd#L17487) · [run_scene.gd:17549](../../scripts/run_scene.gd#L17549) · [combat_board_view.gd:8285](../../scripts/combat_board_view.gd#L8285) · [combat_board_view.gd:8353](../../scripts/combat_board_view.gd#L8353) | Hover updates the board status under `Choose Door` with the destination. The source formats ordinary rooms as `%s%s %d` (optional element plus room type and depth) and special rooms as `%s %d` (special name and depth). Focus detail reads `Travel through this door`. Clicking or confirming commits travel and opens the selected door. The hero does not path onto the grid door, and the room display has no active enemies. The map controller prompt is `Enter`, then `Entering`. The path tutorial shows `CHOOSE A PATH`, `Enter the Next Chamber`, and `Select a glowing doorway. The map previews where each route leads.` The map version says `Select a glowing room on the map to travel there.` The controller action is `Travel`. [run_scene.gd:27267](../../scripts/run_scene.gd#L27267) · [run_scene.gd:3157](../../scripts/run_scene.gd#L3157) · [run_scene.gd:3402](../../scripts/run_scene.gd#L3402) · [run_scene.gd:21336](../../scripts/run_scene.gd#L21336) · [run_scene.gd:27759](../../scripts/run_scene.gd#L27759) · [run_scene.gd:18066](../../scripts/run_scene.gd#L18066) · [section_map_panel.gd:1209](../../scripts/section_map_panel.gd#L1209) · [contextual_combat_tutorial.gd:221](../../scripts/contextual_combat_tutorial.gd#L221) |
| **Active by `exit_options` alone outside `room`.** A revealed route may qualify in combat or while another mode displays the board. This includes ordinary combat and post-combat reward without `pending_escape`, unless an objective assigns that same door a marker. [run_scene.gd:34226](../../scripts/run_scene.gd#L34226) | Normal closed body, with no destination icon, exit paint or threshold marker for this door. Room-mode label and icon maps only apply in `room`. In other modes they come from the displayed Reach the Exit objective. [run_scene.gd:17547](../../scripts/run_scene.gd#L17547) · [run_scene.gd:34198](../../scripts/run_scene.gd#L34198) · [combat_board_view.gd:9470](../../scripts/combat_board_view.gd#L9470) | Hover fill and shared combat interaction. This presentation flag gives neither enemies nor the hero a travel action. Room status and direct door travel apply only in `room`. In reward mode the board may retain the closed door but clicking does not select a route. Door-specific text is absent. [run_scene.gd:34169](../../scripts/run_scene.gd#L34169) · [run_scene.gd:21330](../../scripts/run_scene.gd#L21330) · [run_scene.gd:27267](../../scripts/run_scene.gd#L27267) |
| **Reach the Exit objective door in combat.** Eligible connections are normally onward, excluding the arrival direction and `inward` links, with a fallback for fixtures with no ordinary eligible exit. [combat_objective_rules.gd:201](../../scripts/combat_objective_rules.gd#L201) · [run_scene.gd:34239](../../scripts/run_scene.gd#L34239) | Shared closed art and destination medallion on the boundary. The boundary gets the gold exit fill and pulse. The interior threshold gets teal fill, a pulsing teal ring and the Reach the Exit icon. [run_scene.gd:17365](../../scripts/run_scene.gd#L17365) · [run_scene.gd:34198](../../scripts/run_scene.gd#L34198) · [combat_board_view.gd:8283](../../scripts/combat_board_view.gd#L8283) · [board_layer_slices.gd:295](../../scripts/board_layer_slices.gd#L295) · [combat_board_view.gd:8531](../../scripts/combat_board_view.gd#L8531) | Hover the threshold icon for `Objective threshold · Reach this tile to clear the encounter.` The boundary itself uses shared hover and combat interaction. Move onto the threshold to win. Enemies can obstruct it. The map's `Show exit` / `Showing exit` closes the map and highlights the corresponding door from `exit_options`, without travel. Objective text is listed below. [combat_board_view.gd:8536](../../scripts/combat_board_view.gd#L8536) · [combat_engine.gd:3842](../../scripts/combat_engine.gd#L3842) · [section_map_panel.gd:518](../../scripts/section_map_panel.gd#L518) · [section_map_panel.gd:1209](../../scripts/section_map_panel.gd#L1209) · [run_scene.gd:35105](../../scripts/run_scene.gd#L35105) |
| **Selected `pending_escape` door in `reward`.** Victory on an open threshold records the exact door and the destination. The reward shows the saved final board. [run_engine.gd:1463](../../scripts/run_engine.gd#L1463) · [run_engine.gd:1328](../../scripts/run_engine.gd#L1328) · [run_scene.gd:18088](../../scripts/run_scene.gd#L18088) | Selected door is the only active flag. The door stays closed through the choice. The objective still supplies its medallion, gold boundary paint and the threshold markers of eligible exits. There is no distinct selected-door badge. [run_scene.gd:34226](../../scripts/run_scene.gd#L34226) · [run_scene.gd:17359](../../scripts/run_scene.gd#L17359) · [run_scene.gd:17547](../../scripts/run_scene.gd#L17547) | The hero is already on the selected interior threshold. Enemies may remain visible in the saved board and take no turns there. The boundary has no travel click or new door text. Board tooltips are disabled during the `VICTORY` intro and in `reward` mode. Choosing a card or skipping for Health starts continuation. Existing reward copy is listed below. [combat_engine.gd:3851](../../scripts/combat_engine.gd#L3851) · [run_scene.gd:14973](../../scripts/run_scene.gd#L14973) · [choice_refresh.gd:11](../../scripts/choice_refresh.gd#L11) · [run_scene.gd:21336](../../scripts/run_scene.gd#L21336) · [run_engine.gd:1582](../../scripts/run_engine.gd#L1582) · [run_engine.gd:1985](../../scripts/run_engine.gd#L1985) |
| **Selected `pending_escape` door in `escape`.** A reward claim or skip changes mode to `escape`. Continuing a saved run in this mode queues the same continuation. [run_engine.gd:1591](../../scripts/run_engine.gd#L1591) · [run_engine.gd:1998](../../scripts/run_engine.gd#L1998) · [run_scene.gd:9684](../../scripts/run_scene.gd#L9684) | Same saved board and objective markers until the selected door enters the opening animation. [run_scene.gd:18088](../../scripts/run_scene.gd#L18088) · [run_scene.gd:27867](../../scripts/run_scene.gd#L27867) | Continuation automatically travels to the committed destination through the normal adjacency and sealed-room guards. The hero does not move onto the grid door. Extra hover, click, or enemy action is unnecessary. There is no `escape` status label or detail. [run_engine.gd:1640](../../scripts/run_engine.gd#L1640) · [run_scene.gd:27867](../../scripts/run_scene.gd#L27867) · [run_scene.gd:27267](../../scripts/run_scene.gd#L27267) |
| **Locked visited-room connection.** A connected destination is visited and sealed and the door is absent from the active list. This branch runs outside the `pending_escape` override. [run_scene.gd:34245](../../scripts/run_scene.gd#L34245) | Shared closed art and tint. Ordinarily no medallion, exit fill or lock marker. The lock lookup makes the door visible. [combat_board_view.gd:8952](../../scripts/combat_board_view.gd#L8952) · [combat_board_view.gd:9470](../../scripts/combat_board_view.gd#L9470) · [run_scene.gd:17547](../../scripts/run_scene.gd#L17547) | Hover fill only on a bare door. The room-mode travel lookup excludes sealed destinations and there is no board lock label. The map can show `Already visited` with the `Inspect` controller action. Enemy interaction is ordinary combat obstruction. Last Door is a separate defeat-triggered skill described below. [run_engine.gd:909](../../scripts/run_engine.gd#L909) · [run_scene.gd:27299](../../scripts/run_scene.gd#L27299) · [section_map_panel.gd:1036](../../scripts/section_map_panel.gd#L1036) · [section_map_panel.gd:1216](../../scripts/section_map_panel.gd#L1216) · [run_engine.gd:1346](../../scripts/run_engine.gd#L1346) |
| **Locked non-selected escape door.** An unsealed objective exit other than the selected door enters the lock list in `reward` and `escape`. [run_scene.gd:34245](../../scripts/run_scene.gd#L34245) | Shared closed art and tint. The saved objective still supplies the destination medallion, gold boundary fill and pulse, and the marked threshold. The visual path does not use the lock flag to tint it. [run_scene.gd:34198](../../scripts/run_scene.gd#L34198) · [run_scene.gd:17365](../../scripts/run_scene.gd#L17365) · [combat_board_view.gd:8952](../../scripts/combat_board_view.gd#L8952) | Bare-door hover has no new panel. The retained threshold icon keeps the objective tooltip registration. Board tooltips are disabled in `reward` mode. Clicking or attempting to move cannot change the selected route. Remaining enemies are a snapshot. There is no door-specific lock string. [combat_board_view.gd:8544](../../scripts/combat_board_view.gd#L8544) · [choice_refresh.gd:11](../../scripts/choice_refresh.gd#L11) · [run_scene.gd:21336](../../scripts/run_scene.gd#L21336) · [run_engine.gd:1640](../../scripts/run_engine.gd#L1640) |
| **Umbral Snare gaoler exit.** The shortest route, with map lane as the tiebreaker, has role `jailer` and stays open. [snare_room_rules.gd:24](../../scripts/snare_room_rules.gd#L24) · [snare_room_rules.gd:154](../../scripts/snare_room_rules.gd#L154) | Ordinary Reach the Exit door and teal threshold. There is no seal countdown. [combat_board_view.gd:18249](../../scripts/combat_board_view.gd#L18249) · [combat_board_view.gd:18275](../../scripts/combat_board_view.gd#L18275) | Shared Reach the Exit hover and movement. `The Umbral Gaoler` starts one step before this threshold along the approach path. Other enemies can obstruct the exit. Each open door pays the Snare bonus on successful escape. See the Snare copy below. [snare_room_rules.gd:38](../../scripts/snare_room_rules.gd#L38) · [snare_room_rules.gd:111](../../scripts/snare_room_rules.gd#L111) · [snare_room_rules.gd:177](../../scripts/snare_room_rules.gd#L177) · [special_encounters.json:190](../../data/special_encounters.json#L190) |
| **Umbral Snare timed, open exit.** Other exits have role `sealing` and begin open. The timer is 3 player turns for a two-door room, or 2 and 4 for the timed doors in a three-door room. [snare_room_rules.gd:7](../../scripts/snare_room_rules.gd#L7) · [snare_room_rules.gd:38](../../scripts/snare_room_rules.gd#L38) · [special_encounters.json:204](../../data/special_encounters.json#L204) | Shared objective door body, medallion and gold marker. `Seals · %d` floats above the medallion. The threshold fill is Umbra-violet and keeps the teal ring and objective icon. [combat_board_view.gd:8279](../../scripts/combat_board_view.gd#L8279) · [board_layer_slices.gd:295](../../scripts/board_layer_slices.gd#L295) · [combat_board_view.gd:18275](../../scripts/combat_board_view.gd#L18275) | Shared Reach the Exit hover and movement while open. A `Sealbinder` starts beside the threshold and is assigned to this exit. Inspect the enemy for `Seal · %d` and the description below. Killing the Sealbinder before sealing keeps the exit open. An open exit pays the bonus. [snare_room_rules.gd:45](../../scripts/snare_room_rules.gd#L45) · [snare_room_rules.gd:118](../../scripts/snare_room_rules.gd#L118) · [snare_room_rules.gd:135](../../scripts/snare_room_rules.gd#L135) · [combat_board_view.gd:5388](../../scripts/combat_board_view.gd#L5388) |
| **Umbral Snare kept open.** The linked Sealbinder died before sealing. `kept_open` prevents sealing and the exit remains in the open lists. [snare_room_rules.gd:147](../../scripts/snare_room_rules.gd#L147) · [combat_objective_rules.gd:103](../../scripts/combat_objective_rules.gd#L103) | Same timed-lane violet threshold, ring and icon, normal body and medallion. The countdown disappears. There is no separate kept-open badge. [combat_board_view.gd:18249](../../scripts/combat_board_view.gd#L18249) · [combat_board_view.gd:18275](../../scripts/combat_board_view.gd#L18275) | Shared Reach the Exit hover and movement. The dead binder no longer acts, but other enemies can obstruct. This door still pays the open-door bonus. No separate `kept_open` text is displayed. [snare_room_rules.gd:147](../../scripts/snare_room_rules.gd#L147) · [snare_room_rules.gd:177](../../scripts/snare_room_rules.gd#L177) |
| **Umbral Snare sealed exit.** At the end of the enemy round after its deadline, an unprotected exit becomes `sealed`. Its binder dissolves. [snare_room_rules.gd:154](../../scripts/snare_room_rules.gd#L154) | The objective label map still includes the boundary so the closed body and gold exit paint can remain. The body switches to dark Umbra tint and the medallion and chip disappear. The threshold loses its teal ring and icon, but the violet fill predicate still uses `role == "sealing"`. [run_scene.gd:34198](../../scripts/run_scene.gd#L34198) · [combat_board_view.gd:155](../../scripts/combat_board_view.gd#L155) · [combat_board_view.gd:8279](../../scripts/combat_board_view.gd#L8279) · [combat_board_view.gd:8958](../../scripts/combat_board_view.gd#L8958) · [combat_board_view.gd:18249](../../scripts/combat_board_view.gd#L18249) · [combat_objective_rules.gd:103](../../scripts/combat_objective_rules.gd#L103) | Door hover is ordinary fill. The threshold icon tooltip is gone. Player and enemy movement cannot enter the sealed threshold. The seal does not displace an enemy already standing there. The seal does not alter grid LOS, so the floor threshold's seal itself does not block sight. The threshold cannot win the encounter or pay the bonus. There is no sealed-door hover text. [snare_room_rules.gd:170](../../scripts/snare_room_rules.gd#L170) · [combat_engine.gd:8419](../../scripts/combat_engine.gd#L8419) · [combat_engine.gd:8459](../../scripts/combat_engine.gd#L8459) · [combat_engine.gd:13047](../../scripts/combat_engine.gd#L13047) |
| **Inactive connection, no marker or active/locked flag.** For example, a generated connection to an unrevealed destination absent from the objective and locked-room list. [room_generator.gd:413](../../scripts/room_generator.gd#L413) · [run_engine.gd:909](../../scripts/run_engine.gd#L909) · [run_scene.gd:34256](../../scripts/run_scene.gd#L34256) | The renderer treats it as `wall`, with no door art, medallion, or marker. Standard outer wall rendering is disabled, so the normal boundary slot is omitted. The grid still holds `door`. [combat_board_view.gd:383](../../scripts/combat_board_view.gd#L383) · [combat_board_view.gd:9448](../../scripts/combat_board_view.gd#L9448) · [combat_board_view.gd:9465](../../scripts/combat_board_view.gd#L9465) | The omitted boundary slot has no door hover or click target. Units cannot enter its grid square and the door remains subject to the shared LOS rule. The map description for an unrevealed destination may show `Undiscovered`. [section_map_panel.gd:1036](../../scripts/section_map_panel.gd#L1036) · [combat_board_view.gd:16840](../../scripts/combat_board_view.gd#L16840) · [run_scene.gd:34169](../../scripts/run_scene.gd#L34169) · [path_utils.gd:23](../../scripts/path_utils.gd#L23) |
| **Opening door.** Transient when room travel is confirmed or when `escape` continues. [run_scene.gd:27784](../../scripts/run_scene.gd#L27784) · [run_scene.gd:27880](../../scripts/run_scene.gd#L27880) | The opening sheet replaces the closed door body and its medallion for the selected tile. The body is flipped on column edges. Reduced motion displays the last frame. The travel branches also play the door-open cue. [combat_board_view.gd:425](../../scripts/combat_board_view.gd#L425) · [combat_board_view.gd:8956](../../scripts/combat_board_view.gd#L8956) · [combat_board_view.gd:9278](../../scripts/combat_board_view.gd#L9278) · [run_scene.gd:27834](../../scripts/run_scene.gd#L27834) | There is no second travel click, unit step onto the door, or entrance for enemies. The animation lock prevents board clicks, the route has already been chosen, and no opening-door status label or detail is shown. [run_scene.gd:21322](../../scripts/run_scene.gd#L21322) · [run_scene.gd:27267](../../scripts/run_scene.gd#L27267) · [run_scene.gd:27774](../../scripts/run_scene.gd#L27774) |

### Existing objective, Snare, and continuation copy

- **Objective and map.** `Reach the Exit`, short name `Reach Exit`, `Reach a marked door to escape.`, and combat HUD title `REACH THE EXIT` under `OBJECTIVE`. The live count uses `Reach any of %d marked threshold%s` with `s` except at 1. The pre-battle heading uses `OBJECTIVE · Reach the Exit`, and its hover includes the objective description. `Objective threshold · Reach this tile to clear the encounter.` is the threshold icon's tooltip. An action that requires a blocked ray may show `No line of sight`. [combat_objective_rules.gd:37](../../scripts/combat_objective_rules.gd#L37) · [combat_objective_hud.gd:69](../../scripts/combat_objective_hud.gd#L69) · [combat_objective_hud.gd:136](../../scripts/combat_objective_hud.gd#L136) · [combat_objective_hud.gd:550](../../scripts/combat_objective_hud.gd#L550) · [pre_battle_view.gd:233](../../scripts/pre_battle_view.gd#L233) · [combat_board_view.gd:8544](../../scripts/combat_board_view.gd#L8544) · [target_click_feedback.gd:103](../../scripts/target_click_feedback.gd#L103)
- **Umbral Snare.** The room preview uses `Umbral Snare` and `The doors are sealing. Get out before they close.` The pre-battle objective tooltip and successful bonus notice use `Normal combat reward, plus 6 Embers per open door.` The countdown chip uses `Seals · %d`. The Sealbinder's intent uses `Seal · %d` and `Seals its door in %d %s. Kill it to keep the door open. When you escape, each open door pays %d Embers.` The source substitutes the countdown, `turn` or `turns`, and `6`. The objective tooltip also appends one of the rule sentences below. [special_encounters.json:177](../../data/special_encounters.json#L177) · [section_map_panel.gd:1055](../../scripts/section_map_panel.gd#L1055) · [special_encounter_library.gd:50](../../scripts/special_encounter_library.gd#L50) · [pre_battle_view.gd:238](../../scripts/pre_battle_view.gd#L238) · [run_engine.gd:1446](../../scripts/run_engine.gd#L1446) · [combat_board_view.gd:18284](../../scripts/combat_board_view.gd#L18284) · [snare_room_rules.gd:135](../../scripts/snare_room_rules.gd#L135) · [combat_objective_rules.gd:284](../../scripts/combat_objective_rules.gd#L284)
- **After reaching a threshold.** The common banner is `VICTORY`, followed by `GROW YOUR POWER`. Skipping for Health offers `SKIP · HEALTH FULL` or `SKIP & RECOVER · +%d HEALTH · %d → %d`. The conditional missed-equipment notice is `Unclaimed gear will be left behind.` A claimed card can set `Added %s to your deck.` These describe the outcome and reward. The route has already been selected. [post_combat_reward_sequence.gd:51](../../scripts/post_combat_reward_sequence.gd#L51) · [run_scene.gd:1105](../../scripts/run_scene.gd#L1105) · [run_scene.gd:15457](../../scripts/run_scene.gd#L15457) · [run_engine.gd:64](../../scripts/run_engine.gd#L64) · [run_engine.gd:1445](../../scripts/run_engine.gd#L1445) · [run_engine.gd:1589](../../scripts/run_engine.gd#L1589)
- **Related room-transition notices.** An intermediate dragon's claimed reward can say `The labyrinth opens outward.` Last Door is a skill-triggered transition on defeat, independent of clicking the visible return door. It can reopen the previous visited room, rebuild the board there and report `Last Door returns you to the previous chamber at %d Health.` The skill description is `Once between bosses, a non-boss defeat returns you to the previous room at @icon(health) 1.` The `@icon(health)` token renders the Health icon. [run_engine.gd:1579](../../scripts/run_engine.gd#L1579) · [run_engine.gd:1499](../../scripts/run_engine.gd#L1499) · [run_engine.gd:1526](../../scripts/run_engine.gd#L1526) · [skills.json:554](../../data/skills.json#L554)


The Snare objective appends the live battlefield rules sentence. The rules dispatcher supplies these sentences in place of the catalog's fallback variant descriptions. [combat_objective_rules.gd:287](../../scripts/combat_objective_rules.gd#L287) · [snare_pressure_rules.gd:8](../../scripts/snare_pressure_rules.gd#L8)

- Earth — `On each Upheaval beat, after your turn, a Marked tile on the way out becomes an Outcrop.` [battlefield_rules.json:141](../../data/battlefield_rules.json#L141)
- Fire — `On each Wildfire beat, after your turn, each Fire tile spreads 1 tile away from the entry.` [battlefield_rules.json:155](../../data/battlefield_rules.json#L155)
- Air — `On each Gust beat, after your turn, each unit is Pushed 1 tile toward the entry.` [battlefield_rules.json:170](../../data/battlefield_rules.json#L170)
- Ice — `On each Frostbite beat, after your turn, each unit on Ice takes 1 damage.` [battlefield_rules.json:184](../../data/battlefield_rules.json#L184)
- Lightning — `On each Lightning Storm beat, after your turn, each unit on Electrified takes 3 damage.` [battlefield_rules.json:198](../../data/battlefield_rules.json#L198)
- Shadow — `On each Shadowstep beat, after your turn, each hidden enemy Blinks up to 2 tiles toward you.` [battlefield_rules.json:212](../../data/battlefield_rules.json#L212)

### What the board can make easy to misread

- An active door from `exit_options` alone and a visited locked door can have the same closed body, tint, and lack of icon while the board is outside `room` mode. [run_scene.gd:17547](../../scripts/run_scene.gd#L17547) · [combat_board_view.gd:8952](../../scripts/combat_board_view.gd#L8952)
- `Reach a marked door to escape.` accompanies marks on two different squares. The gold boundary door blocks entry while the colored floor threshold clears the encounter. The distinction appears in the tooltip for the threshold icon. [combat_objective_rules.gd:37](../../scripts/combat_objective_rules.gd#L37) · [combat_objective_rules.gd:137](../../scripts/combat_objective_rules.gd#L137) · [combat_board_view.gd:8283](../../scripts/combat_board_view.gd#L8283) · [combat_board_view.gd:8544](../../scripts/combat_board_view.gd#L8544)
- During reward and escape, a locked alternative can retain the same destination medallion and exit pulse as the selected door. The automatically opening door is the first door-specific animation that distinguishes the chosen route. [run_scene.gd:34226](../../scripts/run_scene.gd#L34226) · [run_scene.gd:34198](../../scripts/run_scene.gd#L34198) · [run_scene.gd:27887](../../scripts/run_scene.gd#L27887)
- A sealed Snare door can retain the gold boundary pulse and the violet threshold fill. Its countdown, destination medallion, and threshold icon are gone. The `Show exit` map action checks map availability and does not check the Snare seal. [combat_board_view.gd:8279](../../scripts/combat_board_view.gd#L8279) · [combat_board_view.gd:18255](../../scripts/combat_board_view.gd#L18255) · [combat_objective_rules.gd:103](../../scripts/combat_objective_rules.gd#L103) · [section_map_panel.gd:518](../../scripts/section_map_panel.gd#L518) · [run_scene.gd:35105](../../scripts/run_scene.gd#L35105)
- The closed door art and its ordinary hover fill give no line-of-sight explanation. An unrendered connection still has impassable grid terrain. The sealed Snare floor threshold can block movement while leaving the grid LOS test unchanged. [combat_board_view.gd:5296](../../scripts/combat_board_view.gd#L5296) · [combat_board_view.gd:9448](../../scripts/combat_board_view.gd#L9448) · [combat_engine.gd:8419](../../scripts/combat_engine.gd#L8419) · [combat_engine.gd:13047](../../scripts/combat_engine.gd#L13047)

## Feedback 1 · Combat door pop-ups

1. **Combat only.** The board reads the owning run's exact mode. The room focus detail and destination hint keep their existing routes. Reward and escape keep their existing tooltip settings. [Mode gate](../../scripts/combat_board_view.gd#L5300) · [Room focus](../../scripts/run_scene.gd#L3149)
2. **Copy.** An open objective door shows `Exit` / `Reach the marked tile in front to escape.` A sealed Snare door shows `Sealed exit` / `Blocks movement and sight.` Other visible combat doors show `Door` / `Blocks movement and sight.` Each uses the shared plain panel. [Tile stack](../../scripts/board_tile_tooltip.gd#L18)
3. **Paint inputs.** The grid and `_door_is_visible` identify rendered doors. The boundary marker and threshold lookup identify open objective doors. The painter's `_snare_door_sealed` check identifies sealed exits. [Tile stack](../../scripts/board_tile_tooltip.gd#L18) · [Door painter](../../scripts/combat_board_view.gd#L8962)
4. **Order.** The new panel precedes the existing entries. The edge witness checks `[Door, Meteorfall]` and confirms a cached door panel disappears when its connection renders as wall. [Door witness](door_witness.gd)
5. **Regression.** The witness checks the exact threshold registration and the existing room travel detail. A census replay against the round 0 implementation recorded 40 identical observations and six door panels, with zero off-square pop-ups. Fixture 03 at `(8, 4)` is a sealed Snare exit. The other five changed hovers are plain doors. [Comparison log](captures/r1/census-diff.log) · [Feedback census](captures/r1-census.LQRVmD/observations.json)

| Witness case | Tile | Mode | Mouse and focus stack |
| --- | --- | --- | --- |
| Ordinary objective exit | `(4, 0)` | Combat | `Exit` |
| Active door outside the objective | `(4, 8)` | Combat | `Door` |
| Locked visited-room door | `(8, 4)` | Combat | `Door` |
| Snare gaoler exit | `(4, 0)` | Combat | `Exit` |
| Snare timed exit | `(8, 4)` | Combat | `Exit` |
| Snare kept-open exit | `(8, 4)` | Combat | `Exit` |
| Snare sealed exit | `(8, 4)` | Combat | `Sealed exit` |
| Active room door | `(4, 0)` | Room | Empty |

| Check | Result |
| --- | --- |
| [Native wrapper dry run](captures/dry.WePeHM/runner.log) | `FEL08 DOOR EDGE PASS inactive=[] reward=[] escape=[] marked=[Door, Meteorfall]`<br>`FEL08 DOOR WITNESS PASS combat=7 room=1 threshold=unchanged`<br>`FEL08 DRY RUN PASS pillars=2 controls=2` |
| [Census comparison](captures/r1/census-diff.log) | `FEL08 R1 CENSUS DIFF PASS unchanged=40 door_popup_only=6 off_square=0` |
| [Board tile tooltip](captures/r1/board_tile_tooltip_test.log) | `BOARD TILE TOOLTIPS: PASS checks=233 failures=0` |
| [Board tile tooltip routes](captures/r1/board_tile_tooltip_route_test.log) | `BOARD TILE TOOLTIP ROUTES: PASS (12 capture states; real X input; native popup layout; headless, no pixels)` |
| [Board tile tooltip live](captures/r1/board_tile_tooltip_live_test.log) | `BOARD TILE TOOLTIP LIVE: PASS (held mouse, idle controller, occupied tile, all mutation domains)` |
| [UI identity lint](captures/r1/ui_identity_lint.log) | `Ran 25 tests in 28.271s`<br>`OK` |
| [Rules text lint](captures/r1/rules_text_lint.log) | `Ran 3 tests in 0.232s`<br>`OK`<br>`PASS: Rules text lint (16 existing hits)` |

### Proof for the design owner

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fel-08 && bash tools/fel08/native.sh
```

The command captures the two pillar stills and three door stills at 1920×1080, 100% UI scale, with `LABYRINTH_CEL_LOOK=all`. `exit-hover.png`, `sealed-exit-hover.png`, and `door-hover.png` go under `tools/fel08/captures/native.*/` beside the pillar PNGs and `visual-proof.json`. The probe prints each PNG path and drives the SubViewport directly. Windowed capture and inspection are pending. [Proof contract](proof_contract.json)

### Chosen defaults

- The ordinary witness uses fixture 02. The north connection gets the objective, the east destination is marked visited and sealed, and the south connection stays active. The room witness uses the cleared room with the north door active.
- Snare states reuse the existing fire tier 2 inspection fixtures and vision bonus. The door witness inherits the pillar probe's waits and timeout.

**TODO_DESIGN placeholders** · None.

## Feedback 2 · Reach the Exit copy

- The objective description is `Reach a marked tile to escape.` The pre-battle plate, combat objective HUD, and map resolve the current definition at display time. The Grimoire and glossary have no separate Reach the Exit description. The Continue witness uses a disk save with the old stored value in both the room layout and combat state. [Definition](../../scripts/combat_objective_rules.gd#L40) · [Description resolver](../../scripts/combat_objective_rules.gd#L284) · [Pre-battle heading](../../scripts/pre_battle_view.gd#L233) · [Objective HUD](../../scripts/combat_objective_hud.gd#L69) · [Map](../../scripts/section_map_panel.gd#L1009)
- The live status reads `Reach the marked tile` with one open target and `Reach any of 2 marked tiles` with two. The count still uses the existing open objective targets. [Live status](../../scripts/combat_objective_hud.gd#L550)

### Text audit

The case-insensitive search covered `scripts/`, `data/`, `scenes/`, and `tests/`. Every match is listed below. The two remaining references are archived diff lines. [Before log](captures/r2/old-copy-before.log) · [After log](captures/r2/old-copy-after.log)

| Search hit | Before | After |
| --- | --- | --- |
| [combat_objective_rules.gd:40](../../scripts/combat_objective_rules.gd#L40) | `Reach a marked door to escape.` | — |
| [combat_objective_hud.gd:552](../../scripts/combat_objective_hud.gd#L552) | `Reach any of %d marked threshold%s` | — |
| [combat_objective_probe.gd:151](../../tests/combat_objective_probe.gd#L151) | `marked threshold` | — |
| [pre_battle_living_foes_suite.gd:17](../../tests/suites/pre_battle_living_foes_suite.gd#L17) | `Reach a marked door to escape.` | — |
| [txt_16_report.md:1481](../../tests/txt_16_report.md#L1481) | `marked threshold` | `marked threshold` |
| [txt_16_report.md:1482](../../tests/txt_16_report.md#L1482) | `marked threshold` | `marked threshold` |

### Verification

The combat witness reads the live status label and the open objective tooltip. Continue loaded the old stored description and the tooltip showed the new copy. The pre-battle witness checked both the fresh layout's stored description and the focus tooltip. [Native wrapper dry run](captures/dry.iqhUqa/runner.log)

```text
FEL08 DOOR WITNESS PASS combat=7 room=1 threshold=unchanged
FEL08 OBJECTIVE exits=1 status: Reach the marked tile
FEL08 OBJECTIVE fresh pre-battle description: Reach a marked tile to escape.
FEL08 OBJECTIVE exits=2 status: Reach any of 2 marked tiles
FEL08 OBJECTIVE continued description: Reach a marked tile to escape. (legacy value loaded)
FEL08 OBJECTIVE WITNESS PASS status_counts=1,2 fresh=true continued=true
FEL08 DRY RUN PASS pillars=2 controls=2
```

| Check | Result |
| --- | --- |
| [Pre-battle semantics](captures/r2/pre-battle-semantics.log) | `PRE-BATTLE SEMANTICS TEST: PASS`<br>`TEST RESULT: PASS` |
| [Combat objective probe parser](captures/r2/combat-objective-parse.log) | `--check-only` exited 0 |
| [UI identity lint](captures/r2/ui_identity_lint.log) | `Ran 25 tests in 5.002s`<br>`OK` |
| [Rules text lint](captures/r2/rules_text_lint.log) | `Ran 3 tests in 0.081s`<br>`OK`<br>`PASS: Rules text lint (16 existing hits)` |

### Proof for the design owner

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fel-08 && bash tools/fel08/native.sh
```

The three new stills are `objective-one-exit.png`, `objective-two-exits-resumed.png`, and `objective-pre-battle.png`. The runner writes them alongside the five accepted pillar and door views under `tools/fel08/captures/native.*/` at 1920×1080 and 100% UI scale. The round-1 `exit-hover.png` is also refreshed and includes the singular status. Native rendering is pending because this sandbox lacks macOS window-server access. [Proof contract](proof_contract.json)

**Chosen defaults** · The witness reuses fixture 02 for the one-target case, fresh Snare generation for pre-battle, and the first Snare seal for a legacy-save case with two open targets.

**TODO_DESIGN placeholders** · None.

## Feedback 3 · Shared combat objective tooltip

- The combat objective hover now calls the same shared tooltip builder as the Battlefield hover. It uses the `objective` context with the current type ID, the shared inset frame and typography, and normal popup placement. The HUD title supplies the capitalized heading. [Combat objective builder](../../scripts/combat_objective_hud.gd#L61) · [Battlefield builder](../../scripts/battlefield_rule_hud.gd#L47) · [Shared tooltip builder](../../scripts/ui_tooltip_panel.gd#L23)
- `description_for_objective` appends the Wildfire line when it resolves Snare pressure. The combat objective hover requests only the objective sentence. Warband's appended Order follows the same rule. Last Light and the Hoarder keep their authored sentences. Pre-battle still uses the full description and adds the Snare reward line. [Description resolver](../../scripts/combat_objective_rules.gd#L284) · [Snare pressure source](../../scripts/snare_pressure_rules.gd#L8) · [Pre-battle builder](../../scripts/pre_battle_view.gd#L233)
- The witness checks the complete text of each shared popup. It also checks that Wildfire still appears on the Battlefield panel and that the pre-battle tooltip retains both the Wildfire sentence and the reward line. [Objective witness](objective_witness.gd)

### Verification

| Case | Popup title | Popup body |
| --- | --- | --- |
| Wildfire Snare | `REACH THE EXIT` | `Reach a marked tile to escape.` |
| Ordinary exit | `REACH THE EXIT` | `Reach a marked tile to escape.` |
| Defeat All | `DEFEAT ALL ENEMIES` | `Defeat each enemy.` |
| Defeat the Leader | `DEFEAT THE LEADER` | `Defeat the marked leader. The rest flee.` |
| Survive | `SURVIVE` | `Survive until the marked time.` |
| Last Light | `SURVIVE UNTIL DAWN` | `Survive until dawn.` |
| Hoarder | `DEFEAT THE HOARDER` | `Catch the Hoarder before it slips away.` |
| Warband | `DEFEAT THE RIME ORACLE` | `Defeat the captain to make each follower flee.` |

| Check | Result |
| --- | --- |
| [Native wrapper dry run](captures/dry.yQfXhe/runner.log) | `FEL08 DOOR WITNESS PASS combat=7 room=1 threshold=unchanged`<br>`FEL08 OBJECTIVE WITNESS PASS status_counts=1,2 fresh=true continued=true`<br>`FEL08 DRY RUN PASS pillars=2 controls=2` |
| [UI identity lint](captures/r3/ui_identity_lint.log) | `Ran 25 tests in 20.657s`<br>`OK` |
| [Rules text lint](captures/r3/rules_text_lint.log) | `Ran 3 tests in 0.075s`<br>`OK`<br>`PASS: Rules text lint (16 existing hits)` |
| [Pre-battle semantics](captures/r3/pre-battle-semantics.log) | `PRE-BATTLE SEMANTICS TEST: PASS`<br>`TEST RESULT: PASS` |
| [Snare UI](captures/r3/snare-ui.log) | `Snare UI/fixture suite: 0 failures` |

The Snare UI test exited 0 and Godot logged a shutdown warning about leaked ObjectDB instances and seven resources still in use. The native wrapper dry run exited 0 without those shutdown diagnostics.

### Proof for the design owner

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fel-08 && bash tools/fel08/native.sh
```

The existing proof contract requires `objective-one-exit.png` and `objective-two-exits-resumed.png` at 1920×1080 and 100% UI scale under `tools/fel08/captures/native.*/`. The command also refreshes the other accepted captures. Windowed capture is pending because this sandbox lacks macOS window-server access. [Proof contract](proof_contract.json)

**Chosen defaults** · The witness reuses the accepted ordinary and Wildfire Snare captures. The extra objective cases use the production HUD with representative objective dictionaries, including The Rime Oracle for Warband.

**TODO_DESIGN placeholders** · None.
