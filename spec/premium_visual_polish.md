# Premium presentation finish

The September 2026 polish pass preserves authored layouts, gameplay rules, the room-lighting presets, and all character/cutout animation. It closes material and response gaps between the richly authored cards/board and simpler secondary surfaces.

## Design contract

- **Surfaces:** elemental cast and chain contacts; shared action-button edges; menu, tooltip and HUD panel wells; Grimoire parchment.
- **Player question:** what is active, what is affected, and what can I do next?
- **Primary action:** the existing card, target, menu action, or Grimoire selection. No new controls or instructional copy.
- **Hierarchy:** combat geometry and card faces remain primary. Light is localized to contact or the active control; secondary panel interiors stay quiet beneath text.
- **Interaction paths:** preserve native pointer and keyboard/controller focus/activation, back/cancel, and existing device handoff. Decorative nodes have no input or layout role.
- **Proof:** real Metal-renderer screenshots at 1920×1080, 100% UI scale; native normal/hover/focus/pressed/disabled states, elemental contact/decay, and reduced motion. Full regression suite plus focused semantic probes.

## Materials and motion

`UiSkin` owns `ui_surface_finish.gd` application. The retained `Node2D` draws before panel contents, participates in neither minimum-size calculation nor input, and adds no frame processing. Dark surfaces receive a slight warm upper reflection, a shaded lower well, and a quiet inner lip. Existing panel fills, frame art, margins, typography, and geometry remain authoritative.

Grimoire leaves use the same finish helper with restrained, shared procedural paper grain, broad reflected light, binding-side shade, and fine bottom leaf edges. Text is painted afterward and retains its original contrast and metrics. Grain is deterministic, seamlessly tiled, cached once, and warmed during hidden Grimoire construction, with no animation or per-page image allocation.

Elemental and action-edge motion uses the existing semantic event as its trigger. New motion must finish into a stable static state, stop requesting redraws when settled, and respect Reduced Motion. No looping decorative shimmer, global brightness increase, screen flash, camera movement, or character changes belong to this pass.

## Visual references

The audit inspected [Mega Crit's Slay the Spire 2 combat screenshot](https://www.megacrit.com/images/steam_screenshot1_new.png), [Monster Train 2's official gallery](https://store.steampowered.com/app/2742830/Monster_Train_2/), and [Into the Breach's official gallery](https://store.steampowered.com/app/590380/Into_the_Breach/). The transferable principles are clear active-edge hierarchy, consistent material depth, and local effects that preserve gameplay evidence. Screenshots do not establish animation timing.

## Verification routes

Run Godot through `tools/godot_task_runner.py` and visual scripts through `tools/visual_probe_runner.py`, with the isolated task id. The relevant commands are:

- `tests/run_tests.gd`: full gameplay, save, controller/input, shared UI and content regression suite.
- `tests/premium_button_probe.gd`: authored-size state gallery and native pointer, held activation, focus traversal, stable hit geometry, disabled/hidden/idle, reduced motion and applied preference semantics.
- `tests/ui_material_polish_probe.gd`: production Grimoire card/rules/equipment pages, menu/focus/reduced states, and visible tooltip; verifies that material visibility cannot affect panel layout or focus.
- `tests/grimoire_search_probe.gd`: search, selection, keyboard focus and restored browsing in the finished parchment surfaces.
- `tests/ui_probe.gd`: integrated combat, pre-battle, reward, map, menu, progression and end-state captures.
- `tests/elemental_spell_fx_test.gd`, `tests/elemental_spell_effects_probe.gd`, `tests/chain_attack_visual_probe.gd`, and `tests/elemental_aoe_attack_visual_probe.gd`: spell endpoints, all five contact/tail signatures, depth, multi-target casts, live chain contact ordering and reduced motion.
- `tests/elemental_spell_geometry_equivalence_probe.gd`: strict historical equivalence of the unchanged primitives. The former generic ground arcs were deliberately replaced; their new appearance is proved by production spell captures. The frozen optimization fixture and pixel tolerances remain unchanged.
- `tests/ui_skin_performance_test.gd` and `python3 tests/test_button_system_inventory.py`: shared immutable styles, bounded resource reuse and button inventory.

The chain visual probe's old expectation that a neighboring crate would be destroyed was stale before this pass: current traps damage only their center tile. The probe now checks that the adjacent crate remains present and intact throughout playback and never emits a destruction animation. No combat rule changed.

## UI rubric record

| Gate | Result | Evidence / rationale |
| --- | --- | --- |
| Immediate comprehension | Pass | Existing actions, card faces and target geometry preserved; stronger control edge response. |
| Visual hierarchy | Pass | Local contact and active edges carry highlights; dark panel centers stay subordinate. |
| Gameplay visibility | Pass | Bounded floor details and chain filaments preserve actors, tile boundaries and damage text; depth/clearing captures. |
| Compact, precise copy | Pass | No player-facing copy changed. |
| State and consequence | Pass | Native normal, hover, focus, held press, selected, destructive and disabled states remain distinct. |
| Interaction completeness | Pass | Native focus traversal and activation, Grimoire search/return, and full controller/input suite remain intact. Decorative nodes do not receive input. |
| Visual cohesion | Pass | Shared UiSkin, existing raster frames, typography, icons and material palette extended. |
| Accessibility | Pass | Existing geometry and text metrics preserved; reduced motion has static final feedback and cancels new glints. |
| Layout resilience | Pass | Fresh 1920×1080/UI100 production captures; no new layout participation or minimum-size changes. |
| Visual proof | Pass | Native Metal captures with semantic assertions; before/after and final pixel inspection. |

Routine proof is limited to the requested 1920×1080/UI100 target. Windows hardware and additional display configurations are outside this pass; new typed assignments follow the cross-platform GDScript policy. The unchanged full suite may emit its existing ObjectDB cleanup warning after passing.
