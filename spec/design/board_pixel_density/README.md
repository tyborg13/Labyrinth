# Board pixel-density pass

## Goal

Every raster drawn on the combat and room board reads at the protagonist's chunky pixel density. The owner's words (2026-10-06): "I want everything to look as consistent and coherent as possible."

This follows the visible-gear work, where gear art was consolidated to match the hero. It reuses that idea with one key difference: gear started as large paintings shrunk to native size, and the shrink is what made it chunky. Board art is already at native size, so the treatment re-pixelates it onto a coarser grid instead of posterising it. A flat 24-colour posterise of a whole creature dulled its highlights (`review/01_posterise_vs_board_scale.png`) and was rejected.

## Owner decisions (2026-10-06)

- **Grid 1.5 for Harrier-class art at the hero's scale.** Fine, single-pixel painting drawn at the hero's size is averaged onto a grid of 1.5 source pixels and enlarged back with nearest (`review/02_grid_options_bloomer_harrier.png`).
- **The hero's front is the reference and stays untouched.** His rear view only gets the orphan cleanup: it measures close to the front overall, and grid 1.5 would make it chunkier than the front (`review/04_outline_kept_and_hero_rear.png`).

## Design-owner decisions (from those reviews)

- **The original silhouette edge is restored after treatment**, so outlines stay crisp like the hero's (`review/04`).
- **Scale compensation.** The board draws assets at different sizes relative to the hero:
  - Units differ by `art_scale`.
  - Props differ by their draw rects.
  - The grid is divided by the asset's relative draw scale `r`, so an art pixel ends up the same size on screen as the hero's.
  - Small creatures and heavily shrunk paintings get a coarser grid (torch: `review/05_torch_grid.png`).
  - The October 6 pass gave oversized art cleanup only. The October 7 decision below supersedes that for non-rig props; dragons keep native cleanup.
- **Lightning Wisp override.** It is line art, and grids above 1.5 smear its bolts (`review/06_wisp_grid.png`).
- **Scavenger NPC override: cleanup only.** The same PNG is cropped for the dialogue portrait, where grid 1.63 muddied his face (`review/14_ui_scavenger_portrait_grid163_rejected.png`, then `15_..._clean.png`).
- **Shared UI uses stay treated.** The warden, gaoler and Zekarion front rests (pre-battle and grimoire) and dropped embers (map recovery marker) are the board art itself (`review/13_ui_prebattle_warden.png`).
- **No palette posterise in this pass.** Colours stay as the source painted them, averaged within each block.

## Owner decisions (2026-10-07)

- **Each facing measures its own untouched rest.** Rear views looked finer than fronts, especially the Gaoler's. Strength now varies continuously: `t(o) = 1 + 0.5 × clamp((o − 0.05) / 0.10, 0, 1)`. Native regrid begins at grid 1.2. Wisp grid 1.5, hero rear cleanup, untouched hero front and scavenger cleanup keep their existing values and notes.
- **Oversized non-rig board art resamples to the hero's source-pixel scale.** Every non-rig entry at r > 1.05 uses scale r, then grid 1.5. [Sheet 16](review/16_props_resample_proposal.png) records the approved direction; [sheet 17](review/17_props_resample_refined_outline.png) refines hard outlines using NEAREST source edge colour.
- **Revised alpha decision ([sheet 18](review/18_resample_hybrid_alpha.png)):** a visibly translucent fraction (64 ≤ alpha < 240 among nonzero source pixels) ≥ 0.10 makes an entry soft; all others are solid. Measure once on the static calibration image, or frame 0 for a sheet-only entry. Related sheets/parts inherit through registry `alpha_class_from`; each elemental floor overlay measures itself. Solid frames use a premultiplied Lanczos body at alpha 255 and a rounded BILINEAR faint halo, both clipped to the NEAREST source footprint. Body RGB comes from Lanczos, halo RGB from BILINEAR, un-premultiplied with rounding. Restore the body's own edge ring from NEAREST where source alpha ≥ 128. Soft frames use premultiplied BILINEAR clipped to the same footprint, with no extra outline. Both regrid at 1.5 and preserve NEAREST hidden fringe. Applied class/fraction and measurement-owner records are in `outputs.json`.
- **Boundary tolerance replaces IoU.** Changed silhouette pixels must stay within one output pixel (Chebyshev distance) of the NEAREST source boundary. Nonzero support is a subset of NEAREST source support for both classes, and bounds have zero expansion. Static traps have 182×92 used bounds on 248×162 canvases and satisfy the proportional margin/perspective checks; the no-texture fallback retains the original 80/122 source aspect.
- **Family classification resolves air plate parity:** every trap family is solid, with sheets linked to their static entry (for example `alpha_class_from: "trap_air"`). Box/crate destruction, chest opening, campfire idle, door opening and torch idle follow the same inheritance rule. The exact static/idle sample assertions remain unchanged. Soft entries are fire floor overlays 01/02 and ice floor overlay 01; every other resampled entry is solid. Sampling and regridding stay frame-local.
- **Current audit:** 31 solid / 3 soft resample entries, applying 224 solid / 3 soft frames. Every solid frame matches the approved hybrid prototype pixel for pixel. Worst boundary distance is zero, with no support/bounds violations; all 240 exact static/idle plate samples match.
- **Rigs retain their fixed geometry.** Dragons stay clean and every rig retains source dimensions and alpha. Resized prop consumers derive sizes from loaded textures; the chest's authored hinge/canvas geometry stays fixed.

[Unit 3](unit_3_per_facing_and_resample.md) specifies this work, including the follow-up alpha decision. Native rest rebake, rest recording, shadow-cache regeneration and renderer/UI proof remain owned by the design owner. Detailed audit/proof artifacts live in task scratch.

## The rule

1. **`r`** is the asset's screen pixels per source pixel divided by the hero's.
   - Units: `art_scale`.
   - Props: the draw size from code divided by the unit draw factor `1.03/255`.
   - Both scale with the board tile width, which cancels out.
2. **`t`** is `1 + 0.5 × clamp((o − 0.05) / 0.10, 0, 1)` for native orphan share `o`.
   - Each rig facing measures its own untouched rest; props use their first frame.
   - An orphan is an opaque pixel whose RGB sum-abs difference is at least 24 from every opaque 4-neighbour. The share counts only opaque pixels that have at least one opaque neighbour.
3. **`grid`** is `round(t / r, 2)`.
   - When `grid` ≥ 1.2, use the regrid mode.
   - Otherwise use `clean` (orphan cleanup at native).
   - Every non-rig at r > 1.05 instead resamples each frame by r and regrids at 1.5.
   - Overrides carry a note and keep their approved values.
4. **Regrid** works like this:
   1. Premultiplied BOX reduction to `round(w/grid) × round(h/grid)`.
   2. Un-premultiply.
   3. Orphan cleanup on the reduced image (threshold 24, two passes, opaque pixels only).
   4. NEAREST enlargement back to the exact source size.
5. **Invariants:**
   - Native outputs keep the source's size, alpha channel and fully transparent pixels byte for byte.
   - Edge-ring pixels are restored from the source. These are opaque pixels with a transparent or out-of-bounds 4-neighbour.
   - Sheets are processed frame by frame, with the grid anchored at each frame's origin, so animation frames do not shimmer against each other.
   - Resample outputs have rounded scaled frame sizes and hidden fringe RGB from NEAREST. Solid body alpha is 255 with a preserved faint halo; both classes have zero support/bounds growth. Changed support stays within the one-pixel boundary tolerance.

`grid_table.json` retains the October 6 seed table. The production registry now owns the per-facing and resample values; `review/` holds the comparison sheets behind each decision.

## Scope

**In scope:**
- All 18 enemy cutout rigs the board draws (`combat_board_view.gd` `_unit_uses_cutout`).
- All 13 guardian rigs.
- The hero's rear view (body parts only).
- Floor tiles and floor overlays, the pillar and its moss overlay, traps (static and sheets), the door and door-opening sheet, column torches (idle sheets and static fallbacks).
- Crates, box and keg, plus their destroy sheets.
- Relic chest, campfire (static and idle), watch brazier, scavenger stall, scavenger NPC, the emaciated man's idle sheet, dropped embers.

**Out of scope:**

| Art | Reason |
| --- | --- |
| Raster VFX and ambient particles | Transient glow art |
| Dedicated UI, card art, portraits, icons, and the item and equipment icons reused as board loot | Painterly by policy; the shared board art named above, including the scavenger PNG, stays treated in UI |
| Board backdrop | Soft, dimmed painting with no fine texture |
| Protagonist gear | Has its own pipeline (`tools/process_gear_visual_assets.py`) |
| Scavenger and Graftwright rigs | UI-only |
| Art that is never drawn | Wall overlays, non-earth pillar overlays, `watch_brazier_lit`, `raised_cover`, unreferenced tiles |

## Units

| Unit | Brief | Owns |
| --- | --- | --- |
| 1 | `unit_1_density_tool.md` | `tools/pixel_density.py`, `tools/process_board_density.py`, `tools/rebake_cutout_rests.gd`, gear-tool import refactor, `spec/assets/board_pixel_density/`, treated production PNGs, `tests/test_board_pixel_density.py`, `spec/board_pixel_density.md`, workflow docs |
| 2 | `unit_2_density_probe.md` | `tests/board_density_probe.gd`, `tools/board_density_ab.py` |
| 3 | `unit_3_per_facing_and_resample.md` | Per-facing rule, oversized prop resampling, resized-texture consumer fixes and tests, regenerated outputs/report, October 7 docs |

Units 1 and 2 were implemented in parallel. Unit 3 follows their committed baseline.

The design owner runs the native steps itself: the rest rebake, the shadow-cache regeneration, the asset probes, and the before/after captures.
