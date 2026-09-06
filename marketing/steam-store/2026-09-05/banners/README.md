# Steam section banners

Four original, code-native headers at 1170×176px. The approved cut-stone frame, ochre rails, exact Crumble lettering, heading text and transparent corners are preserved. Only the left ornaments were refined: beveled positioning tiles and pieces, layered cards with a forged blade, a brass-and-glass lantern, and a fire-lit route toward a stone arch. The lantern uses smooth light falloff and a curved flame; it has no diagrammatic ray marks.

Typography comes from `fonts/LabyrinthCrumble-Display.ttf`, at 56 source pixels. SVG text contains the font's actual outlines so no installed-font substitution can occur. `dimensional_motifs.py` supplies original shaded polygons, sampled Bézier silhouettes and radial light; the same geometry and color stops produce SVG and PNG. PNGs render at 3× and downsample with Lanczos. Their authored hex colors carry an explicit standard PNG sRGB chunk with perceptual intent. No stock artwork, generated raster illustrations, or external fonts are used.

Regenerate from the repository root:

```sh
python3 marketing/steam-store/2026-09-05/banners/render-banners.py
```

Dependencies: Pillow and fontTools. The generator writes SVG/PNG pairs, font/output SHA-256 metadata, and review sheets at 1170,780 and 390px. Review sheets use Steam's dark-blue background and are proof only, not upload assets.

The worker inspected the original and refined 1170px and 390px sheets. A second render reproduced every SVG, PNG and manifest byte-for-byte. XML validation checks gradient references; PNG checks confirm dimensions, sRGB metadata, stable alpha and unchanged pixels outside the ornament well. The exact frame and lettering remain unchanged to the right ofx178. Before/after sheets and `validation.json` are archived in the task's ignored `proof/banner-refinement` directory. Independent review and the final commit are coordinated by the parent task.
