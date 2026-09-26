# Themed Button System Inventory

The shared action-button system is code-native. `scripts/ui_skin.gd` builds every interaction state from scalable `StyleBoxFlat` borders, corners, shadows, and symmetric content margins. `scripts/themed_button_ornament.gd` adds resolution-independent brass inlay, corner cuts, rivets, ember accents, and keyboard-focus brackets without accepting input.

The removed bitmap families were the three `button_wood_gold_*` planks and the eight `progression_command_*` / `progression_stepper_*` state images. `tests/test_button_system_inventory.py` fails if any removed asset returns or any player-facing script, scene, or theme references one.

## Player-facing inventory

| Surface | Construction after replacement | Variant/state use |
| --- | --- | --- |
| Main menu and saved-run replacement prompt | `UiSkin` through `scripts/main_menu.gd`; the main action stack uses the code-native Umbra Obsidian variant while confirmation actions remain in the shared large/destructive family | dark-fractured idle slabs, one ember-fractured primary/hover/focus choice, disabled, pressed, destructive confirmation |
| Settings in main menu and in-run camp menu | `UiSkin` through `scripts/settings_panel.gd` | centered standard `OptionButton`, selected toggle state, compact cancel, destructive restore, standard back |
| Run header | `UiSkin` through `scripts/run_scene.gd` | square icon variant for Map, Character Loadout, Grimoire and Menu |
| Combat action area | `UiSkin` through `scripts/run_scene.gd` | large Pass; compact Rotate, Skip, and Cancel |
| Guided first-run tutorial | `UiSkin` through `scripts/contextual_combat_prompt.gd` | spotlight callout with compact Continue and Skip Tutorial actions; Camp has no persistent tutorial-management buttons |
| Pre-battle | `UiSkin` through `scripts/run_scene.gd` | standard Equip and selected primary Start |
| Camp/menu, dialogue, map, pile, and upgrade overlays | `UiSkin` through `scripts/run_scene.gd` | standard commands, large room choices, destructive abandon, square close icons |
| Merchant and dense progression controls | `UiSkin` through `scripts/run_scene.gd` | compact Buy/Sell and stepper controls; standard and selected progression commands |
| Reward/treasure selection | Card/relic choice controls remain authored selection objects; supporting context actions use shared large buttons | selected cards/relics are not stretched action-button bitmaps |
| Graftwright workbench | Native Buttons with purpose-built equipment cradles, real CardWidgets, and a needle-and-thread ritual clasp | role-colored selection, hover lift, focus brackets, disabled state; category grid and quiet Back/Leave |
| Scavenger shop | Native Buttons with scene-specific leather-and-brass trade clasps, filtered pack trays and shaded text | pointer lift/press, selected mode underline, native focus, unaffordable and reduced motion |
| Run-end recap | `UiSkin` through `scripts/run_end_recap_overlay.gd` | large New Run and Main Menu |
| Death engulf continuation | `UiSkin` through `scripts/death_engulf_overlay.gd` | selected primary Begin Again |

## Intentional exclusions

- `CardWidget` remains a card-shaped `Button` with its own card-frame texture; it is not an action-button skin.
- Graftwright is an intentional material-specific exception requested during visual review. Its mounts and cards are selection objects; its ritual clasp is unique encounter art. It preserves native input/focus while using empty button StyleBoxes so no shared action plate appears behind these objects.
- Scavenger is a user-requested material-specific exception, like Graftwright. Its authored atlas, object trays and trade clasps preserve native input and use empty button styles, with the same shaded text treatment as Graftwright.
- Grimoire page navigation remains a parchment list treatment, not a command button.
- Panel textures such as `panel_wood_parchment.png` remain panel-only and are never used as button states.
- Styling never assigns focus neighbors, focus modes, controller bindings, remapping, device glyphs, or input actions.

## Proof routes

- `tests/button_system_probe.gd`: real-renderer galleries at 100% and 125%, covering every shared variant and interaction state.
- `tests/settings_probe.gd`: centered Settings controls at 100% and 125% in both menu and run contexts.
- Existing `ui_probe`, contextual tutorial, pre-battle, map, reward, and run-end probes provide representative screen coverage.
- `tests/run_tests.gd` covers variant construction, native proportions, style states, centered margins, and preservation of focus traversal properties.

## Hover and navigation sound

Shared `UiSkin` buttons and the Graftwright/Scavenger native choices use the
approved Ember Hearth focus cue: the same 120 ms cloth tick at -17 dB, routed
through the dry UI SFX bus and the player's SFX/master controls. The existing
Hearth choices keep their reveal-aware feedback. Cards in combat, passive
inspection/tooltip surfaces, and board tiles do not acquire button sounds.

`UiButtonFeedback` binds once per button. Pointer hover and keyboard/controller
focus form one highlight, so clicking an already hovered control or restyling it
does not replay the cue. Hidden and disabled controls remain silent. The shared
cursor feedback owner limits focus playback to one voice with an 80 ms minimum
interval and keeps it separate from action-confirmation audio. Binding does not
change any focus mode, neighbor, action, or input-device behavior.

Design statement: This extends the established action-button feedback across
title/confirmation, Settings, in-run commands and merchant choices. The player's
current action and its existing visual hierarchy remain unchanged; the sound
confirms reaching an available control via pointer or navigation. No copy, icon,
layout or motion changes are introduced. Proof uses focused input/audio checks
and fresh menu, Settings and in-run screenshots at 1920×1080 / 100% UI scale,
plus the full runtime regression suite and a verified pre-choice Hearth save.

Hover-feedback proof routes:

- `tests/ui_button_feedback_test.gd` and its full-suite entry exercise pointer,
  native keyboard/controller navigation, click deduplication, restyling,
  disabled/hidden controls, fast crossings, merchant families, scene disposal,
  the exact shared waveform/gain and player SFX mute.
- `tests/ui_hover_sfx_probe.gd` with `tests/ui_hover_sfx_probe_contract.json`
  captures five native 1920×1080 / 100% frames: title hover, Settings keyboard
  focus, title controller focus, Hearth header hover and the open in-run menu.
  The probe also asserts cue counts, native activation and pointer handoff.

Rubric record for this audio-only extension: immediate comprehension, visual
hierarchy, gameplay visibility, precise copy, state/consequence, interaction
completeness, visual cohesion, accessibility, layout resilience and visual proof
are **Pass**. Existing visible states remain intact; audio is supplementary and
respects SFX/master settings. The five real-renderer frames were inspected at
native resolution. There are no new icons, text, motion, layouts or input paths.
Physical controller hardware and Windows exports remain outside this proof.
