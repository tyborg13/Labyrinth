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
  - Assets drawn larger than the hero (dragons, tiles, traps, crates, chest, door, pillar) only get the orphan cleanup.
- **Lightning Wisp override.** It is line art, and grids above 1.5 smear its bolts (`review/06_wisp_grid.png`).
- **No palette posterise in this pass.** Colours stay as the source painted them, averaged within each block.

## The rule

1. **`r`** is the asset's screen pixels per source pixel divided by the hero's.
   - Units: `art_scale`.
   - Props: the draw size from code divided by the unit draw factor `1.03/255`.
   - Both scale with the board tile width, which cancels out.
2. **`t`** is 1.5 when the asset's native orphan share is at least 15%, otherwise 1.0.
   - The share is measured on the rig's front `rest.png`, or on the first frame of a sheet.
   - An orphan is an opaque pixel whose RGB sum-abs difference is at least 24 from every opaque 4-neighbour. The share counts only opaque pixels that have at least one opaque neighbour.
3. **`grid`** is `round(t / r, 2)`.
   - When `grid` ≥ 1.25, use the regrid mode.
   - Otherwise use `clean` (orphan cleanup at native).
   - Overrides carry a note.
4. **Regrid** works like this:
   1. Premultiplied BOX reduction to `round(w/grid) × round(h/grid)`.
   2. Un-premultiply.
   3. Orphan cleanup on the reduced image (threshold 24, two passes, opaque pixels only).
   4. NEAREST enlargement back to the exact source size.
5. **Invariants:**
   - Every output keeps the source's size, alpha channel and fully transparent pixels byte for byte.
   - Edge-ring pixels are restored from the source. These are opaque pixels with a transparent or out-of-bounds 4-neighbour.
   - Sheets are processed frame by frame, with the grid anchored at each frame's origin, so animation frames do not shimmer against each other.

`grid_table.json` holds the computed table. It is the seed for the production registry, and `review/` holds the comparison sheets behind each decision.

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
| UI, card art, portraits, icons, and the item and equipment icons reused as board loot | Painterly by policy; shared with the UI |
| Board backdrop | Soft, dimmed painting with no fine texture |
| Protagonist gear | Has its own pipeline (`tools/process_gear_visual_assets.py`) |
| Scavenger and Graftwright rigs | UI-only |
| Art that is never drawn | Wall overlays, non-earth pillar overlays, `watch_brazier_lit`, `raised_cover`, unreferenced tiles |

## Units

| Unit | Brief | Owns |
| --- | --- | --- |
| 1 | `unit_1_density_tool.md` | `tools/pixel_density.py`, `tools/process_board_density.py`, `tools/rebake_cutout_rests.gd`, gear-tool import refactor, `spec/assets/board_pixel_density/`, treated production PNGs, `tests/test_board_pixel_density.py`, `spec/board_pixel_density.md`, workflow docs |
| 2 | `unit_2_density_probe.md` | `tests/board_density_probe.gd`, `tools/board_density_ab.py` |

The units own disjoint files and run in parallel.

The design owner runs the native steps itself: the rest rebake, the shadow-cache regeneration, the asset probes, and the before/after captures.
