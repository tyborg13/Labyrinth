**Historical, superseded by [feedback 3](../feedback3/README.md).** Its preview images were hashed and discarded to keep the figure budget; current runnable proofs are in feedback 3.

# mq-06 feedback 2 — front gate passes; native delivery remains blocked

The revised front gate passes on the corrected **actual** far-leg rig, but this is a diagnostic capture, not a certified or staged delivery. The last completed native build fails the existing body/robe collision check. The next bridge job timed out after 120 seconds. Native work stopped at that deadline without a retry, as the unit brief requires. `bridge_timeout.json` records director exit `-1`, 120.0 seconds, and job `mq03-f8a2c749685741c5ac41f75383443b86`.

The canonical `measurements.json` and all delivery files remain unchanged. `correction_recipe.json` contains the authorized, opt-in correction without rewriting any of the supplied measurement values. The unproven triangle-constraint experiment was removed from the active builder after its timeout; its source and intermediate outputs were hashed before removal.

## Numbered requirements

1. **Root cause: complete.** Capture already uses a positive-determinant exact 180° root rotation, the same camera, and unchanged anatomical side labels. The paired fit lifted the far ankle by 0.156967104 m instead of placing it deeper. See `../root_cause.json`, `../diagnose.py`, and the original native reproduction logs. The old delivered rear IoU is **0.755072833**.
2. **Floor and front correction: implemented and diagnostically measured; not staged.** The compiled joint chain, actual registered leg bones, body skin, and far hem are corrected along the front camera ray. The unchanged native clothed body is solved first; evaluated Solidify shells are then moved along that ray, retaining their original triangle diagonals. Re-evaluating Solidify or choosing new quad diagonals changes the projected rim and is deliberately avoided. Skinning and projection errors are reported rather than inferred from joint names.
3. **Rear rebuild, fit and coverage: incomplete.** A certified corrected rear has not been captured. Therefore there is no after IoU, after coverage table, or corrected three-cell rear sheet to approve. The existing same-camera, exact-turn capture code is unchanged. `TODO_DESIGN_REAR_FRAME` and `TODO_DESIGN_REAR_FIT_REGISTRATION` remain explicit in `status.json`; no camera or registration decision has been substituted.
4. **Regression and general guard: implemented; delivery regression still fails.** The test discovers every complete front/rear delivery, including the Lancer's complete r2 archive (r3 contains only clays). It determines the lower foot from solo pixels and checks front/right and rear/right placement plus genuine near/far colour dominance over the torso. Other figures pass; the unchanged Seer delivery fails. The floor guard accepts only documented, unique, known-point exceptions with reasons and authority. Seer's exception list is empty.

## Heights and native validity

Reference plane: near ankle Z = **0.026642927722 m**. Heights below are from the last completed native build and its actual mesh/rig correction, not the earlier prototype.

| Contact | Before Z, m | After Z, m |
| --- | ---: | ---: |
| Far ankle | 0.183610032158 | 0.026642927722 |
| Far hem boundary minimum | 0.116210013628 | 0.026642927722 |
| Far hem boundary maximum | 0.313963472843 | 0.026642927722 |
| Staff butt | -0.002259472098 | -0.002259472098 |

All 121 far hem boundary points reach the reference plane. The staff butt was already below that plane, so it was not moved. Near-side hem vertices and waist pins stay fixed. Maximum baked front projection error is below 0.000027 px; maximum native skinning error is below 0.000001 m.

The corrected native build passes the floor-height guard, bone/region ownership and facing checks. Hood, scarf and robe torso collision checks pass. The robe skirt still has **59 intersecting body/cloth face pairs, 113 samples below the existing 0.003 m margin**, and minimum signed distance **-0.006201778 m**. Those assertions have not been weakened. `native_front8/build_report.json` and `capture_checks.json` retain `passed: false`. A passing front silhouette gate cannot certify this failed native geometry.

An earlier prototype mistakenly used body region names (`thigh_far`, `shin_far`, `foot_far`) as bone names. Its joints moved while the bound foot did not. That evidence is historical only. The production config now names `hip_far`, `knee_far`, `ankle_far`, and a fail-fast check and regression fixture reject the old mistake. Earlier prototype rear fit numbers must not be used as a corrected-body acceptance result.

## Front v2 gate and proof

`native_front8_gate.json` binds the compared capture manifests and the design-owner contract.

- Whole figure: **0 alpha-byte changes; 0 binary silhouette changes**.
- Head, torso/collar, both arm unions, both hands, staff union, robe union and near foot: **0 changed pixels, 0 px displacement**.
- Far foot: **2 changed pixels / 3997 union pixels = 0.0500375%; displacement within 1 px**.
- All front joints: **0 px**.
- Clay value record, not a gate: **56,109 changed RGB pixels / 252,849 figure pixels**; maximum absolute channel difference **191/255**; mean absolute RGB-channel difference per changed pixel **8.970723651/255**; mean maximum-channel difference **9.302375733/255**.

`front_gate_sheet.png` is **3072×1024**: original front clay | corrected diagnostic front clay | corrected diagnostic part map. All cells are native 1024 pixels. It was visually inspected. This is the front proof; it is not the missing corrected rear sheet.

The diagnostic front ownership and facing checks pass; `capture_checks.json` confirms capture did not mutate the geometry. The diagnostic preview PNGs have been packed to fit the figure budget. Clay preserves every RGBA byte. Masks preserve every alpha byte and every visible RGBA byte, clearing hidden RGB only. `native_capture_manifest.json` and `preview_encoding.json` retain the original native byte hashes; `capture_manifest.json` binds the packed previews. The front gate was rerun after packing with identical numerical results.

## Other guard findings — no changes to those figures

| Figure | Contact and lift above its near ankle | Documented disposition |
| --- | --- | --- |
| Thrall | far ankle +0.070364564 m | mq-07 |
| Herald | far ankle +0.048713929 m | Herald humanoid v2 unit |
| Lancer | spear butt +0.269636631 m | Lancer humanoid v2 unit; may be intentional |
| Gloam | far ankle +0.005412659 m | within 0.02 m limit |

`floor_guard_exceptions.json` contains these documented exceptions and an empty Seer list. The unchanged committed Seer is correctly reported **FAIL** at +0.156967104 m. The diagnostic corrected candidate's floor contacts pass, while its native collision gate fails. The guard preserves the physical measurements even when an exception permits a deferred figure.

The portable audit covers fitted ankle joints and explicit prop path endpoints; native floor-length cloth contacts are supplied separately to the same `contact_guard` from mesh boundaries. It does not assume that a shirt, short tabard or banner touches the floor.

## Verification and proof for the design owner

Run portable proofs from the worktree root:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-06
python3 -B spec/art_identity/maquettes/hoarfrost_seer/rear_turn/feedback2/front_proof.py
python3 -B spec/art_identity/maquettes/hoarfrost_seer/rear_turn/feedback2/scan_floor_contacts.py
python3 -B -m unittest discover -s tests -p 'test_maquette_rear_turn.py' -v
```

Observed result lines:

- `front_proof.log`: `FRONT_V2_GATE: PASS; alpha=0 px; joints=0.0 px; native build=False`.
- `focused_builder.log`: `Ran 43 tests in 3.660s` / `OK`.
- `focused_turn.log`: `Ran 6 tests in 2.799s` / `FAILED (failures=1)`; the Seer rear delivery is unchanged.
- `art_identity.log`: `Ran 111 tests in 49.087s` / `OK`.
- Full Python discovery (`python_full.log`): `Ran 845 tests in 844.514s` / `FAILED (failures=1, skipped=63)`. The sole failure is the new regression against the unchanged Seer rear delivery. All other executed tests passed; skip reasons remain in the verbose log. This is not a full-suite PASS.
- `native_front8_capture.log`: `FITTED_VIEW_CAPTURE: FAIL; view=front`; director exit 1, 66.5 s. The failure preserves the native collision result; facing and front preservation pass separately.
- Last completed corrected build: `BLENDER_MAQUETTE: FAIL`; director exit 1, 24.2 s (`native_corrected8_build.log`).
- Next job: director exit `-1`, **120.0 s**; no retry.
- Protected-byte audit: **533 files checked**, only the two authorized existing builder files changed; no unexpected changes (`protected_check.json`). New helper files are additive.

No `.gd` files changed. A separate Godot runtime suite, windowed visual probes and `inspection_fixture.py` are not applicable to this native-maquette unit. Standard Python engine-fixture children remain in the full discovery log. No local Blender process was launched. The brief's bridge deadline prevents further native commands in this attempt. When native work is explicitly resumed, regenerate a spec from `correction_recipe.json` and use only `bridge_client.py` with `build.py` and `capture_view.py`; never treat the retained failed diagnostic preview as a certified build.

Exact native commands for a later, explicitly resumed attempt **after the body/robe fix** are below. They were not issued after the deadline. Each capture requires a passing native build; no diagnostic override is included. These are bridge commands, not local windowed commands.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-06
MQ06_PROOF=spec/art_identity/maquettes/hoarfrost_seer/rear_turn/feedback2
python3 -B -m spec.art_identity.maquettes.blender.compile_recipe "$MQ06_PROOF/correction_recipe.json"
python3 -B spec/art_identity/maquettes/blender/bridge_client.py --timeout 120 spec/art_identity/maquettes/blender/build.py -- "$MQ06_PROOF/spec_native.json" "$MQ06_PROOF/resumed_build" --build-only
python3 -B spec/art_identity/maquettes/blender/bridge_client.py --timeout 120 spec/art_identity/maquettes/blender/capture_view.py -- "$MQ06_PROOF/spec_native.json" "$MQ06_PROOF/resumed_build/maquette.blend" "$MQ06_PROOF/resumed_front" front
python3 -B spec/art_identity/maquettes/blender/bridge_client.py --timeout 120 spec/art_identity/maquettes/blender/capture_view.py -- "$MQ06_PROOF/spec_native.json" "$MQ06_PROOF/resumed_build/maquette.blend" "$MQ06_PROOF/resumed_rear" rear
```

## Chosen defaults and remaining work

No camera, player-facing value, label, painting or other figure was changed. Numerical/proof-only defaults are named in code: `FLOOR_DEFAULTS` (20,000 convergence iterations, 1e-10 epsilon, proof projection 1024 px; the 0.02 m limit is the owner's requirement), `NATIVE_FLOOR_DEFAULTS.skinning_error_max_m` (1e-4), `FRONT_GATE_DEFAULTS.alpha_threshold` and regression `PROOF_DEFAULTS` (128, inherited from existing pixel coverage; sRGB tolerance 1), `GATE_FIXTURE` (8×8 synthetic masks, square [2:6], RGB 10→200), and `front_proof.PROOF_DEFAULTS.cell_px` (1024, specified by the brief). Bridge deadline is the required 120 s. Floor/interpolation synthetic coordinates are explicit local test data. The robe contact correction reuses the existing collision margin; it adds no clothing-clearance tuning.

Open work: resolve the native robe/boot intersections, certify a fresh front build and captures, stage authorized front outputs, capture the corrected rear with exact 180° turn, resolve the two rear proof decisions if still needed, measure rear fit/coverage, create the required corrected rear sheet, and obtain a passing delivery regression and full Python suite. No peer review, commit, staging in Git, publication or queue mutation was performed.
