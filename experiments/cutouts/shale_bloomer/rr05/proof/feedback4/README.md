# Feedback 4: connected paint and whole-pose silhouette gates

Wisp passes all current headless pixel gates. Bloomer has no detached components
in any sampled pose, but is **not accepted**: 504 poses still have new enclosed
background holes. Its pixel gate returns 505 errors: those poses plus the named
`TODO_DESIGN_silhouette_front_idle_0012`. No threshold or motion key was relaxed.

## Numbered requirements

1. **Pass.** Visible orphan components are reassigned to the connected neighbour
   with the most actual 8-neighbour contact edges. Ties retain existing layout
   priority. Features are excluded from reassignment. Hidden support copies only
   existing approved RGBA/material texels and is clipped to approved rest alpha.
   Every physical painted node, including hidden nodes, is now one 8-connected
   component: 71 Bloomer and 21 Wisp nodes. Both derives pass; rest identity is
   **0 differing pixels in all four views**. The generic derive path calls the
   source-component gate for every case, without a creature whitelist.
2. **Wisp passes; Bloomer remains blocked.** The pixel gate checks every 60 Hz
   sample of every clip and both views, including death. It rejects any component
   more than 2 px from the largest body and every new enclosed hole >=2 px. Rest
   holes are registered through the adjacent source owner, and each may explain
   at most one posed hole. CPU: Wisp 750 poses pass with no detached pixels or
   new holes; Bloomer 1,008 poses have no detached pixels but 504 fail holes
   (maximum 186 background pixels). The same checks read the full native frame
   manifest, require complete pose coverage/checksums and bind source inputs.
   Orphan-pixel and widened-joint-gap mutations fail in source/CPU/saved-surface
   paths; seven immutable native examples reproduce the supplied counts.
3. **Protected motion preserved.** Overlap margins are derived by sampling:
   Wisp 2 source pixels, Bloomer 7. Crops sharing a bone now share exactly one
   snapped source map, including features and hidden support. Individual crop
   snapping cannot tear underlays off their visible material. Amplitudes,
   channels, keys, clip durations, approved art, masks, owners and reasons are
   unchanged. The remaining Bloomer decision is recorded below, not tuned away.
4. **CPU/native before and CPU after recorded.** `before_after.md`, `.csv` and
   `.json` contain every clip/view for both creatures. Native before uses the
   saved director run 2 Bloomer and completed run 3 Wisp captures. Native after
   requires the director's windowed rerun; no native after values are invented.

## The director's seven poses

Before uses the director's >3 px **8-neighbour grid distance**. This reproduces
all seven worst poses exactly, including their frame indices and clean rear
idle. The new acceptance check conservatively uses Euclidean distance >2 px;
all current CPU after detached counts are zero under either distance metric.
Background components use four-connectivity, dual to foreground eight-connectivity.

| Pose | CPU/native before px | Islands | CPU after px/islands |
| --- | ---: | ---: | ---: |
| front_hit 0020 | 182 / 182 | 2 | 0 / 0 |
| front_death 0030 | 207 / 207 | 10 | 0 / 0 |
| front_shell 0019 | 37 / 37 | 8 | 0 / 0 |
| rear_shell 0047 | 25 / 25 | 15 | 0 / 0 |
| front_move 0006 | 20 / 20 | 3 | 0 / 0 |
| front_idle 0030 | 19 / 19 | 1 | 0 / 0 |
| rear_death 0036 | 29 / 29 | 17 | 0 / 0 |

Wisp's >3 px before table has one 1 px island in front_hit 0004 and front_death
0019; other clip/views are clean. Under the stricter >2 px check, front idle also
has a 1 px before island. All CPU after counts and new holes are zero. The full
per-pose reports retain the CPU/native differences rather than forcing agreement.

## TODO_DESIGN: Bloomer front idle 0012

At phase `0.0714285714285714` (0.2 seconds), four connected background pixels at
canvas `(319,291)` through `(319,294)` remain outside every available static
support projection. Even assigning all approved opaque rest pixels to each
currently painted bone cannot fill this component at the cleaned ownership and
fixed transforms. This is a bound on static underlay extension; it does not
claim that every possible redesign of visible ownership has been exhausted.

The rim comes from `tendril_high_r`, `tendril_low_r` and trunk support. The exact
protected **authored** keys are:

- `idle / tendril_high_r.raise_deg`: `(0,-3), (0.5,5), (1,-3)`.
- `idle / tendril_low_r.raise_deg`: `(0,3), (0.3,-3), (0.75,4), (1,3)`.
- `idle / trunk.lean_deg`: `(0,0), (0.5,1.2), (1,0)`.

The active intervals at this pose are respectively 0→0.5, 0→0.3 and 0→0.5.
`TODO_DESIGN.json` includes the original keys, applied front-view signs, source
selectors, contributors and coordinates. The case data field is
`mq3/proof/continuity.json: TODO_DESIGN`. The gate and promotion guard keep this
blocking. A motion/visible-ownership decision is needed from the design owner.

## Precision regression retained from the completed Wisp run

The director's round 3 Wisp capture completed but its old verification failed
18 source-transform checks, so no Wisp MP4 was produced. The retained native
surfaces exposed float32 texel midpoint ties and half-subpixel vertex ties.
The model now matches those conventions, with immutable front arc_right frames
18/90 and rear arc_right frame 90 fixtures. All 5,544 Wisp and 23,856 Bloomer
saved isolated source surfaces pass the existing source-frame tolerances.

Shimmer explanations use the exact independently validated sampled matrix and
hold that ideal for all six held frames. Re-solving it in float64 had invented
four changed pixels at Wisp frame 96. Held and boundary residuals are now zero
for both current CPU cases; wrong-matrix, held-noise and continuous-idle
mutations remain rejected. This is model correction, not fresh native proof.

## Proof artifacts and verification

Current logs/reports: `output/rr-05/feedback4/`. Current real Godot matrices:
`shale-pixels.json`, `wisp-pixels.json`. Gate results:
`shale-pixel-gates.json` (known failure), `wisp-pixel-gates.json` (pass).
Exact commands, result lines and exit codes are recorded in `verification.json`.
Both full suites passed: Godot `FULL SUITE RUNTIME: 811.269 seconds (budget 900
seconds)` / `TEST RESULT: PASS`; Python `Ran 641 tests in 683.517s` /
`OK (skipped=61)`. Both exit 0. Focused runtime: 21,734 checks, 0 failures;
integration passes; focused Python suites (12 pixel, 7 semantic, 3 raster,
3 owner-script, 6 silhouette tests) all report `OK`. The Bloomer data gate
remains failed as documented above.

CPU-only previews, mechanically composed from current approved part pixels:

- `output/rr-05/feedback4/cpu-after/shale_front_hit_0020.png`
- `output/rr-05/feedback4/cpu-after/shale_front_shell_0019.png`
- `output/rr-05/feedback4/cpu-after/shale_front_idle_0012.png`
- `output/rr-05/feedback4/cpu-after/wisp_front_cast_0000.png`

These are CPU diagnostics, not native captures. Saved native before directories
and the Bloomer MP4 are preserved. Production assets remain unadopted.

## Proof for the design owner

Wisp alone, through fresh native review/MP4, then owner-only promotion, density
adoption, native rest rebake and production captures:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-05 && bash experiments/cutouts/shale_bloomer/rr05/proof_for_design_owner.sh --from-native --creature lightning_wisp
```

The script runs headless acceptance before native work. Bloomer deliberately
stops there until its TODO is resolved. To inspect Bloomer's current candidate
natively without adopting it, use a separate after directory:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-05 && python3 tools/godot_task_runner.py --task-id rr-05 --stream -- godot --headless --path . --script tests/maquette_cutout/pixel_samples.gd -- --case experiments/cutouts/shale_bloomer/mq3 --output /Users/borgerding/workspace/Labyrinth.worktrees/rr-05/output/rr-05/shale-native-after4/pixel_samples.json
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-05 && python3 tools/visual_probe_runner.py --task-id rr-05 --no-headless --display-driver macos --audio-driver Dummy --timeout 900 --expect-size 1920x1080 --proof-contract tests/maquette_cutout/shale_bloomer_render_contract.json tests/maquette_cutout/native_capture.gd -- --case experiments/cutouts/shale_bloomer/mq3 --output /Users/borgerding/workspace/Labyrinth.worktrees/rr-05/output/rr-05/shale-native-after4
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-05 && python3 tools/maquette_cutout_polish.py gate --case experiments/cutouts/shale_bloomer/mq3 --samples output/rr-05/shale-native-after4/pixel_samples.json --native output/rr-05/shale-native-after4 --output output/rr-05/shale-native-after4/pixel_gates.json
```

The final gate is expected to fail the documented holes. After the design
inputs are resolved, run the default script from derive for both creatures.
No inspection launch is included. No windowed command, promote, adoption,
commit, review, publication or task-queue edit was run by the worker.

Chosen defaults: conservative Euclidean distance for the new 2 px gate;
four-connected background holes; stable existing ownership priority on contact
ties; existing proof canvas 512, source offset 128 and step distance 96. The
historical grid-distance comparison is fixed by the supplied evidence. The new
2 px / 2-pixel acceptance limits and 8-connectivity are director requirements.
The derived overlap margins are recorded data, not manually chosen tuning.
