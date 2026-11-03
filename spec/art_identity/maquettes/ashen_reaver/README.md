# mq-16 — Ashen Reaver, approved geometry and feedback-3 proof guards

Native maquette delivery for director painting and the later rig-v2 unit.
`director_pose.json` preserves the exact feedback-1 values and
`director_feedback2.json` supplies the blade and shoulder-shell overrides.
`feedback1_preservation.json` locks the other 41 native meshes, camera,
joints and 36 solo/control images. `recipe.py` builds
`measurements.json`, a native v2 specification on the approved CC0 realistic
male humanoid armature. Source art, old cutout files, production behavior and
other figures remain unchanged. No image generation, new font or dependency.
All worker changes remain uncommitted; the design owner handles peer review,
inspection and publication.

## Feedback 3: proof and guards

The approved geometry, pose, PNGs, joints and contact sheet are unchanged.
`feedback3_preservation.json` records their byte hashes and the approved
compiled spec digest, `fa7df679eb9c8c19978d44932adc8082d79b83b937702b1108071ee3c167f5c5`.
The unused disc-layer dimensions, former blade contours/roll and old recipe
blade-sampling controls have been removed from active settings. The immutable
`source_caliper_record.json` retains the original measurement metadata so the
compiled spec remains identical; none of its obsolete fields drives geometry.

Clean copying and verification share `source_inventory.py`. Its required
inventory includes the current figure code/data, shared builder, maquette
modules and protected source assets. Verification compares the complete key
set and every SHA-256 with current source bytes, in addition to the existing
receipt hash checks. Empty package init files represent the checkout's
namespace packages in the clean project. A renderer clay-colour change now
fails the actual `proof verify` command.

`tests/test_mq16_proof_guards.py` executes the actual `render.py` dispatch with
a synthetic Blender boundary, without starting an engine. It checks explicit
preview passes, solos-only batches and the historical default. Temporary
inventory fixtures cover a listed oversized file, prohibited files and the
exact inclusive 6,000,000-byte boundary. Removing the size guard or restoring
unconditional parts/clay/silhouette passes is caught by those tests. All test
mutations and fixture writes stay in per-test temporary directories.

## Numbered requirements

1. **Native geometry and pose.** Forty-nine rounded native render meshes use
   the twenty exact labels, level shoulders and the board's +X facing
   (45° azimuth, 30° elevation). The current 255² art measures **230px drawn
   height**; the 1024² front clay measures **920px**, exactly 4×. Rear height
   is **902px** at the same scale. The helm, layered pauldrons, cowl/scarf,
   cross straps, round strap buckle, broad belt and square buckle, ragged
   tabard, round knees, heavy boots and curved ember-edged falchion have native
   geometry. Cowl/scarf faces belong to `torso`; tabard pivots on `pelvis`.
   The three shoulder lames are closed shells: a dome over the joint and two
   rounded bands following the upper-arm cylinder. Their overlaps are exactly
   one third; the stack ends 0.07H below the joint, with no horizontal disc
   faces. Blade, guard, grip and pommel form one rigid `falchion`; its edge surface
   shares the `hand_far` bone and grip pivot. The near hand remains free.
2. **Gates.** Native shoulder Z difference is **0m**. Front rise is
   **44.340px**, expected **44.3385px**, error **0.0015px**, against ±10px.
   Rear is the exact `diag(-1,-1,1)` rotation; both determinants are **+1**.
   Both native sole minima are **Z=0m**. Far-hand X relative to torso is
   **−176.94px front / +176.94px rear**. All **20/20 labels** have nonempty
   unoccluded solos and visible pure-owner pixels in **both** views; zero
   solos clip the canvas. The visor and round strap buckle are front-only;
   the glowing edge is visible in both views. See
   [acceptance](delivery/mq16_acceptance.json),
   [native observations](delivery/native_probe.json),
   [coverage](delivery/per_part_coverage.csv) and
   [proportions](delivery/proportion_table.md). Proportions are report-only;
   there is no fit/IoU gate against the old pose. The source head-part mask's
   58px height includes its neck attachment; the separate helmet caliper is
   49px. Body-space helmet height is approximately 0.21875H.
3. **Curated delivery.** `delivery/` contains both 1024² clays/maps, forty
   solos, two isolated blade-area masks, joints, native manifests, reports and the
   [contact sheet](delivery/contact_sheet.webp). That sheet places the current
   art at exact 4× NEAREST beside native front/rear clays and the mq-15 Gaoler
   clay at 1:1. Native clay PNG bytes are retained. Mask packing preserves
   every alpha value and every visible RGBA value. The native PNG inventory
   packs from **13,922,400 to 2,631,735 bytes**. The complete figure is checked
   under **6,000,000 bytes** by `proof verify`; `COMMIT_MANIFEST.txt` inventories
   all retained files. Models, caches, candidates, duplicate captures and clean
   build trees are SHA-256 inventoried before removal in
   `discarded_proof_sha256.json`.
4. **Replay, mutation and hash binding.** Cold, shared-cache-path replay and
   independent cold builds agree across all **49 meshes**. Unrounded float32
   geometry and joint matrices agree exactly. Maximum observed joint endpoint
   error is **1.4502473e-6m**. The fixed cloth shapes need no dynamic drape
   simulation. The native probe recomputes opened-world mesh hashes, actual
   rig endpoints, knee/elbow/lean angles, stance, step, fist position, blade
   axis, full length, profile, vertical plane, grip, pommel, tip clearance,
   shoulder-shell overlap/wrapping and cowl coverage. A
   material-ownership mutation and a stale-report helm mutation are rejected;
   the original geometry is restored. All four shared ownership/cache code
   mutants are caught. Fresh regeneration recompiles from copied authoring,
   protected source pixels/metadata and copied builder code, with an explicit
   clean-module path guard. No generated native spec, model or cache is copied.
   Both clays, both part maps and both isolated blade-area masks match exactly
   after canonical PNG normalization;
   the fresh native geometry matches the cold proof. Release receipt hashes,
   contact sheet and fresh proof are chained through the acceptance report
   into the shared cold-proof binding. Verification recomputes those checks.

## Observed director pose

Lengths use L, the hip-joint height above the sole plane. L=1m is only the
native coordinate gauge; H runs from the sole plane to the top of the helm.
Body forward is +X, near/outward is +Y, up is +Z.

| Observation | Native result |
|---|---:|
| Knee bend near / far | 10.000003° / 9.999995° |
| Near elbow | 12.000013° |
| Spine lean from pelvic root | 4.999999° |
| Ankle Y span / shoulder-joint Y span | 1.250000033 |
| Near-ankle advance / L | 0.220000026 |
| Far fist offset from far hip / L | (+0.199999969, −0.100000092, +0.000000119) |
| Blade axis down / outward | 44.999998° / 19.999997° |
| Tip clearance / H (report only) | 0.150445548 |
| Pommel terminal surface to tip / H | 0.480000043 |
| Guard width / maximum width / H | 0.040000003 / 0.070000019 |
| Maximum width along guard-to-tip axis | 0.666666646 |
| Clipped-back axial length / H | 0.080000028 |
| Isolated blade pixels front / rear | 13051 / 13152 |
| Renderer rear/front blade area | 1.007738871 (target 0.8–1.25) |
| Native outline rear/front blade area | 0.999999980 |

The cutting edge is convex; the spine is straight before its last 0.08H
clipped section. The blade plane contains the body-space vertical direction;
its opened-native face normal has Z=1.735e-7. The isolated area masks exclude
the guard, grip, pommel and glow. No clearance constraint changes its geometry.

The front/rear proof cameras retain the accepted feedback-1 targets,
scale and board angles exactly.
Object matrices remain the exact identity/half-turn pair; there is no
per-view pose, mirrored mesh, old-art fit or per-part registration.

## Builder scope and files

The unit's source, data and delivery files are listed in
`COMMIT_MANIFEST.txt`. Outside this folder, the only changes are the generic
opt-in pass planner `../blender/render_plan.py`, its small `render.py` adapter,
`tests/test_mq16_maquette.py`, `tests/test_mq16_proof_guards.py`, the portable
`tests/mq16_render_fixture.py` helper, and the tests' temporary-only resource
entries in `tools/python_suite_resources.json`. Bounded jobs capture clay, labels and
isolated blade-area masks and four solos separately. Historical render calls retain their pass order.
[Preservation](preservation.json) verifies **16 other compiled inputs** and
zero foreign tracked figure changes. Only this unit opts into the new pass
selection, and it has the full fresh native regeneration.

## Tests observed

- Focused maquette/delivery checks, including the final unit/receipt regressions:
  `Ran 103 tests in 23.836s` / `OK (skipped=2)`; two opt-in native cases skipped.
  Separate Ashen Reaver bridge proof passed.
- Art identity: `Ran 111 tests in 76.130s` / `OK`.
- Portable mutations: `MQ03_MUTATIONS: PASS; caught=4; survived=0`.
- Python resource audit: `ISOLATION AUDIT: 229 modules`.
- Feedback-3 guard mutants: unconditional renderer passes caught with seven
  assertion failures; removing the inventory size guard caught with one.
  The renderer-colour mutation is rejected by the actual `proof verify`
  subprocess regression. The full required inventory matches 210 current files.
- Native: `MQ16_NATIVE_PROOF: PASS`.
- Clean rebuild: `MQ16_CLEAN_REGENERATION: PASS; clays=2/2; part_maps=2/2; blade_area_masks=2/2; cache_reused=false`.

The unchanged art-identity tests emit NumPy matmul RuntimeWarnings and a
Pillow mode deprecation warning; no assertions fail. Full Python/Godot suites,
peer review, commits and publication were not part of this worker handoff.
Exact commands/results and retained bridge receipts are in
`verification_results.json` and `delivery/validation/`.

## Proof for the design owner

Verify the curated delivery and focused checks:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-16 && python3 -B -m spec.art_identity.maquettes.ashen_reaver.proof verify
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-16 && python3 -B -m unittest tests.test_mq16_maquette -q
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-16 && python3 -B -m unittest tests.test_mq16_proof_guards -q
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-16 && python3 -B tests/test_art_identity_gate.py
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-16 && python3 -B tools/run_python_suite.py --shards 4 --audit-only --output-dir /private/tmp/labyrinth_codex/mq-16/owner-python-audit
```

To repeat native proof, use fresh empty destinations and run these in order:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-16 && python3 -B -m spec.art_identity.maquettes.ashen_reaver.recipe
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-16 && python3 -B -m spec.art_identity.maquettes.ashen_reaver.proof prove --out spec/art_identity/maquettes/ashen_reaver/proof/owner_native
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-16 && python3 -B -m spec.art_identity.maquettes.ashen_reaver.proof stage --capture spec/art_identity/maquettes/ashen_reaver/proof/owner_native/capture
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-16 && python3 -B -m spec.art_identity.maquettes.ashen_reaver.proof regenerate --out spec/art_identity/maquettes/ashen_reaver/proof/owner_fresh
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-16 && python3 -B -m spec.art_identity.maquettes.ashen_reaver.proof curate
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-16 && python3 -B -m spec.art_identity.maquettes.ashen_reaver.proof verify
```

Every Blender operation uses the director's bridge with a 110s execution
budget and a strict 120s response deadline including queue time. An unanswered
job stops the workflow. This is offline authoring with native 1024² proof;
windowed Godot/1920×1080 probes and `tools/inspection_fixture.py` do not apply.

## TODO_DESIGN, chosen defaults and open observations

No `TODO_DESIGN` field remains. All seven pose questions are resolved by the
protected `director_pose.json`, with feedback-2 overrides in
`director_feedback2.json`. Source calipers and palette samples come from
the approved existing art; they are retained in the native input.

[Chosen defaults](chosen_defaults.json) contains only technical settings:
L=1m coordinate gauge, topology/resampling precision, inherited renderer
settings, analytic proof centring, alpha/colour tolerances, native numerical
bounds, bounded capture sizes/deadlines, synthetic mutations and review-sheet
layout. Synthetic test values stay in named test fixture fields.

The blade's rear/front isolated renderer area ratio is 1.007738871, within the
director's bounds. The shared studio lights shade the two faces differently;
the masks and native outline independently establish their projected area.
No per-view weapon correction or lighting change was applied.
