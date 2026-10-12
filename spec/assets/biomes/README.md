# Approved biome paint provenance

Only the director-approved files directly in
`/Users/borgerding/workspace/Labyrinth/output/peer-benchmark-2026-10-12/raw_art/biomes/`
were processed. The `rejected/` and `v2_alt/` directories were not inputs. No art,
audio, icons or fonts were generated or downloaded. The 36 raw images remain
outside Git and read-only; `raw_sha256.txt` records their SHA-256 byte digests.

The director's prompts are preserved at
`spec/peer_benchmark/staged/biomes/prompts/`. The protected runtime source of
names, grades and presentation values is `data/biomes.json`.

Reproduce all 54 PNGs from the approved raw directory:

```bash
python3 tools/process_biome_art.py --raw-dir /Users/borgerding/workspace/Labyrinth/output/peer-benchmark-2026-10-12/raw_art/biomes --all
```

The tool keys green and despills mixed fringes, fits onto the untouched density
source templates by alpha bbox with BOX, fills alpha holes from the nearest
painted sample, applies the protected raw grade before fitting, and matches the
four floor variants toward their median channel means (0.85–1.15 gain clamp).
It calls the existing board-density functions with each template's registered
mode, grid, resample scale and static-family alpha classification. It asserts
that final floor/pillar alpha exactly equals the production template alpha.

Template families are `floor_tiles`, `pillar`, `column_torch_static`, and
`column_torch_idle` in `spec/assets/board_pixel_density/registry.json`; their
untouched sources live below `spec/assets/board_pixel_density/sources/`.
Floors finish at 248×124, pillars at 351×351, static lights at 66×121. Idle sheets
match stone's 752×1376, sixteen row-major 188×344 frames in a 4×4 grid. Each right
frame is mirrored independently, preserving frame order. The existing board
animation timing and side offsets remain unchanged.

Spark sheets use the director-approved zero-based frames 4 and 11 at 1.25,
with the other fourteen frames at 0.9. Flame/glow cycle over the specified
brightness ranges; flame jitters its luminous region up one pixel on alternate
frames. Luminous pixels have Rec.709 luminance greater than 0.55. The director's
Noctyrax floor grade `[1.30, 1.25, 1.35]` is read from `data/biomes.json` and
applied before fitting and variant matching. Noctyrax and Zekarion were
regenerated for feedback 1; their updated measurements follow below.

Processing is deterministic (encoded PNG bytes), tested by processing every
approved set twice and comparing against the shipped bytes. The following
orphan shares are from the shared density metric, over each whole output. They
are measurements, not additional art tuning. The reusable test also verifies
floor/pillar alpha, no green fringe, sheet dimensions and per-frame mirroring.

| Biome | Output | Orphan share | Stone template share |
| --- | --- | ---: | ---: |
| tharokh | floor_02.png | 0.00116530 | 0.00139836 |
| tharokh | floor_03.png | 0.00250378 | 0.00291138 |
| tharokh | floor_05.png | 0.00184593 | 0.00418410 |
| tharokh | floor_06.png | 0.00215863 | 0.00357716 |
| tharokh | light_left.png | 0.03501516 | 0.02735346 |
| tharokh | light_left_idle.png | 0.00000000 | 0.00000855 |
| tharokh | light_right.png | 0.03501516 | 0.02132196 |
| tharokh | light_right_idle.png | 0.00000000 | 0.00003937 |
| tharokh | pillar.png | 0.00185223 | 0.00255197 |
| vyraketh | floor_02.png | 0.00180621 | 0.00139836 |
| vyraketh | floor_03.png | 0.00163037 | 0.00291138 |
| vyraketh | floor_05.png | 0.00215358 | 0.00418410 |
| vyraketh | floor_06.png | 0.00185025 | 0.00357716 |
| vyraketh | light_left.png | 0.02875197 | 0.02735346 |
| vyraketh | light_left_idle.png | 0.00040623 | 0.00000855 |
| vyraketh | light_right.png | 0.02875197 | 0.02132196 |
| vyraketh | light_right_idle.png | 0.00040623 | 0.00003937 |
| vyraketh | pillar.png | 0.00386911 | 0.00255197 |
| vaeloryx | floor_02.png | 0.00238886 | 0.00139836 |
| vaeloryx | floor_03.png | 0.00320252 | 0.00291138 |
| vaeloryx | floor_05.png | 0.00258430 | 0.00418410 |
| vaeloryx | floor_06.png | 0.00388553 | 0.00357716 |
| vaeloryx | light_left.png | 0.01729676 | 0.02735346 |
| vaeloryx | light_left_idle.png | 0.00039347 | 0.00000855 |
| vaeloryx | light_right.png | 0.01729676 | 0.02132196 |
| vaeloryx | light_right_idle.png | 0.00039347 | 0.00003937 |
| vaeloryx | pillar.png | 0.00407491 | 0.00255197 |
| iskaldra | floor_02.png | 0.00291324 | 0.00139836 |
| iskaldra | floor_03.png | 0.00593921 | 0.00291138 |
| iskaldra | floor_05.png | 0.00559931 | 0.00418410 |
| iskaldra | floor_06.png | 0.00333046 | 0.00357716 |
| iskaldra | light_left.png | 0.03055379 | 0.02735346 |
| iskaldra | light_left_idle.png | 0.00005137 | 0.00000855 |
| iskaldra | light_right.png | 0.03055379 | 0.02132196 |
| iskaldra | light_right_idle.png | 0.00005137 | 0.00003937 |
| iskaldra | pillar.png | 0.00724429 | 0.00255197 |
| zekarion | floor_02.png | 0.00291324 | 0.00139836 |
| zekarion | floor_03.png | 0.00361011 | 0.00291138 |
| zekarion | floor_05.png | 0.00344573 | 0.00418410 |
| zekarion | floor_06.png | 0.00345381 | 0.00357716 |
| zekarion | light_left.png | 0.06628844 | 0.02735346 |
| zekarion | light_left_idle.png | 0.00004156 | 0.00000855 |
| zekarion | light_right.png | 0.06628844 | 0.02132196 |
| zekarion | light_right_idle.png | 0.00004156 | 0.00003937 |
| zekarion | pillar.png | 0.00310764 | 0.00255197 |
| noctyrax | floor_02.png | 0.00256365 | 0.00139836 |
| noctyrax | floor_03.png | 0.00337720 | 0.00291138 |
| noctyrax | floor_05.png | 0.00350726 | 0.00418410 |
| noctyrax | floor_06.png | 0.00345381 | 0.00357716 |
| noctyrax | light_left.png | 0.02233169 | 0.02735346 |
| noctyrax | light_left_idle.png | 0.00000000 | 0.00000855 |
| noctyrax | light_right.png | 0.02233169 | 0.02132196 |
| noctyrax | light_right_idle.png | 0.00000000 | 0.00003937 |
| noctyrax | pillar.png | 0.00510393 | 0.00255197 |
