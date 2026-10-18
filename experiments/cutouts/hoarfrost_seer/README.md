# rr-07 — Hoarfrost Seer and Arc Thrall

The director's feedback 1 is recorded in both `mq5/rig_recipe.json` files.
The Seer front raw matches `5bafa6be8a1d3a4192494dbc02002f35117c413b35dfae33504fc8ef419056f0`.
Both rigs are integrated into production. Native acceptance remains director-owned;
no windowed run, screenshot or MP4 was produced by this worker.
The director has since supplied native captures. The [feedback-3 handoff](mq5/proof/feedback3/README.md)
records the resolved invalid-tie policy, retained edge fixture, per-part/frame
counts, current proof and commands to resume at review without recapturing.
The feedback-2 records remain historical evidence for the 1/512 tie band.

## Requirement evidence

1. **Committed deliveries.** Seer: 35 required files; Thrall: 39. Every solo,
   parts/clay image and joint file matches the committed capture manifest. Pure
   Python compilation reproduces projected joints within 0.004673 raw pixels.
   All four approved registration sources pass. No Blender process, art
   generation, download, new font, icon or audio is involved. Each case contains
   a byte-identical copy of the entire protected rr-07 motion file.
2. **Rigs.** Ownership comes from categorical emission colours within native
   solos. AA fringes cannot seed a remote label. Hidden requests, immutable fill
   previews, same-material approved texel donors, connected physical crops and
   rr-05 seam bands are retained. Genuine occluded clothing/prop sections stay
   on their director-assigned bones: notably both staff sections and both
   visible loincloth sections. Inferred fringe islands outside a material's
   entire native solo use rr-05 connected-neighbour cleanup. Source coordinates
   and approved RGBA never move. Every physical crop is connected. Both views
   of both rigs reconstruct the approved processed art with **0 differing pixels**.
   Seer uses the smallest passing support margin, 15 source pixels; Thrall uses
   zero. Failed trials may be rejected from a subset; acceptance requires every
   60 Hz pose, including death.
3. **Features.** Whole features have one physical node, one owning bone, filled
   holes and a one-pixel rim clipped to approved opaque paint. Every outline
   crop below was inspected. Source/label disagreement is reported rather than
   repaired by moving paint.
4. **Production.** `assets/units/{hoarfrost_seer,arc_thrall}_cutout/` contains the
   production layouts, parts, compiled motion, masks, rest snapshots and runtime
   adapters. Board, pre-battle, inspection and turn portraits share the rr-05
   renderer. Existing enemy definitions, intent tuning, effects, sounds,
   analytics and saves are preserved. Native-joint floor registrations and
   mathematical action bounds feed existing framing. The bounds subtract tile
   travel already represented by `unit_world_positions`. Density sources,
   treatment, registrations, identity rest entries and shadow cache are updated.
   Four **native density rest rebake records remain pending**; none was fabricated.
5. **Gates.** Both independent signed-bone gates pass at authored keys, midpoints
   and contact (304 Seer / 234 Thrall sampled poses). The unchanged rr-05 pixel
   gates pass over all 1,266 / 930 sampled poses. Feature integrity, connected
   parts, silhouette, seams, exposed derived dark slabs and rest identity pass.
   Presented held and boundary unexplained residuals are both **zero**. Native
   re-verification passes both creatures after director feedback 3. The one
   Thrall outer-edge invalid tie is counted under the existing raster allowance.
   Production rendered-frame evidence still awaits the director.
   The independent oracle catches broken compiler signs; mutations also cover
   changed applied bones, missing contact, transparent features, frozen idle
   and omitted actions. Existing rr-05 mutation coverage remains in the full suite.

## Feature masks

Counts include the rim and filled opaque holes.

| Feature / owner | Front pixels / inspected crop | Rear pixels / inspected crop | Pixels outside native label (front / rear) |
| --- | --- | --- | --- |
| Seer crystal / `staff_crystal` | [921](mq5/proof/features/front_ice_crystal_outline.png) | [1171](mq5/proof/features/rear_ice_crystal_outline.png) | 180 / 287 |
| Thrall upper spark / `club` → `hand_near` | [97](../arc_thrall/mq5/proof/features/front_spark_upper_outline.png) | [162](../arc_thrall/mq5/proof/features/rear_spark_upper_outline.png) | 12 / 9 |
| Thrall lower spark / `club` → `hand_near` | [127](../arc_thrall/mq5/proof/features/front_spark_lower_outline.png) | [106](../arc_thrall/mq5/proof/features/rear_spark_lower_outline.png) | 21 / 14 |
| Thrall chain stub / `collar` | [257](../arc_thrall/mq5/proof/features/front_chain_stub_outline.png) | 0, explicitly occluded | 199 / 0 |

Each case's `proof/registration_disagreements.json` retains these categorical
mismatches. `proof/pixels_gates.json` checks the exact source mask/RGBA on every
sampled pose, including correct ownership and no split feature nodes.

## Clip integration

| Creature | Intent / action | Clip |
| --- | --- | --- |
| Seer | `icefall:icefall_mark` | `mark` |
| Seer | `icefall_land:icefall_land` | `land` |
| Seer | `rime_bolt:ranged` | `bolt` |
| Seer | `withdraw:move_away`, then `withdraw:block` | `move`, then `ward` |
| Thrall | `tether:tether_beam` | `tether`, acting Thrall only |
| Thrall | `arc_jab:move_toward`, then `arc_jab:melee` | `move`, then `jab` |

The existing feedback boundary maps exactly to each authored contact. Special
Icefall/tether/status adapters retain existing FX durations and outcome helpers;
marks, damage/status feedback and beam start use contact. The partner's renderer
never receives the acting Thrall's tether clip. Real resolver steps drive
`tests/rr07/production_capture.gd`; its headless logic reports contain 1,607 Seer
and 1,053 Thrall recorded callback frames, with at least six changing poses per
clip and exact contact. These reports are **not native pixel captures**.

Fractional native joints expose float32 accumulation and exact half-angle ties.
The new rigs retain authored float64 angle ties and compensate parent
accumulation before final pixel snapping. The independent local/global Bone2D
oracle and the existing transform tolerances remain unchanged. Historical rigs
do not enable this path. All additional runtime/authoring sources are bound into
both Python and Godot proof manifests through case-local `runtime_paths`.

## Headless verification

Current complete logs and exact result lines are in each case's
`proof/verification_results.json`, `proof/full_godot.log`, `proof/full_python.log`
and `proof/focused_tests.log`.

```text
MAIN BODY ASSERTIONS: 378792
FULL SUITE RUNTIME: 418.548 seconds (budget 900 seconds)
TEST RESULT: PASS
Ran 839 tests in 737.306s
FAILED (failures=1, skipped=63)
```

Python's only failure is the shipped-density rest check: four rebake records
await the director's native renderer. All other runnable checks pass. An
intermediate Godot run hit the existing hero-targeting-arrow assertion (1.03 px
against its 1 px limit); its assertions remain unchanged. The independent rerun
and final full suite passed. Both intermediate logs are retained in `proof/history/`.

Already observed on the implemented rigs:

```text
RR07 RUNTIME: PASS (120088 checks, 0 failures; headless logic only)
Ran 19 tests in 77.539s
OK
RR07 MOTION GATES: PASS (hoarfrost_seer; 0 errors)
RR07 MOTION GATES: PASS (arc_thrall; 0 errors)
RR07 PIXELS GATES: PASS (hoarfrost_seer; 0 errors)
RR07 PIXELS GATES: PASS (arc_thrall; 0 errors)
RR07 PRODUCTION GATES: PASS (hoarfrost_seer; 0 errors)
RR07 PRODUCTION GATES: PASS (arc_thrall; 0 errors)
Art identity: Ran 111 tests in 36.332s — OK
Icon identity: Ran 7 tests in 0.060s — OK
```

The old static roster tests now explicitly expect these two live renderers and
34 cutouts / 9 stills. The travel registration test checks protected per-step
clock semantics for rr-07. Its original neutral-centroid assertions are retained.
The supplemental runner retains all 120 previous programs and adds the rr-07
runtime program. No pre-existing failing assertion was removed or weakened.

## Proof for the design owner

Run from the rr-07 worktree root:

```sh
sh experiments/cutouts/hoarfrost_seer/rr07_proof.sh hoarfrost_seer
sh experiments/cutouts/hoarfrost_seer/rr07_proof.sh arc_thrall
python3 tools/process_board_density.py --check
```

For the director's already captured feedback-2 proof, use the same commands with
`--from-review` after each creature. This skips native rest, sampling and capture;
the review composer re-verifies the retained evidence before encoding.

[The script](rr07_proof.sh) contains the exact per-creature command sequence:
native rest; signed-motion sampler/gate; all 60 Hz native frames plus isolated
pixel/seam layers; exact-tie/native verification; real-time review MP4; production
density rest rebake and records; shadow-cache refresh; actual production callback
capture and gate. All windowed invocations use `tools/visual_probe_runner.py` at
1920×1080 and 100% UI scale (density output crops are 255×255). Contracts live in
`tests/rr07/*_contract.json`. The existing rr-04 composer enforces front-left,
rear-right, 2× nearest, #1E1E24, top-centred clip title, idle/move ×3, other actions
×2, death once and a one-second final hold.

Expected **future** output paths per creature:

- `experiments/cutouts/<creature>/mq5/proof/native_rest/`
- `experiments/cutouts/<creature>/mq5/proof/native/` (frames and verification)
- `experiments/cutouts/<creature>/mq5/proof/<creature>_review.mp4`
- `experiments/cutouts/<creature>/mq5/proof/production_native/`

The director owns inspection-fixture preparation. A concrete fixture command is:

```sh
python3 tools/inspection_fixture.py --task-id rr-07 --run-id rr-07-inspection --scenario combat --enemy-types hoarfrost_seer,arc_thrall,arc_thrall --enemy-intents icefall,tether,tether --summary 'rr-07 rig inspection'
```

After both native rebakes, rerun Python discovery; the current density-rest
failure requires those four records. No windowed command was attempted or retried
by the worker. No peer review, signoff, commit, branch change or publication was run.

## TODO_DESIGN and chosen defaults

The feedback-1 source/hierarchy questions are all resolved in `rig_recipe.json`
and the case's recipes. Director feedback 3 resolves
`TODO_DESIGN_native_outer_uv_edge_policy`; its old failure record remains
historical evidence. There are no active design placeholders.

Only diagnostics/test values were chosen:

- `rr07_inputs.PROOF_DEFAULTS`: 255 px contact-sheet cells, six columns, 30 px
  labels, 8× nearest outline crops, 3 px crop margin, 0.02 raw-pixel joint check
  tolerance and 900 s full-suite timeout (existing project values where applicable).
- `rr07_build.REJECT_SAMPLE_STRIDE = 6`; adaptive worst-pose rejection only
  accelerates failed trials. Only all-frame acceptance can finish the search.
- `rr07_contract.ANGLE_EPSILON = 1e-12`; `precision.MIN_PIXEL_SCALE = 1e-6`
  preserves the existing semantic solver's zero-scale guard.
- Production probe: eight settle frames, 30 HP hit fixture, 1/60 s idle sampling;
  actors at (2,4)/(6,4), hero at (4,4), adjacent-hit target at (5,4). Existing
  en-03 fixture seed/grid and the existing 6 ms proof clock are reused.
- Python production timeout: 180 s. Travel-query fixtures are
  `RR07_TRAVEL_QUERY_DISTANCES = [96, 131.52, 192]`.
- Windowed proof budgets: 120 s rest/density, 900 s full native, 300 s production.
- Feedback-3 regression: `SYNTHETIC_SMALL_PART_SIZE = 2`, test-only; destination
  bounds derive from size + 1. No rendering or allowance value was chosen.

No balance, clip timing, body size, camera tuning, wording, palette or sound value
was invented. Framing bounds are derived source-texel geometry; density values
come from the existing rule and approved sources.
