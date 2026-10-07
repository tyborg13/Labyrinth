# Unit 3: Per-facing strength and resampled props

## Header

On 2026-10-07 the owner inspected the first pass in game. They approved the enemies, and asked for two fixes:

1. **Rear views read finer than fronts.** The Gaoler's back was the example. The rule measured each rig on its front rest only, and backs generally measure finer.
2. **Board props still stand out.** Tiles, pillars, boxes and crates were drawn larger than the hero, so they only received cleanup. Pillars and tiles read as lower density; boxes read as finer.

The owner approved both proposals.

- **Reference sheets:**
  - `review/16_props_resample_proposal.png`: the approved direction.
  - `review/17_props_resample_refined_outline.png`: the design owner's refined edge handling, the right-hand column of each row.
- **Reference prototype (not production code):** a scratch prototype (not retained). Its original alpha path is superseded by the follow-up owner decision below.
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
0. **Classify alpha once per entry/family (revised owner decision).** On the entry's static measurement image, or frame 0 of a sheet-only entry, divide the count of source pixels with 64 ≤ alpha < 240 by the count with alpha > 0. A visibly translucent fraction ≥ 0.10 makes the entry soft; every other entry is solid. An empty measurement is solid with fraction zero. All entry frames use that one class. Related sheets/parts inherit the static entry's class through registry `alpha_class_from`: traps, box/crate destruction, chest opening, campfire idle, door opening and torch idle. Each elemental floor overlay keeps its own measured class, using a separate entry. Record the applied class/fraction and measurement owner in outputs. Faint halos and nearly opaque paint do not select the soft path.
1. **New frame size:** `round(fw × r)` × `round(fh × r)`. Sheets keep their cols × rows layout.
2. **Colour:** premultiplied upscale of all four channels as float, then un-premultiply with rounding. Solid frames upscale with both LANCZOS and BILINEAR; soft frames use ringing-free BILINEAR.
3. **Alpha:**
   - `support` is the NEAREST-upscaled source alpha > 0.
   - Solid `body` is LANCZOS alpha ≥ 128 intersected with support. Set alpha to 255 on the body, rounded BILINEAR alpha off the body inside support, and zero elsewhere. RGB comes from un-premultiplied LANCZOS on the body and BILINEAR off it. Fully binary art uses this same hybrid path.
   - Soft frames keep rounded, clipped BILINEAR alpha inside support and zero elsewhere.
4. **Hidden fringe:** pixels with output alpha 0 take the RGB of the NEAREST-upscaled source. This preserves the source's hidden fringe colour under bilinear sampling.
5. **Regrid** the upscaled frame at grid **1.5**, the owner-approved grid at the hero's pixel size. Use the existing `regrid`, including its edge restore.
6. **Crisp outline (solid frames only):** on the body's own edge ring (body pixels with a non-body or out-of-bounds 4-neighbour), set RGB to the NEAREST-upscaled source colour where that source alpha is ≥ 128. Soft frames have no additional outline step.

Process independently per frame using the family's single class. This revision supersedes the previous per-frame classification; all trap families are solid, restoring exact static/idle plate parity. A scratch prototype (not retained), `resample_hybrid`, and [sheet 18](review/18_resample_hybrid_alpha.png) specify the approved solid-body/faint-halo path.

**Registry.** Resampled entries record `mode: "resample"`, `scale: r`, `grid: 1.5`, a note, and `alpha_class_from` when inheriting a static family entry. Outputs are deterministic and checked by pixel digest, like the others. Their class/fraction and measurement path/pixel digest bind the single applied family classification.

**Invariants and tests for resample entries:**
- the output size equals the scaled size per frame;
- every frame uses the entry's measured or inherited class, preserving existing exact static/idle plate samples;
- nonzero support never exceeds the NEAREST source footprint for either class;
- every changed nonzero-support pixel lies within 1 output pixel (Chebyshev distance) of the NEAREST source silhouette boundary;
- output nonzero bounds stay within NEAREST source bounds with zero expansion for either class;
- rerunning from sources is idempotent.

The follow-up owner decision replaces IoU because thin moss and tiny specks need boundary tolerance. Keep detailed per-frame audits and all Unit 3 logs/reports in task scratch. `spec/assets/board_pixel_density/` contains only `registry.json`, `outputs.json`, `report.md`, `seed_corrections.json` and `sources/`.

Native entries keep their existing invariants.

### 3. Code consumers of resized textures

Texture sizes change for every resampled entry. **Find every consumer** of each resampled path (draw code, rect math, frame math, trims, used-rect caches, shadow or static caches, tests, probes) and confirm it is size-independent. Fix the ones that are not, by deriving from texture size rather than adding new constants.

Known risks to check:
- **Relic chest opening.** `scripts/relic_chest_prop.gd` maps the 128×160 opening canvas to `LOGICAL_SIZE` 96, and `relic_chest.png` is 96×96.
- **Static door.** It has a 112×182 used area and a flipped copy, in `combat_board_view.gd` around the door draw.
- **Pillar.** It is trimmed to 160×205. Check whether the trim is computed at runtime or fixed in code.
- **Trap sheets.** Check the frame size math (sheet ÷ 4) and the `160/122` draw constant.
- **Trap fallback.** When no trap texture is loaded, retain the original 80/122 source aspect for height, with a regression assertion.
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
