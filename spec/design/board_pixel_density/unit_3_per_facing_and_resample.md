# Unit 3: Per-facing strength and resampled props

## Header

On 2026-10-07 the owner inspected the first pass in game. They approved the enemies, and asked for two fixes:

1. **Rear views read finer than fronts.** The Gaoler's back was the example. The rule measured each rig on its front rest only, and backs generally measure finer.
2. **Board props still stand out.** Tiles, pillars, boxes and crates were drawn larger than the hero, so they only received cleanup. Pillars and tiles read as lower density; boxes read as finer.

The owner approved both proposals.

- **Reference sheets:**
  - `review/16_props_resample_proposal.png`: the approved direction.
  - `review/17_props_resample_refined_outline.png`: the design owner's refined edge handling, the right-hand column of each row.
- **Reference prototype (not production code):** `/private/tmp/claude-501/-Users-borgerding-workspace-Labyrinth/1192fff8-0018-41b6-b489-30bcf96f6a52/scratchpad/codex_density/resample_prototype.py`.
- **Existing code:** `tools/pixel_density.py`, `tools/process_board_density.py`, `spec/assets/board_pixel_density/registry.json`, `tests/test_board_pixel_density.py`, `spec/board_pixel_density.md`.

## Change

### 1. Per-facing, continuous strength (rigs and native props)

- **Continuous `t`.** Replace the step rule with `t(o) = 1 + 0.5 × clamp((o − 0.05) / 0.10, 0, 1)`, where `o` is the native orphan share (a fraction).
  - Up to 5% gives 1.0, 10% gives 1.25, and 15% or more gives 1.5.
  - The Harrier-class art the owner approved at grid 1.5 is unchanged.
- **Per facing.** Rigs measure each facing on its own untouched rest: the front rest for `front/` parts, the rear rest for `rear/` parts.
  - Store per-facing `orphan_share`, `t`, `grid` and `mode` in the registry.
  - Each facing's parts use their own values.
  - `grid = round(t / r, 2)`.
- **Threshold.** `regrid` when `grid` ≥ **1.2** (was 1.25), otherwise `clean`.
- **Overrides keep their notes and values:**
  - Lightning Wisp: grid 1.5 in both facings.
  - Scavenger NPC: clean.
  - Hero rear: clean, with the same protected parts.
  - Hero front: the untouched reference.
- **Expected results**, for checking:

  | Rig | Front | Rear |
  | --- | --- | --- |
  | Chainbound Gaoler | regrid 1.23 | regrid 1.46 |
  | Frostglass Lancer | clean | regrid 1.37 |
  | Craghide | clean | regrid 1.22 |
  | Ash Hound | 1.68 | 1.84 |
  | Bell Tender | 1.48 | 1.76 |
  | Rime Spitter | 1.43 | 1.53 |
  | Roc Fledgling | 1.57 | 2.0 |
  | Crawler | 1.73 | 1.73 |

  Dragons stay clean (r ≈ 1.8). Report every entry whose mode or grid changed versus HEAD.

### 2. Resample mode for props drawn larger than the hero

**Scope.** Every non-rig entry with `r` > 1.05:
- floor tiles, including the ember floor and the stone fallback;
- all floor overlays;
- the moss pillar overlay and the pillar;
- traps, static and the idle/activation sheets;
- the static door and the static column-torch fallback;
- wooden box, crate and keg, with their destroy sheets;
- the relic chest and its opening parts;
- the scavenger stall.

Rigs never resample: their geometry is fixed to the 255-px canvas. Entries with `r` ≤ 1.05 keep the per-facing rule above, for example the door opening, torch idle sheets, campfire, brazier, embers and NPCs.

**Algorithm.** For each frame (whole image, or each grid frame), with `r` the entry's scale:
1. **New frame size:** `round(fw × r)` × `round(fh × r)`. Sheets keep their cols × rows layout.
2. **Colour:** premultiplied Lanczos upscale of all four channels as float, then un-premultiply with rounding.
3. **Alpha:**
   - If the source frame's alpha is binary (only 0 and 255), threshold the upscaled alpha at 128 to 0/255.
   - Otherwise keep the rounded, clipped upscaled alpha. This covers soft overlays and glows.
4. **Hidden fringe:** pixels with output alpha 0 take the RGB of the NEAREST-upscaled source. This preserves the source's hidden fringe colour under bilinear sampling.
5. **Regrid** the upscaled frame at grid **1.5**, the owner-approved grid at the hero's pixel size. Use the existing `regrid`, including its edge restore.
6. **Crisp outline (binary-alpha frames only):** set every new edge-ring pixel (opaque, with a transparent or out-of-bounds 4-neighbour) to the NEAREST-upscaled source colour, where that source pixel is opaque.

The prototype implements steps 1–6 for single images; add frame handling.

**Registry.** Resampled entries record `mode: "resample"`, `scale: r`, `grid: 1.5`, and a note. Outputs are deterministic and checked by pixel digest, like the others.

**Invariants and tests for resample entries:**
- the output size equals the scaled size per frame;
- binary alpha stays binary;
- the silhouette IoU against the NEAREST-upscaled source alpha is ≥ 0.97 per frame;
- rerunning from sources is idempotent.

Native entries keep their existing invariants.

### 3. Code consumers of resized textures

Texture sizes change for every resampled entry. **Find every consumer** of each resampled path (draw code, rect math, frame math, trims, used-rect caches, shadow or static caches, tests, probes) and confirm it is size-independent. Fix the ones that are not, by deriving from texture size rather than adding new constants.

Known risks to check:
- **Relic chest opening.** `scripts/relic_chest_prop.gd` maps the 128×160 opening canvas to `LOGICAL_SIZE` 96, and `relic_chest.png` is 96×96.
- **Static door.** It has a 112×182 used area and a flipped copy, in `combat_board_view.gd` around the door draw.
- **Pillar.** It is trimmed to 160×205. Check whether the trim is computed at runtime or fixed in code.
- **Trap sheets.** Check the frame size math (sheet ÷ 4) and the `160/122` draw constant.
- **Destroy sheets.** Check the 4×4 frame math.
- **Column torch static fallback.** Check its rect.
- Any test or probe that asserts these textures' pixel sizes.

**Coverage rule.** Every production script change needs a regression test that fails at the old size assumption and passes now. A static-or-rest equivalence must not silently change; if one does, report it.

The chest opening's visual registration must match the closed chest at `open_progress` 0 and 1. Add a check that the opening composite at progress 0 covers the same screen rect as the closed chest.

### 4. Docs

- **`spec/board_pixel_density.md`:** the continuous per-facing rule, the 1.2 threshold, resample mode with its algorithm and invariants, the consumer audit results, and the owner decisions of 2026-10-07.
- **`README.md` in this folder:** add the 2026-10-07 decisions.
- **Report:** regenerate it with per-facing rows and resample entries. Each row shows the old and new screen pixel size; resampled entries reach ratio 1.0.

## Keep

- Rules, analytics and saves.
- Every rig texture's size and alpha.
- The hero front.
- Gear outputs.
- The decoded-pixel checks, `--record-rests`, coverage and case-paint pins from unit 1, round 2.

## Proof

- **Commands:** process; `--check` (rests will report stale until the native rebake; state the expected output); both Python suites; `--check-only` for every GDScript you touch; the full Godot suite when production scripts change.
- **Native steps:** you cannot run the GUI renderer. Give the exact command sequence: rebake → `--record-rests` → shadow cache → board density probe and asset probes.
- **Final message:**
  - files changed;
  - counts of changed PNGs per mode;
  - the full consumer audit, as a table of path → consumer → size-dependent? → fix;
  - every production script change and its test;
  - open issues.

Do not commit.
