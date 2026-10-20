# int-03 feedback 1 (director; Codex review of e78aaba78 requested changes)

Windowed targeting probe: all 8 states PASS on the native renderer, and they read correctly. The arrow is back on the
board after an invalid release and after the map, menu, Abilities and skill choice. Over the hand and the HUD, the
cursor shows and the arrow hides.

Director commits since your round (keep them):
- `88c850052`: the probe waits a frame for the cursor glyph before `CaptureViewport.setup`.
- `8d7c20bce`: glossary metadata says 19 words. That was the review's Low.

Fix these two Mediums. Focused tests only.

1. **The targeting-cache guards need permanent regressions.**
   - Two mutations survived the committed suite. Your temporary probe caught both.
     - Restoring the unconditional endpoint reset at `run_scene.gd:8217`.
     - Removing the selected-card guard in `card_empower_controller.observe_targeting_pointer`.
   - Add checks to `card_drag_play_suite.gd`. Each must fail under its mutation:
     - **(a)** while a modal is still open (map, menu, Abilities, skill choice), the selected card's endpoint survives;
       assert before closing, not after;
     - **(b)** after the card is played, cancelled, or the turn ends, further mouse motion does not repopulate the
       endpoint.
   - Report the mutation results.
2. **`pre_battle_living_foes_suite.gd` hard-codes today's roster.**
   - The fixed lists are at line 16, and the coverage is fixed at 43/41 at line 165.
   - Derive membership and totals from the canonical declarations: `Presentation.CREATURES` and the rig roster, plus
     `cutout_context.STATIC_ENEMY_TYPES`.
   - Keep an independent renderer-path oracle, so a wrong renderer still fails.
   - Adding a rig to `CREATURES` must not require a test edit.
