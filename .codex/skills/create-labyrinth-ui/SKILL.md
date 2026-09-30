---
name: create-labyrinth-ui
description: Create, change, or review Escape the Umbra player-facing UI, copy, input behavior, and gameplay visual feedback.
---

# Create Labyrinth UI

## Workflow

1. Look at the live surface first: run its existing probe (or `tests/ui_probe.gd`) and inspect the current screenshots before changing anything.
2. Build from the shared visual language in `spec/visual_design_system.md`: `UiPalette`, `UiGildedFrame`, `UiSkin`, `UiTypography`, `UiTooltipPanel`, `CardWidget`, and the existing icon libraries. Extend a shared component when a pattern recurs instead of creating a one-off.
3. Design for the player's decision on that screen: make the current state and the primary action obvious, keep the board and cards visible, and keep exact rules text precise.
4. Add or update a focused real-renderer probe. Capture fresh images only at `1920x1080` and `100%` UI scale for the changed states, including focus/input states and reduced motion where relevant. Add other resolutions or scales only when the user or task asks.
5. Inspect the rendered images at full resolution and fix what looks wrong. Screenshot proof is required for visual work; code inspection or file existence is not a substitute.
6. Hand off with the normal parallel-task proof and peer review.

## Guardrails

- Preserve every input path the surface already supports (pointer, keyboard, controller/Steam Deck), including focus, activation, and back/cancel. Do not add device glyphs the active-input system does not support.
- Distinct player-facing concepts need distinct, purpose-built icons; follow `spec/icon_identity_policy.md`.
- Do not shrink text below the shared typography floors or hide the current decision to make a layout fit.
- Avoid decorative taglines and free-floating explanatory copy; anchor text to the object, state, or action it describes.
- Use the `imagegen` skill for new raster UI art when generation is appropriate; keep shared controls code-native.
- Add focused logic tests when clicks, focus, navigation, state transitions, persistence, or outcomes change. Screenshots and logic tests prove different things.
