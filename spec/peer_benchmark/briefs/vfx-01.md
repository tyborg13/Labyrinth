# vfx-01 — Pixel-art look for procedural elemental effects (no sprite sheets)

## Header
- Owner, 2026-10-15: "is there some way that we can make our elemental animations for like elemental spells and stuff
  look pixelated, even though they're procedurally drawn ... to make them not stand out as much against our other
  artwork ... without having to actually use like sprite sheets". Today the effects are smooth gradients, soft glows and
  anti-aliased thin lines (baseline: `tests/elemental_spell_effects_probe.gd`), while the board and sprites read as chunky
  pixel clusters about 2 screen pixels wide at 1920×1080.
- Approach (director decision): keep every effect's procedural drawing exactly as it is, but draw it into a low-resolution
  layer snapped to a screen-pixel grid, then quantize colour to a per-element ramp and binarize alpha with ordered dither.
- Base: `codex/peer-benchmark`. Owned files: new `data/vfx_pixel_style.json` (director data below — copy exactly), new
  `scripts/pixel_fx_layer.gd` (+ `shaders/pixel_fx_quantize.gdshader`), `scripts/elemental_spell_fx.gd` and the
  elemental attack visuals (`scripts/attack_fx_library.gd`, `scripts/dragon_spell_presentation.gd`) only to route their
  drawing into the layer, plumbing in `scripts/combat_board_view.gd`, `tests/elemental_fx_hash_equivalence_test.gd` /
  `tests/elemental_spell_geometry_equivalence_probe.gd` only if their contract must accept the new layer (keep the
  geometry/hash checks on the pre-pixelation drawing), new `tests/pixel_fx_*` and a comparison probe
  `tests/pixel_fx_compare_probe.gd` + contract.
- Rules: presentation only — no timing, gameplay or analytics changes; keep every effect's geometry, timing, colour
  identity and depth order (in front of / behind units exactly as today); reduced motion unchanged except for the
  pixel look; performance: no more than +1.0 ms per frame on the elemental performance benchmark
  (`tests/elemental_ambient_performance_benchmark.gd` or the nearest existing spell benchmark); Windows typed-array
  rule; real-renderer proof via SubViewport 1920×1080.

## Look (director decisions)
1. **Grid**: effects render into an offscreen layer at `1/grid_px` of the viewport resolution, with
   `grid_px = max(1, round(grid_px_at_1080 × viewport_height / 1080))`, displayed with nearest filtering so each layer
   pixel is a crisp `grid_px` square aligned to the screen's pixel grid. `grid_px_at_1080` = 2.
2. **Colour quantization**: for each layer pixel, take its colour's Rec.601 luminance and replace the colour with the
   nearest-luminance entry of the effect's element ramp (5 entries, dark → light). Effects with no element use the
   `neutral` ramp.
3. **Alpha**: binarize with a 4×4 Bayer ordered dither: a pixel is opaque when `alpha > bayer4(x, y) + alpha_bias`,
   otherwise fully transparent; any alpha below `alpha_floor` is always transparent (no haze). Soft fades therefore
   become dithered pixel fades.
4. **Blend modes**: effects drawn with additive blending go into a second layer with the same grid, quantization and
   dither, composited additively; normal-blend effects composite normally. Depth order relative to units is preserved
   (if an effect currently draws both behind and in front of a unit, it gets a back and a front layer).
5. **Toggle for review only**: `pixel_style_enabled` in the data file (default `true`); no player setting.

## Director data — `data/vfx_pixel_style.json`
```json
{
 "doc": "vfx-01 pixel look for procedural elemental effects. Ramps are dark -> light; tune here, not in code.",
 "pixel_style_enabled": true,
 "grid_px_at_1080": 2,
 "alpha_floor": 0.08,
 "alpha_bias": 0.0,
 "ramps": {
  "fire":      ["#3a1208", "#8a2a10", "#d0581c", "#f29a3a", "#ffd98a"],
  "ice":       ["#1c3346", "#2f6f8f", "#5fb0d0", "#a8e0f0", "#eefaff"],
  "lightning": ["#2a1a4a", "#5a3a9a", "#9a7ae0", "#d0c0ff", "#ffffff"],
  "air":       ["#1e3a36", "#3f7a6e", "#79b8a6", "#bfe6d6", "#f2fff8"],
  "earth":     ["#3a2614", "#6e4a2a", "#a0743e", "#d0aa6a", "#f0dca8"],
  "neutral":   ["#211a17", "#4a3c34", "#7d6a5c", "#b8a48e", "#efe2cc"]
 }
}
```

## Proof
- Tests: data validation; the quantizer maps a fixture gradient to exactly the ramp entries; dither pattern stability
  (same frame → same pixels); grid scaling at 1080/1440/2160 viewport heights; depth order and blend mode preserved for
  each element; performance budget; existing elemental tests/probes still pass on the pre-pixelation geometry.
- Windowed (list the commands; the director runs them): `tests/pixel_fx_compare_probe.gd` capturing, for each of the
  five elements, the same frames as `elemental_spell_effects_probe` (preview, travel, contact, burst/peak, tail) with
  the style on and off, plus a 3× nearest crop around the effect, and a contact sheet per element (off | on); plus one
  elemental ranged attack and one AoE attack (on/off).

## Out of scope
Non-elemental effects (hit flashes, UI effects, ambient room overlays), new effects, timing changes. If the pipeline is
clean, the director will extend it to other effects in a follow-up.
