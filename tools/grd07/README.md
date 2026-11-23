# GRD-09 ground contact still study

The GRD-07 capture tool shows six single-tile treatments and one merged-region
column on the production Stone combat board. Columns run left to right from
Fire, Ice, Rubble, Electrified, Stormcoal and plain floor to merged regions.
The hero, Tunnel Crawler, Bone Harrier and Craghide run top to bottom in the
single-tile columns. The merged column places the hero on 2×2 Fire and the
Bone Harrier on 2×2 Ice.

Each style combines unscaled screen bands from seven matched live board passes
at 1920×1080, 100% UI scale and 4× MSAA. The room and actor pose stay fixed.
The release-style ground is captured at the existing 12-second anchor. The pixel
style displays the indexed patches and samples the baked GRD-11 atlas.

## Artifacts

- `grid-off.png` and `grid-pixel.png` show the full studies.
- `<off|pixel>/<surface>/<actor>-crop.png` shows the occupied tile at 3×
  nearest-neighbor magnification. The `merged/fire-crop.png` and
  `merged/ice-crop.png` files include each entire region.
- `contact-<surface>.png` puts release and pixel stills side by side with the
  same row order. `contact-merged.png` contains both merged regions.
- `manifest.json` records the bands, crop geometry, actor footprint alignment,
  texel sizes, depth order, contact-shadow canvas and merged region adjacency.
  The dry run verifies this structure headless and writes the manifest with
  `images_written` set to false. The `raised_stills` lists record the baked row
  IDs, cell sizes and depth passes for occupied and empty tiles.
- `native-metrics.json` reports each style and column, with a breakdown by
  actor, region, and tile. Mean and standard deviation use Rec.601 luminance on
  a 0–255 scale. Coverage comes from matched floor-only and bare-floor
  framebuffer pixels. Outline coverage comes from the same curved stencil
  drawn solid in a separate readback, so transparent atlas paint is visible
  in the difference between the two measures. A separate actor pass preserves
  the historical accent-share comparison. Hiding front layers and reflections
  measures their contribution in the saved still. The contact targets are
  historical references. The report includes separate patch and bare-floor
  means over the same mask for comparison across atlas revisions. The `columns` object pairs measurements as `off` and `pixel`.
  The plain control has no ground samples. Release ground has no separate
  front layer. With `--baseline`, `baseline_comparison` puts the previous
  measurements beside the new ones and records RGBA byte equality for the
  release grid and the unchanged pixel-style crops.
- `visual-proof.json` records the native visual runner's checks for all 61
  PNGs. Use the grid and merged crops to inspect the outer dither fringe, shared
  edges and contact at the unit's feet.

## Run

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/grd-09 &&
  LABYRINTH_CEL_LOOK=all LABYRINTH_GRD03_FIXTURE_ATLASES=0 \
  python3 tools/godot_task_runner.py --task-id grd-09 --stream -- \
    godot --headless --path . --script tools/grd07/capture.gd -- --dry-run
```

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/grd-09 &&
  GRD09_CAPTURE_DIR="$(mktemp -d /private/tmp/labyrinth_codex/grd-09-round1-native.XXXXXX)" &&
  LABYRINTH_CEL_LOOK=all LABYRINTH_GRD03_FIXTURE_ATLASES=0 \
  python3 tools/visual_probe_runner.py \
    --task-id grd-09 --no-headless --display-driver macos --audio-driver Dummy \
    --rendering-method mobile --rendering-driver metal --timeout 120 \
    --godot tools/grd07/native_godot.sh --proof-contract tools/grd07/proof_contract.json \
    --result-manifest "$GRD09_CAPTURE_DIR/visual-proof.json" tools/grd07/capture.gd -- "$GRD09_CAPTURE_DIR" \
    --baseline=/private/tmp/labyrinth_codex/grd-09/native-1122
```

## Study fixture

The dedicated proof camera uses 1.10× zoom on a 26×26 grid to fit seven
columns. Column origins are three diagonal tile steps apart and row
origins are two depth steps apart. Crops pad the footprint bounds by a
quarter tile width. Each board settles for four process frames and two
renderer draws. The native capture has a 120-second limit.

## Historical motion study

The procedural motion study and its silhouette metrics remain reproducible
at `4e350e7b9`. The current game plays the baked sheets. See
[the GRD-11 capture](../grd11/README.md) for the real-fight proof and matched
study draw counts.
