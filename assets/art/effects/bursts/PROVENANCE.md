# Tile bursts

`tile_burst_44.png` … `tile_burst_92.png` (fx-12) are director-authored procedural art, one sheet per tile width in cells, one palette index per texel (0 is empty): `tools/fx12/bake_tile_bursts.py` (deterministic numpy particles and slashes, no external source). `data/tile_bursts.json` carries the palette, the row names, each sheet's geometry and pixel SHA-256, and which action uses which burst.

# Effects on a unit

`self_burst_44.png` … `self_burst_92.png` (fx-13): Block, Stoneskin, heal, buff, Mantle, Illusion, summon and Expose, same format: `tools/fx13/bake_self_bursts.py` (deterministic numpy shapes, no external source), `data/self_bursts.json`.

# Acquisition burst

`acquisition_burst_048.png` … `acquisition_burst_208.png` (fnd-01): the light behind a found item, piece of gear or card, one sheet per radius in cells, palette indices 1–5 coloured at draw time: `tools/fnd01/bake_acquisition_burst.py` (deterministic numpy rays, no external source), `data/acquisition_bursts.json`.
