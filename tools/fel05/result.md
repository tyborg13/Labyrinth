# fel-05 feedback 3

Implemented in the prepared `codex/fel-05` worktree over round 2 (`ba82913e9`). The changes are uncommitted. I inspected the release and round 2 Quick Stab frame at −01, and the Warden frames from −02 through +05.

## Acceptance

| Feedback | Implementation and witness |
| --- | --- |
| 1. Warm strike palette | The authored five-color `strike` ramp is in the style JSON. An un-elemented trail selects it. The elemental ramp bindings and the neutral fallback are covered by the witness, including Fire and Lightning sweep submissions. Magic Purge's legacy palette remains pinned. |
| 2. Crescent colors | The tip cell uses step 4, the next two cells use step 3, and the rest use step 2. The hero witness measured `[4, 3, 3, 2, 2]` across the five-cell midpoint. Streak sections retain a two-cell head and one-cell tail with the same cross-width rule. |
| 3. Hilt-side smear | The visible sweep and arc sections carry the same inward path into the smear, capped at 60% of the projected blade length. The two adjacent cells use 50% × envelope coverage and the cells beyond them use 25% × envelope coverage. A shared-grid shader either discards the cell or emits the opaque step-2 color. The Warden's actual playback and a straight edge-on fixture both show occupied smear cells within the reach cap. |
| 4. Clean runs | The raster removes redundant elbows from the tip path and keeps the crescent width single-peaked. The Bayer test moves the last row's width boundaries without producing an isolated widened section. The witness checks both hero and Warden profiles and checks one-cell runs for doubled corners. |
| 5. Tapered contact star | The original anchor and contact window feed a one-cell center and four tapered arms. The witness checked the full offsets and colors at ages 0.2, 0.5, and 0.8, with 17, 9, and 5 cells. |
| 6. Scope and cost | Claw spacing, area raster paths, spark positions and size rules, reduced motion, and frame timing retain their round 2 behavior. The direct painter submits cached rectangular spans and uses one shared coverage shader. It does not bring back an offscreen trail target for sweeps. Warmup exercises the shader before combat and idle trail frames have no active draw. |

## Native performance reference

The director's round 2 run passed all three pairs. Its redrawn medians were 81–97 µs before and 46–67 µs after. Its live-frame after medians were 41–66 µs. Those timings predate this patch. See [the director's timing report](captures/native.QcukmM/effect-overlay.md).

The current launcher retains the same fixture, counters, and before/after, after/before, before/after order. Native visual acceptance and the 1.5× bound for feedback 3 are pending in the windowless sandbox.

## Proof for the design owner

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/fel-05 && tools/fel05/native.sh /Users/borgerding/workspace/Labyrinth.worktrees/fel-03
```

The launcher uses the original fel-03 capture and contract at 1920×1080 and 100% UI scale. It writes the same matched strips and captions, plus the three timing pairs and `effect-overlay.md`. Its `comparisons/` contains four PNGs, one for each of frames −01 and 00 on Quick Stab and Crushing Step. Each shows the 4× nearest-neighbour native-pixel crop from release on the left and the same crop from the revised branch on the right. The reference is the requested fel-03 `native.0uBNGs` capture.

## Changed files

- `data/vfx_pixel_style.json`
- `scripts/pixel_fx_layer.gd`, `scripts/pixel_fx_lines.gd`, `scripts/strike_trail_fx.gd`, `scripts/strike_trail_layer.gd`
- `shaders/pixel_fx_trail_coverage.gdshader` and its UID
- `tools/fel05/witness.gd`, `tools/fel05/native.sh`, `tools/fel05/compare_zooms.gd` and its UID, and this report

## TODO_DESIGN placeholders

None.

## Chosen defaults

- The comparison script crops Quick Stab at native strip coordinates `(212, 97, 128, 138)` and Crushing Step at `(148, 48, 82, 146)`. The crop and enlargement affect only proof images.
- The shader warmup draws one disposable cell in an off phase of the Bayer pattern.
- The edge-on witness fixture uses a 20-cell test blade parallel to its tip path. The native comparison uses the director-supplied captures as references.

## Checks

- Final headless witness exited 0 with `FEL05 WITNESS PASS cases=8 failures=0`, `FEL05 CRESCENT WIDTHS [1, 4, 5, 3, 1] STRIKE STEPS [4, 3, 3, 2, 2]`, and `FEL05 STAR CELL COUNTS [17, 9, 5]`. Quarter marks are snapped to the nearest sampled path cell. See `/private/tmp/labyrinth_codex/fel05-feedback3-witness-handoff.log`.
- `tools/fel05/native.sh --dry-run /Users/borgerding/workspace/Labyrinth.worktrees/fel-03` exited 0. It reported `FEL03 DRY RUN PASS strips=5 captions=8`, `FEL05 ZOOM COMPARISONS PASS frames=4 scale=4x release=left after=right`, and `FEL05 DRY TIMING REPORT pairs=3 within_target=0`. The dummy renderer's baseline medians were 8–25 µs, and the revised medians for the two strikes were 70/52, 60/51, and 226/165 µs. This diagnostic does not establish a native pass. See [the dry timing report](captures/dry.A3aKYO/effect-overlay-dry.md) and the log at `/private/tmp/labyrinth_codex/fel05-feedback3-native-dry.log`.
- The four dry comparison files use release and archived round 2 frames as test input. A separate pixel comparison printed `FEL05 ZOOM PIXEL CHECK PASS four_comparisons eight_exact_halves`. The files are under `tools/fel05/captures/dry.A3aKYO/comparison-check/`.
- The RR48 registration test reported `RR48 STRIKE REGISTRATION: PASS (20 checks; production registry and every supported facing)`. Four affected visual probes passed headless parsing with `FEL05 FOCUSED PROBE PARSE PASS probes=4`.
- UI lint reported `Ran 25 tests in 14.691s` and `OK`. The data audit reported `FEL05 STYLE DATA PASS only authored round 3 changes`. Bash syntax and `git diff --check` passed.
- The repository sidecar audit reported `Ran 19 tests in 10.370s` and `FAILED (failures=1)`. The three missing PNG sidecars belong to director review screenshots already tracked at `ba82913e9`. The new shader and zoom tool each have a UID sidecar.
