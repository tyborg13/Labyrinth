# Steam section banners

Four original, code-native headers at 1170 × 176 pixels. The PNGs have transparent outer corners. The cut stone frame, restrained ochre rails, cream lettering, and violet accents connect the set to the game without adding invented gameplay imagery. Each section has a distinct small ornament: positioning tiles, equipment and cards, a lantern, or a campfire route.

Typography comes from the exact repository font `fonts/LabyrinthCrumble-Display.ttf`, at 56 source pixels. SVG text is converted to that font's actual outlines so no installed-font substitution can occur. PNGs render the same source at 3× and downsample with Lanczos. No stock illustrations, generated raster artwork, or external fonts are used.

Regenerate from the repository root:

```sh
python3 marketing/steam-store/2026-09-05/banners/render-banners.py
```

Dependencies: Pillow and fontTools. The generator writes SVG/PNG pairs, a font/output SHA-256 manifest, and three review sheets at native 1170px, desktop 780px, and phone 390px widths. Review sheets composite onto Steam's dark blue background and are proof only, not uploads.

The worker inspected the full native and 390px sheets, then updated the final heading from “Know When to Turn Back” to the more accurate “Choose How Far to Go.” The final wording and complete safe margins were checked again at all three widths. Single-line text stays legible at 390px; no letter clipping or unrelated microcopy is present.
