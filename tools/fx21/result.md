# FX-21 Shadow tile burst · round 1

The revised Shadow hits use five tendrils at 24–38 authored units. Floor bursts use four at 12–20. The remaining tendrils keep their round 0 positions and stagger. The front group keeps the same height reduction within the directed range.

The foot is nine cells wide and tapers to two through the shaft. The top fifth bends toward the tile centre at that width. The body uses `SHADOW[2]`, the outer third uses `SHADOW[0]`, and the two cells facing the tile centre use `SHADOW[3]`. The centre-facing cell in the top quarter uses `SHADOW[4]`. The light edge covers the core where the hook is only two cells wide. The foot keeps its dither into the ink pool.

The pool keeps the same ellipse and colours. It holds full radius through frame 10, drops to half radius at frame 11, and clears at frame 12. Ordered-dither coverage follows the round 0 cadence. The four hit motes, tendril timing, palette and frame 4 reduced-motion still keep their round 0 settings.

## Bake and identity

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fx-21 && python3 tools/fx12/bake_tile_bursts.py /private/tmp/labyrinth_codex/fx-21/round-1/bake
```

Counts are nonempty indexed cells summed across all 13 frames. The legacy column counts all decoded indices, including transparent cells, compared against both `f21b6ff47` and `6bc34dfd2`.

| Tile width (cells) | Shadow hit rear | Shadow hit front | Shadow hit total | Shadow floor rear | Shadow floor front | Shadow floor total | Legacy bytes identical |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 44 | 5,822 | 1,101 | 6,923 | 5,424 | 298 | 5,722 | 1,601,600 |
| 52 | 8,061 | 1,299 | 9,360 | 7,624 | 361 | 7,985 | 2,265,120 |
| 60 | 10,635 | 1,430 | 12,065 | 10,128 | 435 | 10,563 | 2,886,000 |
| 68 | 13,423 | 1,684 | 15,107 | 12,863 | 460 | 13,323 | 3,669,120 |
| 76 | 16,776 | 1,833 | 18,609 | 16,155 | 530 | 16,685 | 4,594,720 |
| 84 | 20,404 | 2,048 | 22,452 | 19,689 | 558 | 20,247 | 5,624,320 |
| 92 | 24,331 | 2,217 | 26,548 | 23,555 | 635 | 24,190 | 6,757,920 |

`FX-21 BAKE IDENTITY: PASS (27398800 legacy palette-index bytes, 40 rows x 13 frames x 7 sizes, zero row shifts)`

Palette entries, tile centres, frame geometry and all row numbers also matched round 0. The rebake updated the seven indexed PNGs, their pixel hashes in the catalog and their approved asset pins.

## Proof for the design owner

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fx-21 && FX21_OUTPUT_ROOT=/private/tmp/labyrinth_codex/fx-21/round-1 tools/fx21/stills.sh
```

The eight takes use the real 1920×1080 RunScene framebuffer, cel look `all` and the combat HUD at 100% UI scale. Each strip has 640×480 crops at 0, 33, 100, 200, 300 and 400 ms after contact. The `family` take compares Shadow, Ice and Fire on three adjacent occupied tiles. The `before` take captures a real Hollow Mimic Shade Bolt on the hero.

The command writes `strip.png`, `native-evidence.png`, `take.json` and `manifest.json` in `/private/tmp/labyrinth_codex/fx-21/round-1/native/<take>/`. The +100 ms nearest-neighbour crops are `native/hero-hit/hero-hit-100ms-2x.png` and `native/family/family-100ms-2x.png`, both 1280×960. This output root keeps the owner's round 0 strips available for comparison.

Round 1 native capture and fight-size inspection remain with the owner. The sandbox supports headless verification.

## Headless verification

| Check | Observed result |
| --- | --- |
| Shadow raster check | `FX-21 SHADOW RASTER: PASS (spread, widths, colours and pool timeline at all 7 sizes)` |
| `tools/fx21/stills.sh --dry-run` | `FX-21 STILLS PLAN: 8 cases, 48 samples, +100 ms family zoom planned` |
| `tools/fx12/verify.gd` via the Godot task runner | `FX-12 VERIFY: 120 checks, 0 failures` and `TEST RESULT: PASS` |
| `python3 tests/test_approved_content_manifest.py` | `Ran 1 test in 18.182s` and `OK` |

Headless case reports are under `/private/tmp/labyrinth_codex/fx-21/round-1/headless/<take>/take.json`. The logs and per-frame Shadow cell counts are in the round 1 output root.

## Chosen defaults

- Seed `211` for hit and `212` for floor, as in round 0.
- The proof uses the existing fixture, crop framing and clock. Round 1 evidence goes to a separate output directory.

## TODO_DESIGN

`TODO_DESIGN_SHADOW_POOL_LAST_FRAME_RADIUS` is resolved by the directed frame 12 endpoint.
