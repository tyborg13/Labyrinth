# biome-01 — Section biomes: per-dragon tilesets, lights, lighting and motes

## Header
- Goal: each of the six sections looks like its dragon's domain (earth roots, fire basalt, pale wind-temple, frozen
  slate, copper storm-slate, black Umbra marble) instead of one stone tileset everywhere. Floors, pillars and wall
  lights change; the hall lighting, floor light pools, backdrop tint and ambient motes follow the biome.
- Base: `codex/peer-benchmark`. Depends on: nothing (runs beside ev-01/map-01/feel-01/itb-02; touch only the files
  below).
- Docs (sections): spec/board_pixel_density.md (all); spec/combat_art_treatment.md (lighting); spec/visual_design_system.md
  "Combat composition"; spec/actor_presentation.md only if needed for draw order.
- Owned files/dirs: new `data/biomes.json` (director-authored, committed before launch, protected), new
  `scripts/biome_library.gd`, new `tools/process_biome_art.py` (+ its test `tests/test_process_biome_art.py`), new
  `assets/art/biomes/**`, new `spec/biomes.md`, new `spec/assets/biomes/README.md` + `spec/assets/biomes/raw_sha256.txt`,
  new `tests/suites/biome_suite.gd` + `tests/biome_test.gd`, new `tests/biome_gallery_probe.gd`;
  modify `scripts/combat_board_view.gd` (tile/pillar/light texture selection and the floor-light colour only),
  `scripts/combat_atmosphere.gd` (pool colour + mote preset), `scripts/combat_lighting_profiles.gd` (biome tint/ambient
  applied on top of the active profile), `scripts/run_scene.gd` (pass the biome id into presentation, ≤ 25 lines),
  `tools/inspection_fixture.gd`/`.py` (`--biome <id>` override only), `tests/fixtures/static_floor_cache_reference.gd`
  if the static floor cache reference must follow the dispatch.
- Rules: presentation only; rules and saves unchanged (biome is derived, never saved); Windows typed-array rule; no art
  generation — process only the approved raw images listed below; board pixel-density rule applies to every processed
  sprite; `TODO_DESIGN_<name>` for anything undecided.
- Contract: risk tier standard (presentation, assets). Acceptance: (1) sections I–VI render their biome; legacy and
  non-section runs render `stone` (today's look, pixel-identical); (2) processed sprites keep the template silhouettes
  (floors and pillars byte-identical alpha to the templates) and pass the density rules; (3) light colour, lighting tint,
  pool colour, motes and backdrop tint follow `data/biomes.json`; (4) gallery probe for all 7 biomes. Proof: biome
  suite, process tool test, static floor cache equivalence/probe tests that exist, full suite; director runs the
  gallery probe.

## Data provided (director-authored; committed before launch; protected)
- `data/biomes.json`: biomes (stone + six), section→biome map by boss id, light colours, flicker kind, lighting tint and
  ambient scale, atmosphere pool colour + mote preset, backdrop modulate, mote presets. Read every value from here.
- Approved raw images (outside git; read-only for you): `/Users/borgerding/workspace/Labyrinth/output/peer-benchmark-2026-10-12/raw_art/biomes/`
  - `<biome>_floor_{02,03,05,06}.png` (1536×1024 on #00FF00; templates
    `assets/placeholders/tiles/base_floor_tile_{02,03,05,06}.png` enlarged 5× and centred)
  - `<biome>_pillar.png` (1024×1024 on #00FF00; template `assets/placeholders/tiles/pillar.png` 2× centred) — for
    `iskaldra` the file is `iskaldra_pillar.png` too
  - `<biome>_light.png` (1024×1024 on #00FF00; template `assets/art/tiles/column_torch_left.png` 4× centred)
  - Record each raw file's sha256 in `spec/assets/biomes/raw_sha256.txt`; the prompts live in
    `spec/peer_benchmark/staged/biomes/prompts/` (cite that path in the README).

## Change (numbered, testable)
1. **Processing tool** `tools/process_biome_art.py --raw-dir <dir> --biome <id>|--all`:
   - Key #00FF00 (tolerant of anti-aliased green fringes; no green halo may survive — test it).
   - If the biome has  in data/biomes.json, multiply the keyed floor (or pillar) RGB by those per-channel
     gains before fitting (vaeloryx floors: 0.624/0.600/0.540 — the director's approved darkening of the raw).
   - Floors and pillar: fit the repaint's opaque bbox onto the template's opaque bbox (alpha-bbox fit, box filter), then
     REUSE THE TEMPLATE ALPHA byte-for-byte; RGB inside comes from the repaint (fill any transparent-in-repaint pixels
     inside the template alpha from the nearest repaint pixel).
   - Light: fit onto the template torch's bbox, keep the repaint's own keyed alpha; produce `light_left.png` and a
     mirrored `light_right.png` at the template size (66×121), plus `light_left_idle.png`/`light_right_idle.png` in the
     same sheet format as `column_torch_*_idle.png` (inspect the existing sheet: frame count, grid, resolution — mirror
     it exactly). Idle frames animate per the biome's `light_flicker`: `flame` = brightness of the glow region
     (luminance > 0.55) cycling 0.86–1.06 with a 1-px vertical jitter of that region on alternate frames; `glow` =
     brightness 0.92–1.05, no jitter; `spark` = mostly 0.9 with two frames at 1.25 (flash).
   - Floors: after fitting, colour-match the biome's 4 variants: scale each variant's per-channel mean (inside the
     alpha) toward the median of the 4 variants' per-channel means, gains clamped to 0.85–1.15 (zekarion's variants
     drift in hue today).
   - Then apply the board pixel-density treatment the TEMPLATE received in `spec/assets/board_pixel_density/` (same class,
     grid and resample path as the template; reuse `tools/process_board_density.py`/`tools/pixel_density.py` functions,
     do not fork them). Report each output's orphan share vs its template.
   - Outputs: `assets/art/biomes/<biome>/floor_{02,03,05,06}.png`, `pillar.png`, `light_left.png`, `light_right.png`,
     `light_left_idle.png`, `light_right_idle.png`. Deterministic: re-running produces identical bytes (test).
2. **BiomeLibrary** (`scripts/biome_library.gd`): load `data/biomes.json`; `biome_for_run(run_state, room) -> String`
   (section map runs: the room's section boss id → `section_biomes`; everything else → `default_biome`);
   `floor_textures(id) -> Array[Texture2D]`, `pillar_texture(id)`, `light_texture(id, side)`, `light_idle_sheet(id, side)`
   (stone → today's exact paths), `light_color(id)`, `lighting(id)`, `atmosphere(id)`, `backdrop_modulate(id)`,
   `mote_preset(name)`. Missing biome art falls back to stone per asset (and logs once).
3. **Board.** Every room of a section (combat, guardian, boss, Hearth, treasure, Scavenger, Graftwright, event and the
   section's entry threshold) uses the biome's floors, pillars and lights. Floor variant selection keeps today's
   deterministic per-tile choice, just from the biome's 4 textures. Floor light pools from lights use
   `light_color`. Existing elemental room overlays, surfaces, traps, crates/boxes and doors are unchanged.
4. **Lighting.** The active lighting profile's `tint` is multiplied component-wise by the biome tint and its `ambient`
   by `ambient_scale`; everything else in the profile is unchanged. stone = identity.
5. **Atmosphere.** The warm light pool takes `pool_color`; motes use the preset (color, count, direction, speed range,
   lifetime, spread) — `embers` must equal today's motes exactly. Reduced motion: no motes (as today).
6. **Backdrop.** The hall backdrop behind the board is modulated by `backdrop_modulate`.
7. **Fixture.** `tools/inspection_fixture.py ... --biome <id>` forces the biome for inspection.
8. **Spec.** spec/biomes.md (purpose, data, mapping, processing, how to add a biome) and the provenance README.

## Keep (must not break)
- Today's look for legacy runs and for any run outside a section map: pixel-identical (assert with the existing
  static floor cache equivalence probe/test where possible). Board density probes, shadow cache, occlusion
  transparency of pillars, door rendering, elemental overlays, performance (no per-frame texture loads; cache by
  biome).

## Proof
- `tests/biome_test.gd`: data validation, mapping for all six bosses + legacy, fallback per missing asset, lighting
  composition math, mote preset equality for `embers`.
- `tests/test_process_biome_art.py`: keying (no green fringe), template-alpha identity for floors/pillar, determinism,
  idle sheet format equality with the stone sheet.
- `tests/biome_gallery_probe.gd` (windowed, director runs): one staged combat room (fixed layout: hero + 3 enemies, 2
  pillars with lights, crates) rendered in each of the 7 biomes at 1920×1080, plus a Hearth room in iskaldra.
- Keep green: static floor cache tests/probes, board density tests, full suite.

## Out of scope
- New props beyond floors/pillars/lights, wall/door repaints, new music/SFX, new enemies, rules.
