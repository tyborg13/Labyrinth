---
name: create-labyrinth-ui
description: Create, modify, refactor, or review player-facing UI for Escape the Umbra using the repository's game UI rubric and visual-proof workflow. Use for HUDs, combat feedback, cards, tooltips, rewards, merchants, loadouts, progression, map and room choices, dialogue, tutorials, settings, confirmations, menus, input/focus states, UI copy, accessibility, layout, and gameplay-signaling visual effects.
---

# Create Labyrinth UI

## Required workflow

1. Read `spec/game_ui_rubric.md` completely. Treat every acceptance row and automatic rejection tripwire as required unless the task records a specific Exception.
2. Rebuild the relevant context before designing:
   ```bash
   memento brief AGENTS.md spec/game_ui_rubric.md spec/ui_button_system.md scripts/ui_skin.gd scripts/ui_typography.gd scripts/ui_tooltip_panel.gd <changed-ui-paths> <relevant-probe-paths>
   ```
3. Classify the surface and write the rubric's design statement: player question, primary action, hierarchy/disclosure, interaction paths, and proof matrix.
4. Inspect the live surface, its component builders, and its existing visual probe. Reuse `UiSkin`, `UiTypography`, `UiTooltipPanel`, `CardWidget`, and established icon libraries where applicable. Extend shared components when the pattern recurs.
5. Implement for the player's decision, not for a generic app layout. Keep immediate state and actions scan-level; progressively disclose precise rules and optional detail.
6. Add or update a focused real-renderer probe. Capture fresh versioned images for the changed states, constrained and normal sizes, relevant UI scales, focus/input behavior, and reduced motion as required by the rubric.
7. Inspect the rendered images at exact resolution. Fix Fail rows before handoff; do not substitute code inspection or file-existence checks for visual review.
8. Include the rubric handoff record with the normal parallel-task proof and peer review. A visual UI task without screenshot proof is incomplete.

## Decision rules

- Keep exact card, relic, equipment, settings, accessibility, and detailed-inspection text when it is clearer than an unfamiliar symbol. Improve hierarchy before deleting necessary rules.
- Prefer an existing icon plus short label, meter, counter, state treatment, target preview, or contextual callout over instructional prose.
- Do not claim controller support or add fixed controller glyphs unless the task implements and proves the complete active-device and navigation path.
- Do not create one-off buttons, tooltips, typography scales, or panel languages when a shared system covers the need.
- Do not shrink type, hide the current decision, or cover gameplay evidence to make a layout fit.
- Use the `imagegen` skill for new raster UI art or icons when generation is appropriate; keep code-native shared controls code-native.

## Proof selection

- Start from a screen-specific probe when one exists.
- Use `tests/ui_probe.gd` for broad in-run UI coverage, `tests/button_system_probe.gd` for shared action states, `tests/settings_probe.gd` for scale/settings behavior, and `tests/tooltip_consistency_probe.gd` for shared tooltips.
- Run visual probes through `tools/visual_probe_runner.py` with the task id. Follow the isolated task workflow in `$parallel-labyrinth-task`.
- Add focused logic tests whenever clicks, focus, state transitions, persistence, affordability, targeting, or outcomes change. Screenshots and logic tests prove different things; use both when behavior and presentation both change.
