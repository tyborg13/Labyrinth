# mq-06 feedback 4 — planted rear proof, staging held

**Historical — superseded by feedback 5.** The director accepted this exact
sheet and decided the fixed original registration is the gate. The accepted
rear is now in `../../delivery/`, with its separate native certificate in
`../../delivery/rear_native/`. Duplicate capture PNGs and staging intermediates
were hashed before removal. The front is frozen. See `../feedback5/README.md`
for current gates, verification, commands and staged hashes; do not rerun this
historical proof script against the replaced delivery.

The rear native build is valid. Its required **dynamic IoU is 0.2054038784**, so
the **0.60 fit gate fails**. No delivery is staged. The supplied painting,
annotations, original measurements, all front output and every other figure's
delivery remain unchanged. Changes remain uncommitted.

Inspect [rear_sheet.png](rear_sheet.png), four native 1024 cells in the requested
order: old rear clay | planted rear clay | planted rear parts | approved rear
painting (nearest-neighbour enlargement for inspection). This is proof imagery,
not replacement art. [rear_registration_comparison.png](rear_registration_comparison.png)
shows the actual standard registration failure.

## Numbered acceptance

1. **Front frozen: met.** All 21 `front_*` delivery files are byte-identical;
   `joints_px.json.front` is identical. No front render or staging command ran.
   The alpha/union gate is no longer part of the active proof, and its old TODO
   was retired. See `front_freeze.json`, `proof.log`, `protected_check.json`.

2. **Planted rear body: met.** Build from the fitted CC0 skin, retaining only
   `CC0_original` and `source_outline_fit`. Before solving the skirt, pose the
   registered `hip_far`, `knee_far`, `ankle_far` bones to the new joint targets.
   The ankle XY is exactly the previous front-ray correction's ground target;
   Z matches the near ankle. Maximum actual bone endpoint error is
   **0.000003256284 m**. No inverse-skin floor corrective or free body-vertex warp
   is used by this path. The original upper garments solve before the leg moves;
   every garment is then rechecked against the final planted anatomy.

   The skirt starts with a harmonic waist-to-hem correction, solves its original
   **64 native Cloth frames** against the planted body and a hidden floor
   collider, then uses the existing contact projection and floor constraints.
   Existing stiffness, contact margins, self-collision, stability and pin gates
   are unchanged. The physical **0.003 m collision margin** and **0.006 m cloth
   thickness** determine hem clearance. All rendered hem shell vertices are
   **0.005418820–0.006581178 m above the floor**, with **zero intersections** and
   **zero samples below margin**. Minimum skirt/body distance is
   **0.005341358948 m**. See `native_build_report.json` and `floor_guard.json`.

3. **Rear capture: met for the candidate.** Exact 180° root turn, unchanged
   direction and **2.4 m** orthographic scale. Unclipped geometry height is
   **942.640911402 px ≤ 1008 px**. Pan is **(0, -24.999990363) px**. Actual clay
   pixel margins are **left 227, top 72, right 184, bottom 8 px**; every rear PNG
   also passes the 8 px margin. Root canvas positions are front **(512, 925.84)**,
   rear candidate **(512, 900.84)**. Rear clay, part map, silhouette, all 15 solos
   and rear joints are retained under `rear/`. Front files are not copied there.

4. **Gates: mixed, staging held.** Candidate turn, floor, native collision,
   coverage, exact native determinism and framing pass. Dynamic fit fails, and
   the full suite retains the expected old-production Seer regression failure.
   The candidate has not replaced that delivery merely to make tests green.
   Curation records all discarded evidence hashes and must remain within the
   6 MB figure budget; exact final result lines are below.

## Height table (metres)

Floor reference is the near ankle, **0.026642927722 m**. Before hem values are
the original far-hem midsurface; after values include both rendered shell sides.
The complete near/far hem audit is stronger than an ankle-only guard.

| Contact | Before Z | After Z |
|---|---:|---:|
| Far ankle target | 0.183610032158 | 0.026642927722 |
| Far hem minimum | 0.116210013628 | 0.032168436795 |
| Far hem maximum | 0.313963472843 | 0.033117417246 |
| Staff butt | -0.002259472098 | -0.002259472098 |

The staff butt was not lifted, so it remains unchanged. Actual far ankle bone
head is 0.026642935351 m. `height_table.json` and `rear_extent.json` retain the
full measurements. No Seer exception is present.

Other fitted figures are audited without modifying them. Documented exceptions
remain in `../feedback2/floor_guard_exceptions.json`:

| Figure / point | Lift above reference | Disposition |
|---|---:|---|
| Thrall far ankle | 0.070364564 m | mq-07 |
| Herald far ankle | 0.048713929 m | Herald v2 |
| Lancer spear butt | 0.269636631 m | Lancer v2; may be intentional |

Gloam's +0.005412659 m passes without an exception. The frozen old Seer front fit
still has its original lifted ankle; the new rear audit uses the separate rear
recipe and actual native hem. Both states are explicitly retained in the audit.

## Fit and coverage

| Rear comparison | IoU |
|---|---:|
| Original delivery, original dynamic registration | 0.755072833141 |
| Planted candidate, required dynamic registration | **0.205403878388 — FAIL** |
| Planted candidate, fixed-original registration, accounting for pan | 0.760907618508 |

The protected source frame is head 51, sole 246, ground X **81.021739130**.
The new dynamic frame is head 176, sole 1015, ground X **609.820474777**.
The source ground band falls on the lower left robe edge; the planted maquette's
falls on the lower right foot. The fixed-original maquette ground X would be
341.041666667, a difference of 268.778808111 px. Panning cannot repair this:
dynamic registration removes that translation. Neither the approved source
annotation nor the required gate was changed.

`rear_coverage.csv` reports genuine part-colour pixels, not nearest-colour
ownership alone. Fourteen labels have genuine pixels. `foot_near` has a complete
3084-pixel solo but zero visible genuine pixels; its depth occlusion is recorded
(chiefly `skirt_far`, 2974 pixels). There are no unexplained empty labels.

`turn_audit.json` reports every complete committed delivery, including the
Lancer's matching r2 archive (r3 supplies clays without complete solos), and the
new candidate separately. The Seer candidate's rear foot centroids are near
**(336.8794, 934.2506)** and far **(598.7137, 984.8565)**: the lower foot is right.
Front remains near **(688.8261, 950.7903)**, far **(423.7325, 863.3228)**. Genuine
side pixels over torso change from front near/far **1107/341** to rear
**4170/4580**. Rear forward screen vector **(+0.7062434, -0.3536137)** is upper-right.

## Files and integration

Current small opt-in changes are in `blender/build.py` (fit then pose before
skirt, final anatomy checks), `compile_recipe.py` (separate rear recipe),
`cloth.py` and `drape_collision.py` (floor support/settlement), `render.py`
(pan hook), and `curate_delivery.py` (optional lossless packing, from earlier
feedback). New current helpers are `rear_body.py`, `floor_contact.py` and
`capture_frame.py`. Earlier front-preserving helpers remain opt-in historical
code; the new rear path does not invoke them. One new test file,
`tests/test_maquette_rear_turn.py`, owns turn, native candidate, front freeze,
floor, exception, pan and packing regressions.

Figure-owned files are the rear recipe, native rear captures/joints, proof
scripts/reports/sheet, status, curation manifest and discarded-evidence hashes.
No `.gd`, production delivery, other figure, supplied measurements or approved
painting changed. All 533 original protected files are audited; only six
authorized existing shared builder files differ.

Native PNG byte hashes are retained in `rear/native_capture_manifest.json` and
the discarded hash archive. Packed clay RGBA is identical; masks preserve every
alpha and every visible RGBA sample. `rear/capture_manifest.json` binds the
packed proof bytes. `rear/packing.json` explicitly says this is an **unapproved,
unstaged proof**. Generated native models/specs/caches and superseded previews
were hashed before removal. No seal claims these captures are a staged delivery.

## Tests and observed result lines

See `verification.txt` for the final collected result lines and log paths.
Native observations:

```text
BLENDER_MAQUETTE: PASS
BLENDER_BRIDGE_RESULT: exit=0; seconds=34.6
MQ06_REAR_EXTENT: PASS; height_px=942.6409114024216; limit_px=1008
FITTED_VIEW_CAPTURE: PASS; view=rear
BLENDER_BRIDGE_RESULT: exit=0; seconds=75.5
FITTED_RECIPE_PROOF: PASS; raw_hashes_identical=true; max_joint_error=3.501882977994828e-06
EXACT_NATIVE_REPLAY: PASS; unrounded_float32=true; mesh_count=14
MQ06_FRONT_FREEZE: PASS; files=21; joints unchanged=True
MQ06_CANDIDATE_TURN: PASS
MQ06_FLOOR_GUARD: PASS; Seer exceptions=[]
MQ06_PROTECTED_BYTES: PASS; checked=533
MQ06_PROOF: FAIL
```

Focused builder checks: `Ran 82 tests in 3.041s`, `OK (skipped=2)`.
Turn/helper checks: `Ran 11 tests in 5.723s`, `FAILED (failures=1)`; the planted
candidate test passes. Only the unchanged old Seer production rear fails.
Art identity: `Ran 111 tests in 44.978s`, `OK`.
Full discovery: `Ran 849 tests in 723.780s`,
`FAILED (failures=1, skipped=63)`. Its sole failure is the unchanged production
Seer rear. The new native-candidate test was added while discovery was running
and was then included in the final 11-test focused run above; it passes.

## Proof for the design owner

These native jobs were executed through the bridge; the removed models can be
reconstructed with these exact worktree-relative commands. Pickup must occur
within 120 s; running budget is 900 s. No windowed command applies to this
Blender maquette unit. No Godot, renderer/window retry or inspection-fixture
command is required because no runtime or `.gd` file changed.

```sh
MQ06_PROOF="$PWD/spec/art_identity/maquettes/hoarfrost_seer/rear_turn/feedback4"
python3 -B spec/art_identity/maquettes/blender/compile_recipe.py "$MQ06_PROOF/rear_recipe.json"
python3 -B spec/art_identity/maquettes/blender/bridge_client.py --timeout 900 spec/art_identity/maquettes/blender/build.py -- "$MQ06_PROOF/spec_native.json" "$MQ06_PROOF/build2" --build-only
python3 -B spec/art_identity/maquettes/blender/bridge_client.py --timeout 900 spec/art_identity/maquettes/hoarfrost_seer/rear_turn/feedback4/rear_extent.py -- "$MQ06_PROOF/spec_native.json" "$MQ06_PROOF/build2" "$MQ06_PROOF/rear_extent.json"
python3 -B spec/art_identity/maquettes/blender/bridge_client.py --timeout 900 spec/art_identity/maquettes/blender/capture_view.py -- "$MQ06_PROOF/spec_native.json" "$MQ06_PROOF/build2/maquette.blend" "$MQ06_PROOF/rear" rear
python3 -B spec/art_identity/maquettes/blender/bridge_client.py --timeout 900 spec/art_identity/maquettes/blender/recipe_proof.py -- "$MQ06_PROOF/spec_native.json" "$MQ06_PROOF/determinism"
python3 -B spec/art_identity/maquettes/blender/bridge_client.py --timeout 900 spec/art_identity/maquettes/blender/exact_native_replay.py -- "$MQ06_PROOF/determinism" "$MQ06_PROOF/exact_native_replay.json"
python3 -B "$MQ06_PROOF/proof.py"
python3 -B "$MQ06_PROOF/audit.py"
```

Headless verification:

```sh
python3 tools/output_gdignore.py
python3 -B -m unittest tests.test_maquette_blender spec.art_identity.maquettes.blender.test_source_recipe spec.art_identity.maquettes.blender.test_drape spec.art_identity.maquettes.blender.test_delivery_validation spec.art_identity.maquettes.blender.test_round3 -v
python3 -B -m unittest tests.test_maquette_rear_turn -v
python3 -B tests/test_art_identity_gate.py
python3 -B -m unittest discover -s tests -p 'test_*.py' -v
python3 -B -m spec.art_identity.maquettes.blender.curate_delivery verify spec/art_identity/maquettes/hoarfrost_seer
git diff --check
```

## Chosen defaults

No player-facing value was chosen. Bone proof tolerance is a named **1e-4 m**
field, matching existing recipe proof. Harmonic interpolation retains the
named **20,000 iteration / 1e-10** numerical limit. Floor contact projection uses
the existing **24 passes**, with early termination at the existing collision
epsilon. The hidden floor collider's half extent equals `ortho_scale`; it is
never rendered. Pan pixel refinement is bounded by the named **4 passes**.
Coverage uses existing **alpha 128 / channel tolerance 1**. Test fixtures are
plain named fields. Earlier ray-search/front-gate numerical defaults are
historical and unused by this rear build. All physical, camera, render sampling,
fit-gate, framing and budget values come from owner data or existing approved
builder fields.

## TODO and open issue

the historical registration conflict, resolved by feedback 5 in `status.json` records the
failed dynamic fit. A design-owner decision is needed before staging; no
replacement registration or pose adjustment was invented. Consequently the old
production Seer test remains red, and a full Python PASS cannot be claimed.
There is no remaining front-alpha, collision, floor, frame or native replay TODO.
No peer review, sign-off request, commit, Git staging, branch change, publication
or queue mutation was performed.
