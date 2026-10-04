# Unit 5: combat HUD second look

Target: `mockups/combat.jpg`. Today's screens: `baseline/combat_boss.jpg` and
`baseline/combat_your_turn.jpg`.

The board, cards, initiative rail, boss bar, objective dock, PASS plate and pile
icons are already in the visual language. The remaining boxes are generic squares
and plain labels at the edges.

Code:
- `scripts/run_scene.gd`:
  - the top bar (`StatsLabel`, `LoadoutButton`, `GrimoireButton`, `MenuButton`,
    and the section map button `_section_map_hud_button`);
  - the relic bar (`_refresh_relic_bar`, `_setup_relic_bar_layout`);
  - the intents toggle (`_enemy_intent_toggle_button`).
- `scenes/run_scene.tscn`.

## Change

1. **HUD buttons.** The map, character, grimoire and menu/settings buttons
   become unit 0 sockets:
   - size 58 px, with the approved medallion ring;
   - they keep their existing icons (tinted slightly warm if the icon reads cold
     on bronze);
   - they keep their order, spacing (about 12 px) and screen position.
   - Behaviour stays exactly the same: tooltips, the notification dot (move it
     to the socket's top-right rim), hotkeys, focus and disabled states.
   - **Hotkey hint:** show a small key cap on the rim (UI 12, `INK_2` fill,
     `GOLD_DIM` border) only if the active input is keyboard/mouse and the
     action actually has a key binding. Otherwise omit it, and use no device
     glyphs that the active-input system doesn't support.
2. **Level and embers** (`StatsLabel`). Replace `LV 1 EMBERS 0` with a compact
   stack left of the sockets:
   - an eyebrow `LEVEL 1` (letter-spaced 12 px, `TEXT_2`);
   - under it, the ember icon (20 px) plus the value (UI 22, `GOLD_BRIGHT`).
   - Keep the label's tooltip, unread state and any tests' text expectations
     (update tests deliberately).
3. **Relic bar.** Each relic becomes a 48 px unit 0 socket holding the relic icon.
   - Charge counts use the socket badge.
   - Keep the bar's layout logic (wrapping, first-row bottom, and the visible
     bottom used by other HUD placement), tooltips, inspection, NEW/highlight
     glow and the click/hover behaviour.
   - Ability chips that share the bar keep their content but use the same
     socket ring.
4. **Intents toggle.** Restyle `INTENTS [I]` / `INTENTS ON [I]` as a small ink
   plate (UiSkin quiet button):
   - the vision icon (`assets/art/icons/vision.png`, 20 px), then `Intents`
     (UI 15), then the key letter in `TEXT_3`;
   - the ON state shows the ember underline and a brighter gold border.
   - Keep the toggle behaviour, the text for screen readers/tests (update tests
     deliberately) and its placement under the rail.

## Keep

- **Everything else on the screen:** the board and cards, initiative rail, boss
  bar, objective dock, PASS plate and pile icons.
- **Layout:** the top HUD scrim and safe margins.

## Proof

- **Probe:** update `tests/beautify_feel_probe.gd`, or add a focused
  `tests/combat_hud_sockets_probe.gd`.
- **Fresh 1920×1080 screenshots** of:
  - normal combat;
  - boss combat with 7+ relics (wrapping);
  - a relic with a charge badge;
  - hovering or focusing a HUD socket;
  - the notification dot;
  - intents on and off;
  - the map room view (the section map button);
  - reduced motion.
- **Tests:** keep the HUD layout tests green (relic bar bottom, safe margins,
  scrims).
