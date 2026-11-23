# Ground decal atlases

The director installed these runtime PNGs in `8592ea81e` and confirmed the native gallery in grd-03 feedback 1. The staged approval ledger, prompts, feedback, references, and sheets are in `spec/peer_benchmark/staged/grd/` at revision `9a6f81217e0f0895d02621b6ee117e3464e45c8b` on `codex/peer-benchmark`.

| Runtime atlas | Source sheet and job | Prompts | Source sheet SHA-256 | Runtime SHA-256 |
| --- | --- | --- | --- | --- |
| `fire_decals.png` | `approved/fire_v2.png`, img-grd-fire-1 round 1 | `prompt_fire.md`, `feedback_fire_1.md` | `d03f78f41df3dced84ecafe1af68b23c7c3f163f097040e000f7533412f26a46` | `d1862e4ef5d9543aebd9218d78875f58c1eeb4c9eb5a3b0f9a74f2787be2493b` |
| `electrified_decals.png` | `approved/electric_v1.png`, img-grd-electric-1 round 0 | `prompt_electric.md` | `57c45518923c73a107c129af36c1fe06aa8d8a8cc200e43880f2fe8fe2bcc92f` | `4fca5bdccfb47a031ccd7043ce5b294c43e151935c0c947bf3f87e329a7ec17e` |
| `ice_decals.png` | `approved/ice_v4.png`, img-grd-ice-4 round 0 (replaces ice_v3 after ground-fx-2: a solid slab with cracks) | `prompt_ice4.md` | `f8aacea170667e9919093fcfab6ad328f434fd364d73a71ba28ec6781c72899f` | `230f9a8f16b5fda61413463a6cbd8fd88196789db7560b1e191efaf109fff8d4` |
| `rubble_decals.png` | `approved/rubble_v1.png`, img-grd-rubble-1 round 0 | `prompt_rubble.md` | `69fe5c8e76252900910e4cd7df6b2a86865b6b85911f2d6a4983e96568dbbe44` | `38e109493f649b8efd3ee41444bdceaeaa6cfd54c75d42a959acb66b50c2a31b` |

All three jobs used `refs/ref_attack_fire_pixel.png` and `refs/ref_hero_on_floor.png`. The staged ledger records approval at game scale on 2026-11-17. Electrified and the Ice replacement were approved by the director at game scale on 2026-11-18 (staged revision 73e053631) after the owner's ground-fx-1 notes.

The director's staged `build_atlases.py` keyed the green backgrounds, sampled the 4×4 source art pixels, quantized each sample to its vfx-01 ramp, and packed the indexed decals. The grd-05 copy at `tools/build_atlases.py` added path distance and sector metadata in G and B of the installed Electrified atlas. Its R and alpha channels still match the director's original runtime PNG, SHA-256 `a16878c4bdad0fa7ce33e60296326ad9e2c4d04f44f84b36d83f3b09a98b4147`. The renderer reads the rectangles from `data/ground_surface_style.json` and the ramp colours from `data/vfx_pixel_style.json`. Each atlas texel maps to one vfx-01 cell.

`ground_fx_44.png` … `ground_fx_92.png` (grd-11) are director-authored procedural art, one sheet per tile width in cells, one palette index per texel: `tools/grd11/bake_ground_fx.py` (deterministic numpy simulation and branching discharges, no external source) with the vfx-01 fire and lightning ramps; `data/ground_fx_atlas.json` carries the palette, row names, and each sheet's geometry and pixel SHA-256.
