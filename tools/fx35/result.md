# FX-35 Shadow stain

The hit and floor rows use the directed `.28` and `.42` central radii, seeded three- and five-lobe distortion and shallow foot blots for visible tendrils. The central stain grows through frame 2, holds through frame 10, halves on frame 11 and clears on frame 12. The rear pool uses `SHADOW[0]` with a `.6` dither cap and a one-cell `SHADOW[1]` rim at half coverage.

## 1. Bake identity

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fx-35 && python3 tools/fx12/bake_tile_bursts.py /private/tmp/labyrinth_codex/fx-35/bake
cd /Users/borgerding/workspace/Labyrinth.worktrees/fx-35 && PYTHONDONTWRITEBYTECODE=1 python3 tools/fx35/measure.py
```

```text
FX-35 TENDRIL CELLS CHANGED OUTSIDE FORMER POOL: 0 (includes hit motes)
FX-35 BAKE IDENTITY: PASS (27398800 non-Shadow palette-index bytes, 40 rows x 13 frames x 7 sizes, zero row shifts)
```

The comparison reads `codex/fx-34` at `0b4515958`. Pool-free tendril and mote renders also match across all frames. The palette, tile centres, frame geometry and row numbers match the base.

## 2. Frame 4 measurements

Counts and widths use the visible pool-only raster, including the foot blots and rim. Raggedness is the maximum divided by the minimum outer radius of the undithered union over 64 evenly spaced angles in 2:1 board space.

| Tile width | Version | Pool cells old → new | Cell ratio | Width old → new | Width ratio | Raggedness |
| ---: | --- | ---: | ---: | ---: | ---: | ---: |
| 44 | hit | 540 → 106 | 19.6% | 38 → 27 | 71.1% | 2.28 |
| 44 | floor | 540 → 102 | 18.9% | 38 → 24 | 63.2% | 2.12 |
| 52 | hit | 768 → 138 | 18.0% | 44 → 30 | 68.2% | 2.17 |
| 52 | floor | 768 → 130 | 16.9% | 44 → 26 | 59.1% | 2.04 |
| 60 | hit | 1024 → 178 | 17.4% | 50 → 34 | 68.0% | 2.10 |
| 60 | floor | 1024 → 173 | 16.9% | 50 → 31 | 62.0% | 1.99 |
| 68 | hit | 1300 → 224 | 17.2% | 58 → 38 | 65.5% | 2.04 |
| 68 | floor | 1300 → 216 | 16.6% | 58 → 35 | 60.3% | 1.95 |
| 76 | hit | 1640 → 270 | 16.5% | 64 → 41 | 64.1% | 1.99 |
| 76 | floor | 1640 → 271 | 16.5% | 64 → 39 | 60.9% | 1.94 |
| 84 | hit | 2004 → 334 | 16.7% | 72 → 45 | 62.5% | 1.96 |
| 84 | floor | 2004 → 325 | 16.2% | 72 → 43 | 59.7% | 1.94 |
| 92 | hit | 2400 → 388 | 16.2% | 78 → 48 | 61.5% | 1.94 |
| 92 | floor | 2400 → 384 | 16.0% | 78 → 47 | 60.3% | 1.94 |

```text
FX-35 WIDTH TARGET: 0/14 within 45–55%
FX-35 POOL COUNT AND RAGGEDNESS: PASS
```

The undistorted full central diameter is `.42 / .85`, or 49.4% of the old diameter. The angular lobes and required blots expand that bound. At tile width 44, the two outer hit tendril bases span 20.2 cells before adding their 6.3-cell-wide blots, while the upper width target is 20.9 cells. The bake preserves the specified radii, lobe amplitudes, blot widths and tendril bases.

## 3. Catalog and pins

All seven atlas entries use the rebaked pixel hashes in `data/tile_bursts.json` and Git blob hashes in `tests/approved_asset_pins.json`. The measurement verifies both hashes for every atlas on both sides of the comparison.

The default group ran `test_approved_content_manifest.ApprovedContentManifestTests.test_approved_content` in the successful suite. The log reports `MODULE test_approved_content_manifest: 12.264s` and `OK`.

## 4. Proof for the design owner

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fx-35 && /private/tmp/labyrinth_codex/fx-35/native.sh
```

The capture inherits the fx-25 Hollow Mimic three-tile area and Closing Shade on the hero. It uses `LABYRINTH_CEL_LOOK=all`, an exact 1920×1080 SubViewport, 100% UI scale and the 60 fps game-speed clock. It stages the catalog and source atlases for both revisions so the playback selects the correct pixels even with a shared import cache.

Each `/private/tmp/labyrinth_codex/fx-35/native/{before,after}/{area_ranged,closing_shade}/` folder will contain `strip.png` with four 640×480 crops at contact and +100, +233 and +366 ms, `100ms-2x.png`, `native-evidence.png`, `clip.mp4`, `take.json` and `manifest.json`. Windowed files await the director’s run.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fx-35 && /private/tmp/labyrinth_codex/fx-35/native.sh --dry-run
```

```text
FX-35 TAKE PLAN: area_ranged contact=7 samples=[7, 13, 21, 29] clip=240 frames; before/after identical
FX-35 TAKE PLAN: closing_shade contact=19 samples=[19, 25, 33, 41] clip=240 frames; before/after identical
FX-35 NATIVE DRY RUN: PASS (2 before/after pairs) /private/tmp/labyrinth_codex/fx-35/headless
```

The headless output contains `take.json` under `{before,after}/{area_ranged,closing_shade}/`. Godot logged a macOS system certificate lookup diagnostic in the probe runs. Both staged projects passed the visual runner’s import freshness check.

## Verification

| Check | Observed result |
| --- | --- |
| FX-12 verifier against the staged after project | `FX-12 VERIFY: 120 checks, 0 failures` and `TEST RESULT: PASS` |
| `python3 tests/test_ui_identity_lint.py` | `Ran 25 tests in 6.534s` and `OK` |
| Python default group in four shards | `SELECTED MODULES: 22 of 58`, `Ran 194 tests in 28.001s` and `OK` |
| Rules text lint in the default group | `PASS: Rules text lint (16 existing hits)` |

The Python default group produced its summary and logs under `/private/tmp/labyrinth_codex/fx-35/python-default/`. Git sandbox permissions blocked the runner’s optional timing-cache update after the suite completed.

## Chosen defaults

- The edge measurement uses 64 radial intervals per raster cell and the brief’s 64 angular samples.
- Captures inherit the 640×480 crop, four-second silent clip and 300-second launcher timeout from fx-25.

## TODO_DESIGN and open issues

No `TODO_DESIGN_*` placeholders. The full footprint width exceeds the 55% target and the native renderer capture remains open.
