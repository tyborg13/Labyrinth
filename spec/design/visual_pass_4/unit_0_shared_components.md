# Unit 0: shared components

Build the small component vocabulary that units 1–5 reuse. Nothing player-facing
changes in this unit except a new gallery probe; later units adopt the parts.

Reference look: `mockups/prebattle.jpg` (kit column, foes), `mockups/character.jpg`
(stat chips, sockets, card strips), `mockups/combat.jpg` (relic sockets).

## Assets (already approved; process, don't redraw)

Approved paintings live in `spec/assets/visual_pass_4/sources/` (see the README
there for prompts and hashes). Write `tools/process_visual_pass_4_assets.py`
(model it on `tools/process_card_time_watch.py` and
`tools/process_turn_order_brushes.py`) that produces:

- `assets/art/ui/visual_pass_4/medallion_ring.png`: chroma-keyed (green → alpha,
  colour un-mixed from the green, no fringe), cropped to the ring with a small
  margin, downscaled with premultiplied alpha to 256 px. Also write
  `medallion_ring.json` with the ring's outer radius and inner (opening) radius
  in output pixels, measured from the alpha mask.
- `assets/art/ui/visual_pass_4/ink_pool_a.png`, `ink_pool_b.png`: white-on-black
  source → pure white RGB with the painting carried in alpha (luminance levels as
  in the brush tool), cropped, 768 px wide.
- `assets/art/ui/visual_pass_4/price_tag.png` (keyed like the ring, 256 px tall);
  unit 3 uses it.

Add `tests/test_visual_pass_4_assets.py` that checks the processed files exist,
have alpha, the JSON matches the ring PNG, and the source hashes match the README.

## Components (new scripts under `scripts/`, preload-style like `ui_gilded_rule.gd`)

All sizes below are layout pixels at 100 % UI scale; scale them with
`UiTypography.scaled_value` like the existing widgets. Colours are `UiPalette`
tokens. Fonts are `UiTypography.ui_font()` / `apply_eyebrow()`.

1. **`ui_section_header.gd`** (Control, height 22):
   - An eyebrow label in `GOLD`, size 15, letter-spaced as `apply_eyebrow`.
   - An optional count label in `TEXT_2`, size 15.
   - A 1 px rule from `GOLD_DIM` fading to transparent, filling the remaining width.
   - API: `setup(title, count_text := "")`.

2. **`ui_socket.gd`** (Control, default 50×50; square):
   - **Ring:** draws the approved medallion ring texture scaled to the control.
   - **Inside the ring:**
     - A radial fill from `INK_3` (centre, offset up-left) to `INK_0`.
     - The icon centred, filling 92 % of the measured ring opening using the
       JSON's inner/outer radius ratio. Cache runtime ring geometry and crop
       pixel-art icons to their opaque bounds once per texture. Pixel-art icons
       use nearest filtering; the ring uses linear-with-mipmaps.
   - **States:**
     - *normal:* `ring_tint` defaults to `Color(1.14, 1.06, 0.96, 1)` (the v2 ring art is already dark antique bronze).
     - *hover/focus:* the ring tint is `Color(1.5, 1.36, 1.12, 1)`, with a
       soft `EMBER` glow behind it (alpha 0.55).
     - *selected:* adds a 2 px `GOLD_BRIGHT` inner ring.
     - *empty:* no icon; the ring is drawn at 45 % alpha with a faint dashed
       inner circle.
     - *disabled:* the ring tint is `Color(0.72, 0.68, 0.62, 1)` and the icon
       is desaturated to 35 %.
   - **Badge:** an optional bottom-right badge (a small rounded pill: `INK_2`
     fill, 1 px `GOLD` border, UI 13 px `GOLD_BRIGHT` text) for charges/counts.
   - **API:** `setup(icon: Texture2D, tooltip := "", badge := "")`, a `pressed`
     signal, and focus mode ALL when interactive. It must support mouse, keyboard
     and controller activation like existing `Button`s; build it on `Button` or
     `BaseButton` with an empty stylebox.

3. **`ui_stat_chip.gd`** (Control, height 44, width fits content):
   - A pill: a vertical gradient `INK_2`→`INK_1`, a 1 px `GOLD` border at 35 %,
     fully rounded ends.
   - A 30 px socket at the left (reuse `ui_socket.gd`, non-interactive) holding
     an icon.
   - A value label (UI 22, colour param, default `GOLD_BRIGHT`), then the
     letter-spaced caption (13, `TEXT_2`) on the same baseline.
   - API: `setup(icon, value_text, caption, value_color := GOLD_BRIGHT)`.

4. **`ui_card_strip.gd`** (Button-based, height 30, width from container):
   - **Left:** the card's art (the same art path `CardWidget` uses) as a 54×30
     thumbnail, cover-cropped. Its right 30 % fades to transparent so it melts
     into the strip.
   - **Name:** UI 15 `TEXT`, 8 px left padding, ellipsis only if truly needed.
   - **Count:** an optional "×N" at the right, UI 14 `GOLD_BRIGHT`.
   - **Background:** a horizontal gradient `INK_3` (95 %) → `INK_1` (92 %), a
     1 px `GOLD` border at 25 %, 2 px radius.
   - **States:**
     - *hover/focus:* the border goes to `GOLD_BRIGHT` at 70 %, with a faint
       `EMBER` outer glow.
     - *selected:* a 2 px `EMBER` underline.
     - *locked/disabled:* the art is desaturated and the name is `TEXT_3`.
   - **Signals:** `pressed`, plus `hovered(card_id)` / `unhovered(card_id)`, so
     callers can keep their existing card inspection/tooltip behaviour.
   - **API:** `setup(card_id, display_name, count := 1, card_override := {})`.

5. **`ui_ink_pool_stage.gd`** (Control, ignores mouse). Draws behind a standing
   figure:
   - A warm spotlight: a radial gradient centred at 62 % height, colour
     `Color(0.59, 0.36, 0.19, 0.22)` fading to 0 at 70 % of the radius.
   - The ink pool texture (variant a/b selectable), tinted `Color(0.02, 0.012,
     0.01, 0.9)`, placed at the figure's feet. Its width is about 92 % of the
     figure width and its height about a quarter of that.
   - Feet anchor and pool size are exposed as properties.

## Proof

- `tests/ui_components_gallery_probe.gd`: six real-renderer captures from a
  fixed 1920×1080 SubViewport (never the root window texture), showing a gallery
  on the warm `INK_0` backdrop with:
  - every component and every state (normal, hover, focus, selected, empty,
    disabled);
  - sockets at 30, 50 and 62 px;
  - strips with and without a count, plus one long name;
  - three stat chips;
  - ink pool stages a and b under an enemy sprite (`assets/art/enemies/grave_surgeon.png`).
- Unit tests for API behaviour: socket and strip signals, keyboard activation,
  and badge visibility.
