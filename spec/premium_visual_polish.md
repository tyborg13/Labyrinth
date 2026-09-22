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


## Grimoire focus checkpoint

The Grimoire focuses its search field for immediate typing, but closing it by pointer must not reapply native focus to the opener after the pointer has left. Track pointer/touch versus keyboard/controller dismissal while the modal is open. Pointer dismissal leaves the closed opener idle; keyboard/controller dismissal restores its navigation return point. Opening/search focus, real hover, geometry, labels and controller recovery remain unchanged.

`tests/grimoire_focus_return_probe.gd` exercises native pointer Close and scrim dismissal, keyboard cancel and activation, controller cancel, controller-to-pointer handoff, and renewed hover. Run its logic headlessly and inspect its native 1920×1080/UI100 captures; existing Grimoire search proof still covers search and rebuilt-row navigation. This focused checkpoint affects state/consequence, interaction completeness, accessibility and visual proof; the existing full rubric record otherwise remains applicable.


## Second finish pass: card elevation, choices and pickups

The follow-up pass extends the approved finish to three remaining surfaces. The player's question and primary action remain the same: which card/choice is active, or which item can be collected. Existing board framing, control positions, authored card/choice/pickup art, exact rules and all character/cutout animation stay unchanged. Rarity and destructive accents remain semantic; perimeter light and depth stay beneath or outside readable content. Pointer, native keyboard/action focus and controller paths remain supported, with static final feedback under Reduced Motion.

- **Relic and campfire choices:** `UiSkin.apply_choice_finish` reuses the retained `SurfaceFinish` under content. A fine rarity-colored rim, shallow facets, upper reflection and dark underside replace the uniformly thick outline. This adds no processing, input or layout participation. Campfire hover and focus are tracked separately so a pointer departure cannot erase keyboard focus emphasis.
- **Cards:** retain the authored faces and existing pose/timing while strengthening elevation and restricting a brief material reflection to the frame. Reduced Motion settles the material response and existing clock/ready movement.
- **Pickups:** replace nested diamond beacons and broad copied-texture halos with soft floor light, thin interrupted corners and tighter edge light. Existing rarity, item/equipment size ratio, bob/pulse, contact shadow, hover geometry and acquisition destinations remain authoritative.

The focused second-pass proof routes are `tests/choice_material_polish_probe.gd`, `tests/premium_card_material_probe.gd` and existing hand-focus probes, `tests/equipment_pickup_visibility_probe.gd`, and `tests/item_pickup_probe.gd`. Compare native 1920×1080/UI100 before/after captures; assert retained hit/layout bounds, focused and unavailable states, Reduced Motion, normal collection rules and resolved actions. The choice probe additionally checks real hover, keyboard focus through pointer departure and native keyboard activation of healing. Full regression and independent review cover the combined branch before its refreshed inspection fixture is handed off.

All ten rubric gates remain applicable: existing object/action identity and hierarchy are preserved; localized edge effects preserve gameplay visibility; no copy/icon changes; normal/focus/hover/unavailable states remain distinct; native interaction is verified; shared materials maintain cohesion; Reduced Motion and exact text remain accessible; retained decorative nodes preserve layout; and fresh real-renderer proof is required for each changed surface. Record final evidence and any exceptions in the inspection handoff.


## Follow-up: pickup presence and room presentation

The targeted follow-up makes available pickups identifiable from the start of combat using a low, translucent raised light rim around their tile. Object silhouettes, item/equipment proportions, rarity, hit geometry and collection consequences remain authoritative. Treasure room entry shows the chest opening before offering relics; after a choice, delivery and the existing destination settle finish before the route map appears. Campfire actions keep their labels, costs, positions and input paths while removing the expanded duplicate outer frame and replacing the old backing art with three matching production-protagonist illustrations.

The player's question remains which pickup or room action is available, and what happened after choosing it. Hierarchy puts the object and exact action/cost ahead of decorative light; no new instructional copy or icons. Reuse the existing choice finish, item rendering, reward delivery, persistence and navigation machinery. All supported pointer, keyboard/controller focus, activation, cancellation and input handoff must remain complete; Reduced Motion gets clear static presentation and a short reveal.

Proof covers fresh 1920×1080/UI100 pickup visibility in lit and dark rooms, normal/hover/focus/disabled campfire actions, chronological chest/relic/map states, input gating, interruption/cleanup and Reduced Motion. All ten UI rubric gates apply. No character/cutout animation is modified; the chest is a separately authored rigid prop explicitly requested for this follow-up. Campfire image provenance and built-in generation prompts are in `spec/campfire_art_v2.md`.
