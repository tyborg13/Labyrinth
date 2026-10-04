# Unit 1b: pre-battle foes at true relative scale

**Owner feedback on unit 1:**
- Every foe was cropped to its opaque bounds and stretched to the same height. A small foe like the Tunnel Crawler was zoomed up and looked far more pixelated than the Stone Warden, which is much smaller than it in game.
- The crawler's ink-pool shadow sat well below its feet.
- The owner wants to see 5 foes and a boss dragon laid out well.

**Target:** `mockups/prebattle_true_scale.jpg`, a prototype rendered from the real sprites with exactly the algorithm below. Everything else on the pre-battle screen stays as approved: header, objective, kit column, actions, known-moves dialog, entry focus and tags.

## How the game sizes units (match it)

- Every enemy's art is a 255 px canvas. The board draws it at one shared scale multiplied by the enemy definition's `art_scale` (`data/enemies.json`): crawler 0.64, warden 1.18, cinder droplet 0.56, dragons about 1.76–1.92, and so on. The units whose art is a cutout use the same rule.
- The board places the art so that `ActorPresentation.floor_anchor(type)` (`scripts/actor_presentation.gd`, in source pixels) sits on the tile. That point is the foe's feet, not the bottom of the canvas.

## Rules

1. **Draw full art, never crop.**
   - Draw each foe's full 255 px canvas, not cropped to its used rect.
   - Every foe in the lineup uses one shared lineup scale `k`, so each foe's drawn scale is `k * art_scale`. No per-foe normalization.
   - Measure each foe's used rect once (cache it). Then `above = floor_anchor.y - used.top`, `below = max(0, used.bottom - floor_anchor.y)`, and `width = used.size.x`, all in source pixels.
2. **Layout.**
   - **1–3 foes:** one row, in roster order. The leader or boss goes in the centre slot when there are three.
   - **4–6 foes:** two rows.
     - Foes with a footprint larger than 1×1 (the dragons) each take one column that spans both rows, placed in the central columns.
     - The 1×1 foes fill two-high columns: first to the left of the large foes, then to the right, top row first. The left side gets the extra column when the count is odd.
   - Column width weights are 2 for a large foe and 1 otherwise, sharing the foes area's width.
   - The foes area is the space between the FOES header and the action buttons.
3. **Choose `k`.**
   - `k` is the largest value that is at most 0.8 and satisfies, for every foe:
     - `(above + below) * art_scale * k <= cell_height - caption_reserve - 6`
     - `width * art_scale * k <= column_width - 16`
   - `cell_height` is the row height, or both rows for a spanning foe.
   - `caption_reserve` is the height of the name and tag block below the ground, about 58 px for a one-line name; use the real measured caption.
   - Use the same `k` for the whole lineup.
4. **Ground line.**
   - For each foe, `ground_y = cell_bottom - caption_reserve - below * art_scale * k`.
   - Place the art so its floor anchor sits at `(column_centre_x, ground_y)`.
5. **Shadow.**
   - The ink pool (`ui_ink_pool_stage.gd`) is centred on the floor anchor, not the cell bottom.
   - Its width is `0.9 * width * art_scale * k` (minimum 40 px) and its height is 0.22 of its width.
6. **HP badge and LEADER label.**
   - The HP badge sits at the top-right of the foe's visible bounds (the used rect at its drawn scale), clamped inside its column.
   - LEADER sits just above the badge.
   - Drop the old 15 % leader upscale. True scale already makes bosses big.
7. **Caption.**
   - The name sits below the ground area, then the tags.
   - The name wraps to at most 2 lines. If it still overflows, step down to UI 17.
   - Keep the existing "never let tags overlap the name" rule and the single-line tag row with +N overflow.
   - Two-line names must not move sprites. The caption reserve is per row, so take the row's maximum.
8. **Filtering.** Use the same texture filter the combat board uses for unit art, so the screen matches the board. Downscaling must not shimmer: use mipmaps if the board does.
9. **Keep:** foe hover, select and inspection, focus order, tooltips, the hint line, the actions row and all names and tags.

## Proof

- Update `tests/pre_battle_material_polish_probe.gd` and `tests/pre_battle_review_findings_probe.gd` (or add `tests/pre_battle_true_scale_probe.gd`). Capture fresh 1920×1080 screenshots of these rosters:
  1. a lone crawler;
  2. crawler, warden, cinder droplet;
  3. five foes: crawler, warden, acolyte, grave surgeon, harrier;
  4. six foes: the five above plus a chainbound gaoler;
  5. zekarion with 2 lightning wisps;
  6. zekarion with wisp, crawler, warden and acolyte;
  7. noctyrax with 2 veilbound acolytes;
  8. the existing pathological roster.
- **Assertions in the suite, using the real nodes:**
  - For every pair of foes, `drawn_scale / art_scale` is equal.
  - Each foe's floor anchor is on its computed ground line.
  - No sprite's visible bounds intersect its own caption or another column.
  - The ink pool's centre is within 2 px of the floor anchor.
  - `k <= 0.8`.
  - The crawler's drawn height is less than 0.6× the warden's in roster 2.
- Keep all existing pre-battle tests green and the two master failures in `pre_battle_preview_probe` unchanged.
