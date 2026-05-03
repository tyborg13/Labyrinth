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

Action and element icons are `64 x 64` PNG RGBA in `assets/art/icons`. Card frame assets are `256 x 352` PNG RGBA in `assets/art/ui`.

CardWidget loads `art_path` into a `TextureRect` with `STRETCH_KEEP_ASPECT_COVERED`, clips the art frame, and dynamically sizes the art band between roughly 68 and 118 px tall depending on card size. Keep the image readable after center-cropping and downscaling.

## Generation Prompt

Use the `imagegen` skill when generating raster card art. Use existing card art as style guidance when available.

Prompt for:

- Dark fantasy dungeon-card illustration.
- Compact 16-bit/pixel-art-inspired painting, not photorealism.
- Strong central silhouette, readable at small card size.
- Element-colored light or material cues when elemental.
- Transparent or removable flat chroma-key background if the subject should sit cleanly in the card art frame.
- No card frame, no UI, no text, no watermark.
- Wide 16:9 composition with generous padding.

Template:

```text
Create card art for Labyrinth of Ash: <subject and action>. Dark fantasy dungeon-card illustration, compact pixel-art-inspired painted style, strong central silhouette, high contrast, readable at tiny card size. Use <element/neutral palette> lighting and materials. Wide 16:9 composition with generous padding. No text, no card frame, no UI, no watermark.
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

Then resize to the project standard if needed:

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

## Names And Icon Layout

CardWidget title fitting starts around 17-19 pt and can shrink to 10 pt. Prefer short names, usually 1-3 words, with spaces between words. Avoid long unbreakable words.

Action summaries are rendered by `ActionIconLibrary.rows_for_card`:

- Costs render as a leading row.
- Each action usually renders as its own row.
- Rows with many valued tokens split into 2-3 token segments.
- AOE actions render a small tile-pattern token.

If a card needs many effects, consider whether the design is too busy before adding more UI code.

## Visual Validation

Check:

- `file assets/art/cards/<card_id>.png` reports `256 x 144` PNG RGBA.
- Corners or background are transparent when the design calls for it.
- The subject remains readable when scaled to a hand card.
- The card name fits without awkward ellipsis.
- Icon rows communicate the card without relying on long fallback text.
- Elemental frame and rarity frame are produced by data fields, not painted into art.
