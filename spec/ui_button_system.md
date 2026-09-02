# Themed Button System Inventory

The shared action-button system is code-native. `scripts/ui_skin.gd` builds every interaction state from scalable `StyleBoxFlat` borders, corners, shadows, and symmetric content margins. `scripts/themed_button_ornament.gd` adds resolution-independent brass inlay, corner cuts, rivets, ember accents, and keyboard-focus brackets without accepting input.

The removed bitmap families were the three `button_wood_gold_*` planks and the eight `progression_command_*` / `progression_stepper_*` state images. `tests/test_button_system_inventory.py` fails if any removed asset returns or any player-facing script, scene, or theme references one.

## Player-facing inventory

| Surface | Construction after replacement | Variant/state use |
| --- | --- | --- |
| Main menu and saved-run replacement prompt | `UiSkin` through `scripts/main_menu.gd`; the main action stack uses the code-native Umbra Obsidian variant while confirmation actions remain in the shared large/destructive family | dark-fractured idle slabs, one ember-fractured primary/hover/focus choice, disabled, pressed, destructive confirmation |
| Settings in main menu and in-run camp menu | `UiSkin` through `scripts/settings_panel.gd` | centered standard `OptionButton`, selected toggle state, compact cancel, destructive restore, standard back |
| Run header | `UiSkin` through `scripts/run_scene.gd` | square icon variant for Grimoire and Menu |
| Combat action area | `UiSkin` through `scripts/run_scene.gd` | large Pass; compact Rotate, Skip, and Cancel |
| Contextual combat tutorial | `UiSkin` through `scripts/contextual_combat_prompt.gd` | compact Grimoire, Got it, and Skip |
| Pre-battle | `UiSkin` through `scripts/run_scene.gd` | standard Equip and selected primary Start |
| Camp/menu, dialogue, map, pile, and upgrade overlays | `UiSkin` through `scripts/run_scene.gd` | standard commands, large room choices, destructive abandon, square close icons |
| Merchant and dense progression controls | `UiSkin` through `scripts/run_scene.gd` | compact Buy/Sell and stepper controls; standard and selected progression commands |
| Reward/treasure selection | Card/relic choice controls remain authored selection objects; supporting context actions use shared large buttons | selected cards/relics are not stretched action-button bitmaps |
| Run-end recap | `UiSkin` through `scripts/run_end_recap_overlay.gd` | large New Run and Main Menu |
| Death engulf continuation | `UiSkin` through `scripts/death_engulf_overlay.gd` | selected primary Begin Again |

## Intentional exclusions

- `CardWidget` remains a card-shaped `Button` with its own card-frame texture; it is not an action-button skin.
- Grimoire page navigation remains a parchment list treatment, not a command button.
- Panel textures such as `panel_wood_parchment.png` remain panel-only and are never used as button states.
- Styling never assigns focus neighbors, focus modes, controller bindings, remapping, device glyphs, or input actions.

## Proof routes

- `tests/button_system_probe.gd`: real-renderer galleries at 100% and 125%, covering every shared variant and interaction state.
- `tests/settings_probe.gd`: centered Settings controls at 100% and 125% in both menu and run contexts.
- Existing `ui_probe`, contextual tutorial, pre-battle, map, reward, and run-end probes provide representative screen coverage.
- `tests/run_tests.gd` covers variant construction, native proportions, style states, centered margins, and preservation of focus traversal properties.
