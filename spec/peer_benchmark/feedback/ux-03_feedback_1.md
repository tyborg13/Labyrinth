# ux-03 feedback 1 (director)

Reviewed the windowed captures (`relic_choice_hover`, `owned_relic_hover`). The mechanism and the card pixel identity are
right; keep them. Fix:

1. **Capture contract**: the probe captured the Retina root window (3024×1701), so every "Native 1920x1080 capture" check
   failed. Capture a 1920×1080 SubViewport (`render_target_update_mode = UPDATE_ALWAYS`, wait for `frame_post_draw`) like
   the other probes; never `root.get_texture()` (AGENTS.md / brief rule).
2. **Relic choice screen placement and content**:
   - The choice card already prints the relic's name and description, so on this screen the stack shows **only the
     glossary panels** (no relic name/description panel).
   - Place the stack on the **outer side** of the hovered card (left of the left card, right of the right card), top
     aligned with the card's top edge, 12 px gap, when at least the panel width plus 24 px is free on that side; for the
     middle card (or when the outer side lacks room) place it **below the card row**, centred under the hovered card,
     12 px gap. It must never cover any relic card, the "Claim your treasure" banner, or the hovered card.
3. **Owned relic tray placement**: the stack (relic name + description panel, then glossary panels) starts **below the
   tray**, 8 px under the hovered icon's bottom edge, left-aligned with the hovered icon (clamped to the screen), so it
   never covers the tray, the hovered icon or the room title.
4. **TODO_DESIGN_GLOSSARY_skill_point** → name `Skill Point`, definition: `Earned as you level up. Spend them on skills in
   the Character menu.`
5. **TODO_DESIGN_GLOSSARY_CONSUME_PROSE**: leave Briar Winch's current text unchanged; the director's text rewrite (ux-04)
   decides the wording. Keep it listed in the coverage report as known.
6. Re-run the probe's semantic checks and add assertions: no overlap between the tooltip stack and the hovered owner or
   (on the choice screen) any relic card; stack fully on screen.

Do not commit. List the windowed command again.
