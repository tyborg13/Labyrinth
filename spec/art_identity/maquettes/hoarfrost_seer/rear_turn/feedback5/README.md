# mq-06 — accepted rear staged, front frozen

**Integration hold:** the last full suite ran 851 tests and has one error: the existing rr-07 input reader assumes one pose/camera for both views. A minimal generic reader patch is prepared in `rr07_reader.patch`; its proposal probe passes both figures without changing the 0.02 px assertion. That reader is outside the original Owned list, so it remains unchanged pending the requested scope decision. Native staging and all other gates pass.

Feedback 5 accepts the exact planted rear reviewed in
[`../feedback4/rear_sheet.png`](../feedback4/rear_sheet.png). The staged rear
uses the **fixed original mq-04 registration**, IoU **0.7609076185083125 ≥ 0.60**.
Dynamic ground-centroid IoU **0.20540387838762533** is retained as a diagnostic.
The director's reason is recorded in `fit_policy.json` and the staged
[`rear_proportion_report.json`](../../delivery/rear_proportion_report.json):
the painting's lower-left robe edge and the planted body's lower-right foot
are different ground anchors. The method for other figures is unchanged.

## Numbered acceptance

1. **Rear staged; front frozen.** `delivery/` contains the accepted rear clay,
   parts, silhouette, all **15 solos**, and the new rear `joints_px.json` entries.
   These **18 PNGs** were copied byte-for-byte from the reviewed feedback 4
   captures. All **21 `front_*` files** remain byte-identical, including the
   front fit report; front joint displacement is **0 px**. Approved paintings
   and supplied `measurements.json` values are unchanged. No front render ran.

2. **Committed-delivery turn regression passes.** The test reads the actual
   `delivery/` files. All five complete figure deliveries/archives pass. The
   Seer rear's lower foot is right: far **(598.7137, 984.8565)** versus near
   **(336.8794, 934.2506)**. Front remains near **(688.8261, 950.7903)** versus
   far **(423.7325, 863.3228)**. Genuine side-colour pixels over torso change
   from front near/far **1107/341** to rear **4170/4580**. Labels retain their
   anatomical body sides. Rear forward vector **(+0.7062434, −0.3536137)** is
   upper-right. Lancer uses the complete matching r2 map/solo archive because
   its r3 reference is clay-only. New complete deliveries are discovered too.

3. **Floor, native collision, coverage, replay and curation.** The actual
   far hip/knee/ankle bones position the foot, retaining the original native
   source-outline corrective. No arbitrary body-vertex floor warp is used.
   Skirt simulation retains the approved 64-frame solver, original physical
   settings and the existing **0.003 m** collision assertion. The current
   skirt minimum distance is **0.005341358948 m**, with **zero intersections**
   and **zero samples below margin**. All hem shell points are
   **0.005418820–0.006581178 m above** the near-ankle floor plane; the 0.02 m
   floor guard passes with **no Seer exceptions**.

   Fourteen labels have genuine part-colour pixels. `foot_near` has a complete
   3084-pixel solo and recorded depth occlusion, chiefly by `skirt_far` (2974
   pixels). No label is unexplained. The validator recomputes fixed fit,
   genuine colour coverage and all rear pixel margins from staged PNGs.

   Native cold/cache/independent-cold hashes match exactly for **14 meshes**;
   maximum joint endpoint error is **0.000003501883 m**. Exact float32 native
   mesh and joint replay passes. No native rebuild or render was needed for
   feedback 5: the accepted captures and raw native proofs are preserved.

   The camera retains its direction and **2.4 m** orthographic scale. Height
   is **942.640911402 px ≤ 1008 px**. Pan is **(0, −24.999990363) px**. Clay
   margins left/top/right/bottom are **227/72/184/8 px**, and every staged
   rear PNG has at least 8 px margin. Root canvas positions are front
   **(512, 925.84)** and rear **(512, 900.84)**.

   `curation.log` reports final size and the **6,000,000-byte** limit. All
   replaced rear files, stale combined overlays/regeneration reports, duplicate
   capture copies, native models/specs/caches and staging intermediates were
   hashed before removal. No `.blend` is retained. `COMMIT_MANIFEST.txt` lists
   the complete figure tree.

4. **Full Python suite.** Focused checks and the full suite are recorded in
   `verification.txt` and `full_python.log`; exact final result lines are the
   completion evidence. No existing assertion was weakened or quarantined.

5. **Final file list and hashes.** [`final_file_list.txt`](final_file_list.txt)
   lists changed/new/deleted files relative to the worktree. The figure's
   complete retained inventory is `../../COMMIT_MANIFEST.txt`.
   [`staged_rear_sha256.txt`](staged_rear_sha256.txt) lists **34 staged rear and
   supporting certificate/joint/frame file hashes**;
   [`staged_rear_sha256.json`](staged_rear_sha256.json) also records a canonical
   hash of only the rear joint entries. `audit.py` regenerates both inventories
   of rear hashes from disk.

## Height and fit tables

Floor plane: **0.026642927722 m**. Original hem values are midsurface; current
hem values include both rendered shell sides. Full measurements remain in
[`../feedback4/height_table.json`](../feedback4/height_table.json).

| Contact | Before Z, m | Staged Z, m |
|---|---:|---:|
| Far ankle target | 0.183610032158 | 0.026642927722 |
| Far hem minimum | 0.116210013628 | 0.032168436795 |
| Far hem maximum | 0.313963472843 | 0.033117417246 |
| Staff butt | −0.002259472098 | −0.002259472098 |

The staff butt was not lifted and stays unchanged. The actual far ankle bone
head is 0.026642935351 m. Front bytes remain frozen despite the separate rear
body's pose and skirt settlement.

| Rear registration | IoU | Role |
|---|---:|---|
| Original mq-04 rear, original dynamic frame | 0.755072833141 | Before |
| Corrected rear, dynamic ground-centroid | 0.205403878388 | Diagnostic only |
| Corrected rear, fixed original offset plus capture pan | **0.760907618508** | **PASS ≥ 0.60** |

`fit_policy.json` scopes the owner decision to `hoarfrost_seer` / `rear`.
The original reference frames are unchanged: source head 51 / sole 246 /
ground X 81.021739130; native head 201 / sole 984 / ground X 341.041666667.
Only the actual capture pan is added to the native reference frame.
No global fitting function, other figure's method or supplied annotation changed.

Documented floor offenders remain untouched in
`../feedback2/floor_guard_exceptions.json`: Thrall far ankle **+0.070364564 m**
(mq-07), Herald far ankle **+0.048713929 m** (its v2 unit), Lancer spear butt
**+0.269636631 m** (its v2 unit; may be intentional). Gloam's +0.005412659 m
passes without exception. `floor_guard.json` reports the complete current audit.

## Native provenance and integration

One native mesh cannot truthfully certify both the old frozen front and newly
planted rear. The original root build/capture/cold proof is explicitly scoped
to **front**. `delivery/view_sources.json` binds the separate rear recipe and
the independently sealed `delivery/rear_native/` certificate. Both actual native
spec hashes and raw mesh/joint hashes retain their original values. No proof
was relabelled with another build's spec hash.

The root cold-proof binding additionally includes the per-view descriptor,
rear cold certificate, source recipe, fit policy and accepted fit report hashes.
The rear certificate binds its actual capture report, PNG manifest, single-view
joints, collision/ownership reports, pan report and exact native replay.
The shared PNG storage avoids duplicating delivery images. Root combined joints
retain the exact original front entries and new rear entries.

Verification rejects missing view sources, failed rear geometry or collision,
stale native proofs, changes to frozen front files/joints, wrong fixed offsets,
changed rear frame/scale, false colour-coverage counts and fit below the explicit
gate. Mutation tests exercise these rejections before resealing can hide them.
Default validation and fitting for every other figure retain their behavior.

Current existing shared edits are small, opt-in additions to `build.py`,
`cloth.py`, `compile_recipe.py`, `drape_collision.py`, `render.py`,
`capture_manifest.py`, `backend.py`, `delivery_validation.py`, `curate_delivery.py`.
Focused helpers are `rear_body.py`, `floor_contact.py`, `capture_frame.py`,
`view_delivery.py`, `view_fit.py`. Earlier front-preserving helpers remain
historical opt-in code and are not used by this rear path. One new regression
file owns the unit's coverage: `tests/test_maquette_rear_turn.py`.
There are no `.gd`, dependency, save, analytics, input, balance or other figure
changes. `protected_check.json` audits **533 original files** and reports the
authorized rear/shared changes separately; all protected front/painting/other
figure bytes remain unchanged.

## Proof for the design owner

The accepted sheet remains byte-identical; its SHA-256 is recorded in
`delivery/rear_acceptance.json`. Current native PNGs are in `delivery/` and all
native reports are in `delivery/rear_native/`. `audit.log` records the staged
turn, floor, fit, collision and frozen-front outcomes.

No windowed command or inspection fixture applies: this unit changes no Godot
runtime or `.gd` file, and the native 1024 sheet was explicitly reviewed and
accepted by the director. No window-server run was attempted or retried.
No peer review, sign-off request, Git staging/commit/push, queue edit, branch
change or publication was performed. “Staged” means the local curated delivery.

Executed headless commands, from this worktree:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-06
python3 tools/output_gdignore.py
python3 -B spec/art_identity/maquettes/hoarfrost_seer/rear_turn/feedback5/stage_rear.py
python3 -B -m unittest tests.test_maquette_blender spec.art_identity.maquettes.blender.test_source_recipe spec.art_identity.maquettes.blender.test_drape spec.art_identity.maquettes.blender.test_delivery_validation spec.art_identity.maquettes.blender.test_round3 tests.test_maquette_rear_turn -v
python3 -B spec/art_identity/maquettes/hoarfrost_seer/rear_turn/feedback5/audit.py
python3 -B tests/test_art_identity_gate.py
python3 -B -m unittest discover -s tests -p 'test_*.py' -v
python3 -B -m spec.art_identity.maquettes.blender.curate_delivery verify spec/art_identity/maquettes/hoarfrost_seer
git diff --check
```

To reconstruct the **rear only** from the retained input and approved external
CC0 bundle, use the same bridge jobs as the accepted proof. These are replay
commands, not additional unobserved claims of execution in feedback 5. Bridge
pickup limit is 120 s; once running, each job has 900 s. Use a fresh output
folder, then hash/discard native intermediates before curation.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-06
MQ06_RECIPE="$PWD/spec/art_identity/maquettes/hoarfrost_seer/rear_turn/feedback4/rear_recipe.json"
MQ06_REBUILD="$PWD/spec/art_identity/maquettes/hoarfrost_seer/rear_turn/native_rebuild"
python3 -B spec/art_identity/maquettes/blender/compile_recipe.py "$MQ06_RECIPE"
MQ06_SPEC="$PWD/spec/art_identity/maquettes/hoarfrost_seer/rear_turn/feedback4/spec_native.json"
python3 -B spec/art_identity/maquettes/blender/bridge_client.py --timeout 900 spec/art_identity/maquettes/blender/build.py -- "$MQ06_SPEC" "$MQ06_REBUILD/body" --build-only
python3 -B spec/art_identity/maquettes/blender/bridge_client.py --timeout 900 spec/art_identity/maquettes/blender/capture_view.py -- "$MQ06_SPEC" "$MQ06_REBUILD/body/maquette.blend" "$MQ06_REBUILD/rear" rear
python3 -B spec/art_identity/maquettes/blender/bridge_client.py --timeout 900 spec/art_identity/maquettes/blender/recipe_proof.py -- "$MQ06_SPEC" "$MQ06_REBUILD/determinism"
python3 -B spec/art_identity/maquettes/blender/bridge_client.py --timeout 900 spec/art_identity/maquettes/blender/exact_native_replay.py -- "$MQ06_REBUILD/determinism" "$MQ06_REBUILD/exact_native_replay.json"
```

## Chosen defaults and remaining work

No new player-facing default was chosen. Native proof defaults from feedback 4
are unchanged: named bone tolerance **1e-4 m**, harmonic **20,000 iterations /
1e-10**, existing **24** contact passes with existing collision epsilon,
hidden floor half-extent `ortho_scale`, **4** pan refinement passes, coverage
alpha **128** and colour tolerance **1**. Feedback 5 uses exact float32 camera
scale representation instead of adding a tolerance. New test-only mutations use
IoU **0.59/0.70** and **1** genuine colour pixel; they are explicit named data
fields in the regression cases. The fixed gate **0.60**, original registration
frames and reason come directly from the design owner's decision.

All design TODOs are resolved. The read-only rr-07 compatibility patch remains pending the scope decision described above. The historical fixed/dynamic
registration conflict is closed by feedback 5. Other figures' documented floor
exceptions belong to their assigned units and are not repaired here.
