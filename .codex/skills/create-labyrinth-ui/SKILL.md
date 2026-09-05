---
name: create-labyrinth-ui
description: Create, change, or review Escape the Umbra player-facing UI, copy, input behavior, and gameplay visual feedback.
---

# Create Labyrinth UI

## Required workflow

1. Classify the changed surface and scope. Read the relevant `spec/game_ui_rubric.md` sections for focused edits; read the full rubric for broad screen or shared interaction changes. Apply every affected acceptance gate and rejection tripwire.
2. Inspect relevant component code and current presentation. Read `spec/icon_identity_policy.md` when creating or changing icon identities or registries; distinct concepts always require distinct purpose-built icons.
3. Write the rubric's compact design statement. For a focused edit, reuse existing context and describe the changed decision, presentation, and proof; broad changes need the full statement.
4. Inspect the live surface, its component builders, and its existing visual probe. Reuse `UiSkin`, `UiTypography`, `UiTooltipPanel`, `CardWidget`, and established icon libraries where applicable. Extend shared components when the pattern recurs.
5. Implement for the player's decision, not for a generic app layout. Keep immediate state and actions scan-level; progressively disclose precise rules and optional detail.
6. Add or update a focused real-renderer probe. By default, capture fresh versioned images only at `1920x1080` and `100%` UI scale for the changed states, focus/input behavior, and reduced motion required by the rubric. Add lower-resolution or alternate-scale runs only when the user or task explicitly requests them.
7. Inspect the rendered images at exact resolution. Fix Fail rows before handoff; do not substitute code inspection or file-existence checks for visual review.
8. Include the rubric handoff record with the normal parallel-task proof and peer review. A visual UI task without screenshot proof is incomplete.

## Decision rules

- Keep exact card, relic, equipment, settings, accessibility, and detailed-inspection text when it is clearer than an unfamiliar symbol. Improve hierarchy before deleting necessary rules.
- Give every distinct player-facing ability, relic, equipment item, keyword, status, and resource its own purpose-built icon asset. Reusing a generic icon, copying/recoloring another asset, or pointing distinct identities at the same path is a rejection, not a shortcut.
- For an existing concept, prefer its established icon plus short label, meter, counter, state treatment, target preview, or contextual callout over instructional prose.
- Preserve every input path the current surface supports. When controller or Steam Deck support is present, include focus traversal, activation, back/cancel, focus recovery, and input handoff where applicable. Prove those paths logically and capture their changed visual states at `1920x1080`/`100%` unless the task explicitly requests another display configuration; do not infer a handheld-resolution proof requirement from controller support alone.
- Do not claim an unsupported input path or add fixed device glyphs unless the task implements and proves the complete active-device and navigation path. Reuse the current device/glyph system when one exists.
- Do not create one-off buttons, tooltips, typography scales, or panel languages when a shared system covers the need.
- Do not shrink type, hide the current decision, or cover gameplay evidence to make a layout fit.
- Use the `imagegen` skill for new raster UI art or icons when generation is appropriate; keep code-native shared controls code-native.

## Proof selection

- Start from a screen-specific probe when one exists.
- Use `tests/ui_probe.gd` for broad in-run UI coverage, `tests/button_system_probe.gd` for shared action states, `tests/settings_probe.gd` for scale/settings behavior, and `tests/tooltip_consistency_probe.gd` for shared tooltips.
- Run visual probes through `tools/visual_probe_runner.py` with the task id. Follow the isolated task workflow in `$parallel-labyrinth-task`.
- Add focused logic tests whenever clicks, focus, controller/Steam Deck navigation, input handoff, state transitions, persistence, affordability, targeting, or outcomes change. Screenshots and logic tests prove different things; use both when behavior and presentation both change.
