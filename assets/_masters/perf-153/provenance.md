# perf-153 UI texture provenance

The masters below are byte-for-byte copies of the pre-resize production PNGs. Paths
in the table are relative to this folder for the masters and to `assets/art/` for
the runtime copies. Godot skips this folder via `.gdignore`.

`python3 tools/perf153/resize_textures.py` rebuilds the runtime copies using
Pillow 11.3.0 and NumPy 2.0.2. The script converts sRGB to linear light,
premultiplies by alpha, filters four 32-bit float channels with Lanczos, then
unpremultiplies and quantizes to straight-alpha sRGB in the original RGB or RGBA
mode. The PNGs keep the existing Godot import settings.

The 17 sibling map icons are 1254×1254 (14) or 1024×1024 (3). All exceed the
brief's 128-pixel limit, so Ember Hoarder uses the 128×128 fallback. None of the
six paths is in the cel-look inventory.

| Path | Master | Runtime | Master SHA-256 | Runtime SHA-256 |
| --- | --- | --- | --- | --- |
| `ui/campfire_choice_embrace_v2.png` | 1254×1254 | 640×640 | `7f602d0b2475466b63cd73a80b88fd2928875b3fa2bda44cf5eae5fac57ec211` | `65e997ce82ea290c5d153ec5a907930b68ab4ab20b5368832d6f7c86abcd414a` |
| `ui/campfire_choice_linger_v2.png` | 1254×1254 | 640×640 | `eea8e41083d5943a6829012d773ce88abca31343c8f9dbd87ec8df8abb16d86c` | `65cd304c8da3623d9ac7c2db2f229c2924271124c4e6cc0244008007e57d244a` |
| `ui/campfire_choice_purge_v2.png` | 1254×1254 | 640×640 | `67b26215fe7f0e82998a48dff6374c2b231f4b06cda8053d1e9812fc10960896` | `5469d66d82959deb92b72f5b0198d1c41c1faf930db0228bda5042d3a59282a3` |
| `ui/campfire_choice_strength_v2.png` | 1254×1254 | 640×640 | `57d2682ed0930e8168339af4f28c9159444423ca2a375f34c8b9e686b172cd24` | `a505deb7ebc36e177e26e3b8d8c1484ff2b999f8cdc57a1c866867bb5dd6d8cf` |
| `ui/graftwright/ritual_clasp.png` | 2172×724 | 744×248 | `9432fb0201c8442d769d4b8c1d2c1b2458468bcb40886b8851602e620f0d33ac` | `6cacc8ebbf62e0bace350b60356d81ee55919fe00483da4bacd694e03ef6ef95` |
| `icons/map/ember_hoarder.png` | 1024×1024 | 128×128 | `a4807c1d74aab343a6c5113c764c530374bb80dbfd9c8f697bd02c8fc3005caf` | `6d8c67d489d0e8f5c8a3c9a2082c2f0fe1ebecbc82313afc3e1f1c0493e93a59` |
