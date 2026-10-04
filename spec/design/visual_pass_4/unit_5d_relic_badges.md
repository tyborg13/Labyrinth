# Unit 5d: relic badges back to frames, on a pool of accent light

**Owner feedback:**
- The bronze socket rings, and especially the rarity ring added inside them, cover the relic art.
- Go back to master's square relic badges, but make their background nicer than the dull flat fill.

**Target:** row C ("accent-tinted velvet") in `mockups/relic_badge_backgrounds.jpg`. The owner chose C on 2026-10-04. Row A is master as it is today; B and D were the other options.

## Change

1. **Restore master.** The relic bar badges go back to master's structure and behaviour exactly:
   - relic badges, rite badges, the Defiance badge, and skill-sigil previews where they lived in the relic bar;
   - `TooltipPanelContainer` frames sized to `RELIC_BADGE_SIZE`;
   - a 2 px accent border from `GameData.relic_accent(relic_id)` (rites and Defiance keep master's border colours), with master's corner radius and shadow;
   - the icon fills the frame with master's 5 px margin, nothing drawn over it;
   - tooltips, `CURSOR_HELP`, focus and controller candidacy;
   - Stored Time / `RelicTimeReserve`, `RelicStoredSurface_N` pips, `RelicKnots`, the spent fade with "Used this combat.", charge counters, and skill-sigil status borders.

   Use master's `scripts/run_scene.gd` relic-bar code as the reference. Keep the dialogue-input fix: master's frames aren't buttons, so it should simply no longer apply.
2. **The only visual change from master is the fill:**
   - It is an accent-tinted velvet behind the icon, inside the rounded rect.
   - For each pixel at normalised position `(u, v)` in 0..1 across the badge, with `d` the normalised distance from the centre `(0.5, 0.46)`:
     - `t = max(0, 1 - d / 1.1)`
     - `colour = (22/255 + accent * 0.18) * (0.55 + 0.6 * t) + (40/255) * 0.25 * (1 - v)`
   - In words: a dark ground tinted by the relic's accent, brighter toward the centre, with a soft lift toward the top. There is no catchlight arc.
   - Render this as a texture cached statically per accent colour (and per scale), or as a shared shader. There must be no per-frame cost and no per-badge image generation.
3. **Clean up.**
   - Delete socket-only code that is now unused: the accent and status ring properties in `ui_socket.gd` if nothing else uses them, `combat_hud_socket.gd`, and the `combat_hud_relics.gd` builders.
   - Keep the sockets used by the character menu and pre-battle kit.
   - Restore master's tests for these badges.
   - Remove tests that only covered the socket versions.

## Proof

- Real renderer at 1920×1080:
  - boss combat with mixed-rarity relics, rites, a charged relic and spent Defiance;
  - `relic_u4_probe`, `relic_u7_probe` and `dragon_trophy_feedback_probe` pass.
- Add an assertion that badge background textures are shared per accent.
- Full suite green.
