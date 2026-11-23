# Shots

`shot_44.png` … `shot_92.png` (fx-14) are director-authored procedural art, one sheet per tile width in cells, one palette index per texel (0 is empty): `tools/fx14/bake_shots.py` (deterministic numpy and PIL shapes, no external source). `data/shots.json` carries the palette, each sheet's geometry and pixel SHA-256, and which action throws what.
