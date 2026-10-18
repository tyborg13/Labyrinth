# mq-06 feedback 3 — native geometry passes; front gate stops delivery

Native work is stopped under feedback 3 decision 2. The corrected candidate passes the existing native geometry/collision checks and its native front capture, but **adds 95 front alpha pixels**. The v2 robe-union silhouette also changes **2.028622%**, beyond its 0.5% limit. No further Blender job was issued after measuring that failed front gate. The canonical measurements and every production delivery remain unchanged.

This is an implementation stop, not evidence that a smaller contact correction is impossible. The current fallback uses the existing convex regional contact surface to clear the far leg conservatively. That succeeds at collision clearance but is too invasive for the approved front gate. It must be refined before staging; the gate has not been relaxed or patched in the output PNGs.

## Acceptance status

| Requirement | Result |
| --- | --- |
| Original 1: root cause | Complete. The rear already turns exactly 180°; the paired fit raised the far ankle by 0.156967104 m. Original rear IoU 0.755072833. Original evidence remains in `../root_cause.json`. |
| Feedback 3.1: bridge deadline | Applied. Pickup deadline remains 120 s; each running job requested 900 s. No running job was stopped at 120 s. |
| Feedback 3.2: robe contact | One corrected native build passes all existing collision assertions: zero intersections, zero sub-margin samples. The required front gate fails, so this correction is not deliverable. |
| Feedback 3.3: pan only, 8 px | Implemented and headless-tested. Native preflight on the ray-only candidate rejects the projected bounds; no successful rear pan/pixel proof was obtained before the front gate stop. No scale or rotation was substituted. |
| Feedback 3.4: dynamic IoU ≥0.60, fixed registration recorded | The decision is stored in `decisions.json` and the derived recipe. Both measurement paths are written in `proof.py`; no corrected rear raster exists to measure. No after-IoU is claimed. |
| Front/rear staging, corrected rear sheet and coverage | Not completed. The failed front candidate is retained as a preview only. |
| Turn regression | Implemented over all complete committed deliveries. Other figures pass; the unchanged Seer rear delivery fails. |
| Python proof | Focused builder passes. Full discovery fails only the unchanged Seer rear regression; exact result lines are below. |
| Keep/budget | Original input values, original front fit, paintings and all figure deliveries remain byte-identical. Caches, generated specs, models and superseded previews were hashed before removal. |

## Exact observed native results

`attempt10.log`:

```text
RAY_CONTACT_PASS: {'pass': 27, 'constraints': 0, 'intersecting_face_pairs': 0}
BLENDER_MAQUETTE: PASS
BLENDER_BRIDGE_RESULT: exit=0; seconds=41.7
```

The final original-anatomy check, not merely the regional contact surface, reports:

```text
robe_skirt.minimum_signed_distance = 0.005954275373369455 m
robe_skirt.margin = 0.003 m
robe_skirt.samples_below_margin = 0
robe_skirt.intersecting_face_pairs = 0
```

Hood, scarf and robe torso also pass. The corrective native skin and anatomical facing checks pass. This is a passing single native geometry build, **not** a sealed delivery certification: repeated cold/cache proofs and final staging were not run after the front gate stopped work.

`front10.log`:

```text
BLENDER_FACING: PASS
FITTED_VIEW_CAPTURE: PASS; view=front
BLENDER_BRIDGE_RESULT: exit=0; seconds=53.4
```

`front_proof.log`:

```text
MQ06_FRONT_GATE: FAIL; whole alpha changes=95; robe union changes=2217
```

The native front capture preserves its geometry and passes native ownership/facing checks. The separate owner gate correctly rejects it.

## Floor heights — report the clearance displacement too

The reference plane is the near ankle at **0.026642927722 m**. The first floor correction places the far ankle and all 121 far-hem boundary points on that plane. Subsequent collision correction displaces some cloth points; those resulting heights are included in the guard instead of retaining stale pre-clearance heights.

| Point | Original Z, m | Floor correction Z, m | After contact clearance Z, m |
| --- | ---: | ---: | ---: |
| Far ankle | 0.183610032158 | 0.026642927722 | 0.026642927722 |
| Far hem minimum | 0.116210013628 | 0.026642927722 | -0.030114040888 |
| Far hem maximum | 0.313963472843 | 0.026642927722 | 0.042037103147 |
| Staff butt | -0.002259472098 | unchanged | unchanged |

The final upper hem lift is **0.015394175 m**, within the unchanged 0.02 m guard. The minimum is **0.056756969 m below** the reference plane. Therefore this candidate does **not** retain every hem vertex exactly on the plane after contact clearance; that displacement is disclosed rather than described as exact floor contact. No Seer exception was added.

The pure-ray candidate (`ray_only_build_report.json`, from attempt 3) clears collisions without changing projected vertex positions, but raises the hem maximum by **0.036935983 m**, failing the existing floor guard. Constraining those floor anchors exposed the remaining contact-solver issue. The later normal fallback uses the existing regional convex contact surface, followed by the unchanged complete-anatomy acceptance check. Its normal displacement reaches 0.161805 m and changes the front. This conservative fallback is not a proven minimum solution; its ray-infeasibility inference also needs refinement. No new visual result was accepted.

## Front gate, native 1024 proof

`front10_gate.json` records:

- Whole front alpha: **95 added pixels, 0 removed**; changed-pixel box **[386, 838, 401, 850]**.
- Robe (`skirt_near ∪ skirt_far`): **2217 / 109286 union pixels = 2.028622%**; displacement exceeds 2 px.
- Far foot: **2 / 3997 pixels = 0.0500375%**, within 1 px.
- Head, torso/collar, both arm unions, both hands, staff union and near foot: 0 changed pixels, 0 px displacement.
- Front joints: **0 px**.
- Clay, non-gating: **56,229** changed RGB pixels; maximum absolute channel difference **181/255**; mean absolute RGB-channel difference per changed pixel **9.683081684/255**, mean maximum-channel difference **10.014085258/255**.

`front_sheet.png` is **3072×1024**, with native cells: unchanged delivered front clay | corrected candidate clay | corrected candidate part map. It was visually inspected. It is a failed front proof, not the missing corrected rear sheet.

The retained preview PNGs preserve every clay RGBA byte and all mask alpha/visible RGBA bytes; only hidden mask RGB and PNG metadata were packed. `native_capture_manifest.json` retains raw native byte hashes, and `capture_manifest.json` binds the packed preview. The front gate was reproduced after packing. Its manifest mode is `preview`; it cannot be staged as a complete delivery.

## Rear pan preflight

A diagnostic attempt used the completed ray-only candidate, with the exact rear 180° root turn and unchanged camera direction/scale. Before producing any rear image, `capture_frame.minimum_pan` rejected projected mesh bounds:

```text
[[235.63301255741675, 97.35907896096893],
 [839.0796490532354, 1117.082874759138]]
```

The projected height is **1019.723796 px**. The permitted inclusive pixel coordinates are 8 through 1015 (1008 pixel positions). A translation cannot fit these continuous mesh bounds into that region. This is a **mesh-bound preflight failure**, not an uncropped native-alpha measurement. An actual unclipped pixel-bound proof was not run because the later front gate requires a stop. See `rear_diagnostic.log`: director exit 2, 2.2 s. No scale change or clipped rear has been presented as compliant.

## Guard findings and protected files

`floor_guard.json` separately audits unchanged committed figures and the corrected candidate. Thrall far ankle **+0.070364564 m** is deferred to mq-07; Herald far ankle **+0.048713929 m** is deferred to its v2 unit; Lancer spear butt **+0.269636631 m** is deferred to its v2 unit and may be intentional. Gloam's **+0.005412659 m** is within the limit. Documented exceptions remain in `../feedback2/floor_guard_exceptions.json`; Seer's list is empty. The unchanged committed Seer correctly fails at +0.156967104 m, while the candidate passes the numerical upper-height guard.

`protected_check.json` checks 533 original files. Only the four authorized existing builder files differ: `build.py`, `compile_recipe.py`, `render.py`, `curate_delivery.py`. No figure delivery or approved painting changed. The derived recipe adds only `floor_contact_correction` and `rear_capture`; all original recipe field values remain unchanged.

## Files and proof commands

Existing builder edits are small and opt-in: compile the authorized correction, run it after native solve, pan rear captures when requested, and optionally pack PNGs with a fresh delivery seal. Focused new helpers are `floor_contact.py`, `floor_contact_native.py`, `front_gate.py`, `ray_contacts.py`, `ray_search.py`, and `capture_frame.py`. One new regression file, `tests/test_maquette_rear_turn.py`, covers delivered foot/depth order, floor math, bone-name binding, exception validation, v2 unions, ray-search minima, pan invariants, and visible-pixel preservation during staging. `proof.py` writes the future full-capture assembly/fit/coverage/sheet path but was not executed: the required rear capture does not exist.

Reproduce the stopped portable proofs:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-06
python3 -B spec/art_identity/maquettes/hoarfrost_seer/rear_turn/feedback3/front_proof.py
python3 -B spec/art_identity/maquettes/hoarfrost_seer/rear_turn/feedback3/scan_floor_contacts.py
python3 -B -m unittest discover -s tests -p 'test_maquette_rear_turn.py' -v
```

The first and third commands correctly return nonzero for the held failed candidate / unchanged delivery. The guard also returns nonzero for the unchanged committed Seer. Native models and generated specs were removed after hash archival; regeneration begins with the compile command below.

Exact native command forms used for the current build/capture (absolute data paths are required because the bridge's working directory is external):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-06
MQ06_PROOF=/Users/borgerding/workspace/Labyrinth.worktrees/mq-06/spec/art_identity/maquettes/hoarfrost_seer/rear_turn/feedback3
python3 -B -m spec.art_identity.maquettes.blender.compile_recipe "$MQ06_PROOF/correction_recipe.json"
python3 -B spec/art_identity/maquettes/blender/bridge_client.py --timeout 900 spec/art_identity/maquettes/blender/build.py -- "$MQ06_PROOF/spec_native.json" "$MQ06_PROOF/attempt10" --build-only
python3 -B spec/art_identity/maquettes/blender/bridge_client.py --timeout 900 spec/art_identity/maquettes/blender/capture_view.py -- "$MQ06_PROOF/spec_native.json" "$MQ06_PROOF/attempt10/maquette.blend" "$MQ06_PROOF/front10" front
```

These native commands are recorded for the design owner, not retried after the front stop. No local Blender process was launched. No `.gd` file changed. A separate Godot suite, windowed visual probe and `inspection_fixture.py` are not applicable to this maquette unit; standard Python engine-fixture children remain in the full discovery log.

## Tests and chosen defaults

- Focused builder: `Ran 43 tests in 2.420s` / `OK`.
- New regression/helpers: `Ran 9 tests in 5.186s` / `FAILED (failures=1)`. The sole failure is the unchanged Seer rear foot placement; eight helper tests pass.
- Art identity: `Ran 111 tests in 36.579s` / `OK` (`art_identity.log`).
- Full Python: `Ran 848 tests in 775.486s` / `FAILED (failures=1, skipped=63)` (`python_full.log`). The sole failure is the new regression against the unchanged Seer rear delivery. Every other executed test passed; all skip reasons remain in the verbose log. This is not a full-suite PASS.

No new player-facing value was chosen. The 120/900-second deadlines, 0.003 m margin, 8 px rear margin, 0.60 rear IoU gate and front limits come from the owner. Numerical/proof-only fields are named in code: ray search 1024 steps, 32 bisections, 1e-8 m numerical epsilon, 1e-6 m minimum step; contact solver 128 passes and 24 ray-only passes; floor interpolation 20,000 iterations / 1e-10 epsilon; skinning proof tolerance 1e-4 m; alpha threshold 128 and colour tolerance 1 inherited from existing coverage; native proof cells 1024 px; pixel-pan correction bound 4 passes. Synthetic mask, floor/ray and pan fixtures are explicit in the regression file. The regional contact hull uses existing project behavior and adds no new clearance amount.

All original design TODOs have decisions. Those historical front and rear implementation holds are superseded by feedback 4; the front gate was removed and the new native rear passes collision and framing. The pure-ray candidate's boot-draped hem classification question remains pending; the strict existing guard was retained. Missing acceptance: a smaller faithful contact fallback with 0 front alpha changes and passing v2 unions, certified cold/cache proofs, native rear/pixel-margin proof, both after-IoUs, rear coverage and required sheets, staging, a passing Seer turn regression and full Python suite. No peer review, commit, Git staging, branch change, queue mutation or publication was performed.
