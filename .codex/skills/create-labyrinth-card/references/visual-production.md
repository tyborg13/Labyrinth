# Visual Production

## Table Of Contents

- Card art assets
- Generation prompt
- Background removal and sizing
- Frames, rarity, and elements
- Names and icon layout
- Visual validation

## Card Art Assets

Current card art files are all:

- Path: `assets/art/cards/<card_id>.png`
- Data path: `res://assets/art/cards/<card_id>.png`
- Size: `256 x 144`
- Format: PNG RGBA
- Shape: transparent ragged art window with clear alpha at the corners; never an opaque black/full-bleed rectangle.

Action and element icons are `64 x 64` PNG RGBA in `assets/art/icons`. Card frame assets are `256 x 352` PNG RGBA in `assets/art/ui`.

CardWidget loads `art_path` into a `TextureRect` with `STRETCH_KEEP_ASPECT_COVERED`, clips the art frame, and dynamically sizes the art band between roughly 68 and 118 px tall depending on card size. At normal card size the rendered art slot is wider than `256 x 144`, so Godot crops a little vertical content. Keep focal subjects inset from the top and bottom, and do not rely on full-bleed edge detail.

The character menu reuses the same `art_path` for compact card identity badges:

- Gear/Magic deck badges and Magic loadout tiles do not have separate art files.
- `RunScene` fills the badge with a muted card-art-background gradient, adds a dim overscanned copy of the same art behind the sharp crop, overlays blended shadow/tint ramps, then renders the card name on top. Do not add separate hard left/bottom accent strips or visible horizontal bands; the badge border carries the explicit accent color.
- Keep a recognizable silhouette, motion streak, elemental cue, or material texture in the central horizontal band of the card art. A good practical safe zone is roughly source `y=48..96`; tiny badge crops often show only this middle slice.
- Avoid placing the only readable subject detail solely at the top, bottom, or far corner of the `256 x 144` art. The full `CardWidget` can still look good while the character-menu badge reads as blank if the center band is empty.

## Visual Asset Rule

Final card art, action icons, element icons, and other card-facing raster visuals must be produced through the `imagegen` skill using existing Labyrinth assets as style references. Do not ship hand-drawn, code-drawn, SVG, canvas, PIL-generated, or placeholder graphics for these assets unless the user explicitly asks for temporary placeholder art.

Before generating, inspect a small reference set from the relevant asset family:

- Card art: several existing `assets/art/cards/*.png` files with similar element, rarity, subject, or composition.
- Action icons: neighboring `assets/art/icons/*.png` files that share the same visual vocabulary, pixel density, outline weight, palette, and transparent-background treatment.
- UI frames: `assets/art/ui` only as context for how the art will be framed; never bake frames, rarity sockets, or UI chrome into card art.

When replacing a bad or temporary asset, overwrite the project asset only after the generated version has been moved into the workspace, resized to the expected dimensions, visually inspected, and checked in an actual `CardWidget` screenshot. Remove temporary generated sources that are not needed.

## Card Art Alpha And Inset Contract

Final card art must match the existing card-art silhouette, not merely the file dimensions:

- Corners must be transparent (`alpha = 0`), with thousands of transparent pixels around the ragged side/top/bottom art boundary.
- The alpha bounding box should look like nearby existing card art, commonly around `x=27..229` to `x=42..213` and `y=2..142`, depending on the chosen reference silhouette.
- Do not leave a solid black background around a fractured or ragged border. Black pixels outside the intended art window must be transparent.
- Do not fill the full canvas with a wide rectangular scene. Generated artwork should be inset into the visible art window so CardWidget's wider `STRETCH_KEEP_ASPECT_COVERED` slot crops padding or background, not the focal subject.
- If the image generator returns an opaque full-scene raster, composite it into an existing card-art alpha/border reference from a visually related card rather than shipping it directly.
- Center the actual illustration inside the visible alpha window, not merely inside the `256 x 144` canvas. Some reusable alpha masks are left-biased; when using one, nudge the RGB content slightly right so the focal subject sits visually centered in the card frame.
- Preserve the subject read at small size, but keep important faces, weapons, spikes, and impact points away from the outer 8-12 source pixels.

Useful alpha sanity check:

```bash
python3 - <<'PY'
from PIL import Image
from pathlib import Path
for path in map(Path, ["assets/art/cards/<card_id>.png"]):
    im = Image.open(path).convert("RGBA")
    alpha = im.getchannel("A")
    zero = sum(1 for v in alpha.getdata() if v == 0)
    partial = sum(1 for v in alpha.getdata() if 0 < v < 255)
    corners = [im.getpixel((0, 0)), im.getpixel((255, 0)), im.getpixel((0, 143)), im.getpixel((255, 143))]
    print(path, im.size, im.mode, "zero", zero, "partial", partial, "bbox", alpha.getbbox(), "corners", corners)
PY
```

Treat `zero=0`, `partial=0`, `bbox=(0, 0, 256, 144)`, or opaque black corners as a failed card-art asset.

Also audit for detached alpha fragments, especially cropped slivers to the right of the main art window. The intended ragged art shape should read as one main connected component plus only local chips near that component; a separate component several pixels to the right of the main alpha bounding box is usually a copied-edge artifact and should be removed.

## Generation Prompt

Use the `imagegen` skill when generating raster card art. Use existing card art as style guidance and explicitly ask to match Labyrinth of Ash's current dark fantasy pixel-painted card art style.

Prompt for:

- Dark fantasy dungeon-card illustration.
- Compact 16-bit/pixel-art-inspired painting, not photorealism.
- Strong central silhouette, readable at small card size.
- Element-colored light or material cues when elemental.
- Transparent or removable flat chroma-key background if the subject should sit cleanly in the card art frame.
- No card frame, no UI, no text, no watermark.
- Wide 16:9 composition with generous padding, plus extra safe area around the focal subject because the final art will be inset into a transparent ragged card-art window.

Template:

```text
Create card art for Labyrinth of Ash: <subject and action>. Match the current Labyrinth card art references: dark fantasy dungeon-card illustration, compact pixel-art-inspired painted style, painterly pixel texture, strong central silhouette, high contrast, readable at tiny card size. Use <element/neutral palette> lighting and materials. Wide 16:9 composition with generous padding. No text, no card frame, no UI, no watermark.
```

For action icons, use the same `imagegen` workflow with icon references:

```text
Create a 64x64 action icon for Labyrinth of Ash: <keyword/action concept>. Match the existing Labyrinth action icon references: dark fantasy pixel-art icon, transparent background, chunky readable silhouette, crisp outline, limited palette, readable at tiny card size. No text, no UI frame, no watermark.
```

For background removal with the built-in image generator, request a flat chroma-key background and then remove it locally:

```text
Use a perfectly flat solid #00ff00 chroma-key background for background removal. The background must be one uniform color with no shadows, gradients, texture, reflections, floor plane, or lighting variation. Do not use #00ff00 in the subject.
```

## Background Removal And Sizing

For chroma-key cleanup, use the system imagegen helper:

```bash
python "${CODEX_HOME:-$HOME/.codex}/skills/.system/imagegen/scripts/remove_chroma_key.py" \
  --input tmp/imagegen/<source>.png \
  --out assets/art/cards/<card_id>.png \
  --auto-key border \
  --soft-matte \
  --transparent-threshold 12 \
  --opaque-threshold 220 \
  --despill
```

Then resize to the project standard if needed, preserving alpha:

```bash
sips -z 144 256 assets/art/cards/<card_id>.png
file assets/art/cards/<card_id>.png
```

If the requested subject is smoke, glass, hair, translucent materials, or other complex transparency, follow the imagegen skill's true-transparency fallback rules instead of forcing a bad chroma key.

## Frames, Rarity, And Elements

Do not bake frames or rarity marks into card art. CardWidget handles them:

- Rarity frame path is selected from `rarity` using `assets/art/ui/card_frame_rarity_{starter,common,uncommon,rare}.png`.
- Rarity socket color lives in those frame texture variants, not overlay controls.
- Elemental frame tint is applied at runtime by `CardWidget._card_frame_texture` when `element` is one of the elemental ids.
- Elemental backgrounds and accents come from `scripts/element_data.gd`; neutral cards use the card `accent`.

For elemental cards, the visual payload should hint at the element, but the frame tint and element iconography are runtime UI responsibilities.

The card time cost is also runtime UI. `CardWidget` renders top-level `time` as the procedural clock badge in the top-right corner; do not paint clocks, numbers, or time-cost marks into generated card art.

## Names And Icon Layout

CardWidget title fitting tests rendered sizes against the visual nameplate width, not the full label width. It starts from the normal 17-19 pt range, renders the chosen fitting size 2 pt smaller, caps normal rendered titles at 15 pt, and can shrink to 10 pt. Prefer short names, usually 1-3 words, with spaces between words. Avoid long unbreakable words.

Action summaries are rendered by `ActionIconLibrary.rows_for_card`:

- Costs render as a leading row.
- Each action usually renders as its own row.
- Rows with many valued tokens split into 2-3 token segments.
- AOE actions render a small tile-pattern token.

If a card needs many effects, consider whether the design is too busy before adding more UI code.

## Visual Validation

Every new or visually changed card needs a fresh `CardWidget` preview screenshot before delivery. This includes changes to card art, icons, card names, rarity/element framing, summary rows, or any card-facing UI code.

Preview rendering rules:

- Instantiate `scenes/card_widget.tscn` and let the real `CardWidget` render the card; do not assemble card previews by hand.
- Use an actual game card size. For standalone proof sheets, use the scene default `250 x 352`. For surface-specific checks, use the matching `RunScene` size such as `_hand_card_size(...)`, pile, reward, or upgrade card size.
- Do not resize a `CardWidget` to oversized proof dimensions such as `360 x 507`; CardWidget clamps interior art and icon metrics for real game sizes, so oversized controls create false visual bugs like tiny icons, stretched sockets, excess parchment, and cleanly clipped art.
- If a larger image is needed for inspection, render cards at the true size first, then scale the final screenshot/contact sheet uniformly.
- Prefer the normal Godot renderer for preview screenshots when textures or viewports are involved. Headless tests are still useful for logic, but dummy-renderer screenshots can be blank or misleading.
- Save every proof with a fresh timestamped or versioned filename under `tmp/card_screenshots/` so Codex does not show a cached old bitmap.

Check:

- `file assets/art/cards/<card_id>.png` reports `256 x 144` PNG RGBA.
- Corners are transparent and the alpha statistics resemble nearby existing card art; card art should not be a full-bleed opaque rectangle.
- A beige or checkerboard contact sheet shows no solid black rectangle around the ragged art edge.
- The subject remains readable when scaled to a hand card.
- The card name fits without awkward ellipsis.
- Icon rows communicate the card without relying on long fallback text.
- Elemental frame and rarity frame are produced by data fields, not painted into art.
- Actual `CardWidget` screenshots show normal icon scale, unstretched rarity sockets/gems, and art fitting inside the frame with the intended ragged alpha edge visible.
- Character-menu badge screenshots show the same card art reading as a cropped horizontal background with a contained border, readable name, no art spilling over the border, and no blank/featureless center crop. For broad UI changes, render a full badge contact sheet from `RunScene._build_equipment_card_badge` and `_build_magic_card_tile`.
- Visual proof screenshots use fresh timestamped or versioned filenames; do not overwrite a previously shown path because Codex may display stale cached images.
