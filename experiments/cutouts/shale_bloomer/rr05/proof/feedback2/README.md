# rr-05 feedback 2: saved-native diagnosis

The failure is in the CPU sampling model. Runtime transforms, presentation
quantization, feature pixels and hidden-fill transforms are unchanged.

The original model used Pillow inverse-affine nearest sampling. Pillow 11.3.0
uses 16.16 coefficients in its affine fast path:
https://github.com/python-pillow/Pillow/blob/11.3.0/src/libImaging/Geometry.c#L883-L1008
That path also changes rounding when a fixed-canvas image is cropped before
sampling. It does not reproduce the captured Metal quad rasterization: eight
fractional vertex bits, then source UV interpolation over the top-left to
bottom-right diagonal. The replacement models those two triangles at absolute
pixel centers; it copies exact source texels, with all gate tolerances unchanged.

Concrete evidence (bounds are left/top/right/bottom, right/bottom exclusive):

| Surface | Old expected bounds | Captured bounds | Old changed pixels | Existing allowance | Fixed changed pixels |
| --- | --- | --- | ---: | ---: | ---: |
| front/root_stem_r, idle frame 61, after | [204,243,308,364) | [204,243,308,364) | 9 | 6.87 | 0 |
| front/tendril_high_r, idle frame 35, before | [272,214,332,285) | [272,214,332,285) | 14 | 9.53 | 0 |
| front/feature_amber_right, idle frame 53, before | [278,268,296,290) | [278,268,296,290) | 4 | 3.96 | 0 |

A second precision mismatch affected two source comparisons. The old gate used
matrices from the separate headless sampler instead of the native surfaces'
recorded staging matrices. The rigs have different world origins; float32
cancellation differs (for example by 0.000046 source pixels), enough to straddle a
1/256-pixel vertex-rounding boundary. Native pixel replay now uses its own
recorded matrices. Those matrices still pass the independent authored-transform
oracle at the existing 0.0001 tolerance; they are not trusted in place of it.

Retained native PNG fixtures cover continuous rotation, a 1.5 degree step, an
amber feature and a hidden-fill node. The original model failed all four exact
pixel assertions and three crop-invariance assertions: `Ran 2 tests`,
`FAILED (failures=7)`, exit 1 (`native_regression_before.log`). The corrected
model passes those assertions. A third test exercises native staging matrices;
substituting the headless matrices deliberately fails native source matching.
Fixtures and their original SHA256s are under
`tests/maquette_cutout/native_fixtures/`; no PNG pixels were changed.

Full saved-capture replay: **PASS, zero errors** across 11,928 part/frame pairs
(23,856 original PNGs), including every original failure. Native held and
boundary unexplained residual are both **zero** after correction. The original
source agreement allowance remains 1% plus one pixel, the boundary allowance
remains 1%, and held frames still require exactly zero. See
`saved_capture_replay.json` for complete per-part metrics.

Original director manifests and log are archived here unchanged. This replay
is diagnostic use of existing renderer pixels with a corrected model; it is
not a new renderer run and does not relabel stale input bindings as current.
A fresh owner capture remains required with the final model's input hashes.

The owner script accepts `--from-native` to skip both successful derives,
then runs both native review MP4s, promote, density adoption, native rest rebake,
and production captures. Inspection launch has been removed and remains
separate. No windowed command or adoption was run by this worker.

Chosen non-player-visible model constants: `SUBPIXEL_BITS = 8`,
`SUBPIXEL_SCALE = 256`, `QUAD_TRIANGLES = ((0,1,2),(0,2,3))`; these reproduce
the retained Metal captures. No tolerances, director inputs or runtime values
were changed. TODO_DESIGN: none.

## Focused verification

Both current feature/shimmer gates and authored-motion gates pass with zero
errors. All features retain their declared single node and exact source pixels
(504 poses per Bloomer view; 375 per Wisp view). Current CPU after-residuals are
zero for held frames and boundaries on both creatures. Exact command arguments
and result lines are in `focused_results.json`.

```text
MAQUETTE CUTOUT: PASS (15374 checks, 0 failures; headless logic only)
MAQUETTE INTEGRATION: PASS (0 failures)
Ran 10 tests in 29.592s
OK
Ran 7 tests in 56.496s
OK
Ran 3 tests in 0.056s
OK
```

Production logic passed for 1171 Bloomer and 1149 Wisp frames using unchanged
production assets. Both native capture probes passed `--validate-only` in
headless mode; this is parsing/data validation, not a new renderer capture.
The script passes `bash -n`, `--help`, and a logging-stub control-flow probe
(default and `--from-native`; invalid arguments rejected; no inspection command).
The full Godot runner exited 0:

```text
FULL SUITE RUNTIME: 874.253 seconds (budget 900 seconds)
TEST RESULT: PASS
```

The full Python runner exited 0:

```text
GAOLER REBUILD: PASS (882 files)
Ran 630 tests in 522.085s
OK (skipped=61)
```

`suite_results.json` records both exact commands and exit codes. Final input
bindings and case baselines pass for both creatures. The original and current
proof tolerance dictionaries are identical; all twelve supplied feature files,
every case input and all player runtime files retain their director-run hashes.
`git diff --check`, owner-script `bash -n`, and the output check pass:
`OUTPUT GDIGNORE: PASS (14 folders; 3 referenced roots)`.
The stale capture directory remains absent. All changes remain uncommitted.

## Fresh owner proof

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-05 && bash experiments/cutouts/shale_bloomer/rr05/proof_for_design_owner.sh --from-native
```

This writes fresh `output/rr-05/{shale,wisp}-native/` captures and the two
`output/rr-05/{shale_bloomer,lightning_wisp}_review.mp4` videos, then performs
promotion/adoption/rebake and production captures. Inspection is separate.
