# rr-37 feedback 3 implementation handoff

All changes are uncommitted. This round repairs covered surfaces and rear spear ownership, adds an uncovered-surface gate, and retains actual rejected native evidence. No windowed run, full suite, peer review, publication or branch operation was performed. Fresh native acceptance remains the director's work.

## Feedback 3 requirements

1. **Front behind the far arm.** The complete approved upper-arm, forearm and hand footprint has separate `covered_torso` and `covered_cape_far` underlayers, attached to the existing body/cloth transforms. The torso continuation follows the measured armpit/flank to the belt inside its source outline; the remaining footprint continues the existing teal far-cloak strip to the cloak outline. The originally misassigned teal strip now belongs to `cape_far`. Fill uses only the corresponding piece's approved interior mail/leather or cloth. Every donor is more than 2 px from geometric and keyed rest outlines; that source-space donor whitelist survives density processing. Existing own-material clip continuations close the reported front cast joint pocket without reducing motion. Both source rests still report `rest mismatch: 0 px`.

2. **Rear where the spear was.** The measured wood and adjacent source outline, including the disconnected lower black shaft runs, belong to `spear`. Glove paint belongs to `hand_far`; cloth paint belongs to the cloak. A cloak underlayer continues its own material through the original spear footprint over the cloak. Its extent is clipped to the approved cloth-connected outer outline, retaining the real cloth edge and excluding the wider maquette wedge in painted air. Source textures and all clip recipes obey that bound.

3. **Spear edges and glove tuck.** The visible approved shaft and outline are transferred unchanged. The new covered shaft follows measured wood row centres through the glove/cloak occlusion, using the director's 2–3 px target for this hidden core. It uses only the spear's deep wood donors. A final 4× software inspection found that the generic joint tuck was widening the hidden shaft back to the glove width; the builder now clips that tuck to the same shaft core, and a regression rejects reintroduction. The adjoining arm/hand clip coverage closes the wrist pockets exposed by narrowing that tuck, using the same deep own-material donors. Visible plus hidden spear source alpha is one 8-connected component in both source and treated production scopes. The rear visible and hidden spear textures share the visible piece’s derived presentation anchor, so their rigid transform snaps once; independent crop-origin snapping split the narrow shaft after release. No motion, planting anchor or grip retargeting was used.

4. **Uncovered-surface gate and rejected-native regression.** `rr37_uncovered.py` transports the original rest occluder footprints, required receiving surfaces, source ownership and donor certificates through every presented pose. It checks actual native RGBA against hashed isolated native layers, not a software proxy. Newly exposed surface must be owned original paint or certified own-material continuation; it rejects uncovered missing pixels, foreign footprint paint, internal outline texels, opaque components of 3 px or fewer, and rear cloth outside its physical outline. Existing actual native seam pockets are included, so cast 4's 10 px pocket at `[270,295,275,301]` is detected exactly. All native frame/layer/check/pose and binding hashes are verified. The gate is also applied to every production-rest software raster frame as a construction check.

   `feedback3_fixture/` retains the exact round-2 native front cast 4/12, lunge 20, guard 25 and rear lunge 36, plus front/rear cast-0 controls, isolated layers, seam/hole transports and the original production cut closure. It binds full native manifest SHA-256 `a2115a5cc5aeff0dfed780954df3ef0a1bee2ae759f4ab3aabfc734791f752ac` and full failed gate log SHA-256 `c777671c6bf857c8aa8547e1ec29576cf2e9cc1c60c70af39ed11afbe36355f8`. The new gate rejects all five requested actual native failures and keeps both controls clean. `proof/feedback3_rejected_uncovered.json` records the metrics. Mutations remove the fill, leave one real spear texel on the cloak, add an interior outline fragment, and construct 1/3 px opaque islands; all fail. A 4 px island is outside the tiny-component rule while other rules remain active. Tests read this tracked-intent fixture or generate fresh evidence, never ignored logs.

## Original brief and accepted rounds retained

- **1 — cut/rest:** torso still owns pauldrons/chest crystal; pelvis owns belt/pouches; cloth chains, skinned root limbs and rigid hands/boots are retained. Spear remains one rigid item at `hand_far`. Front visor/crystal feature ownership is unchanged. Source rests are 0 px; production uses the exact density-treated rest and independently composed byte-bound parts.
- **2 — draw order:** camera arm remains above torso, pelvis and every visible/hidden/covered cloak layer; head remains above arms. The draw-order check now includes every logical body/cloth layer, including the new coverage, with a failing mutation. Crystal contact visibility checks remain active.
- **3 — production:** the accepted data-driven move/action/contact/hit/death routing and static-roster removal are unchanged. No mechanics, tuning, saves, input paths or analytics changed. Cast retains its protected 16 px lift.
- **4 — knees:** policies and measured stance bends are unchanged: front near 2.937947°, front far 7.612614°; rear near 2.264802°, rear far 9.347591°.
- **5 — gates:** idle, clean pieces, seams/strays, all-action signed direction, every move swing/support, dense minimum reach, native alpha components, draw order, held-item attachment/rigidity and rr-36 defect diagnostics remain active. Overreach is reported rather than failed. Feedback 2's declared `spear`/`death` exemption still reads the protected `release_at` 0.3; only a complete single-component spear can be the one extra post-release component. Its pre-release, foreign-component and fragmented-item mutations remain intact.

Feedback 1's rear `hand_near`, `belt`, `pelvis` and `tabard` remain intentionally empty with the exact director reason: “covered by the cloak in the approved rear painting (director, rr-37 feedback 1)”. Integration is production-ready with no design placeholders. Native visual acceptance is recorded separately and remains pending.

## Generic change and why earlier gates missed these defects

The only generic change in this round is `tools/humanoid_cutout/gait_continuations.py`: optional `continuation_interior_margin_px` (default 0) excludes outline neighborhoods; optional donor-side `continuation_donor_uvs` (default omitted) restricts recipes to certified original interior coordinates. Omission preserves existing behavior. All 168 focused reference tests pass. Every other rig remains byte-identical.

The old CPU diagnostic checked only sparse source-paint poses and shared the cut's ownership masks, so it could not expose density-outline ownership errors. Feedback 1 replaced that with strict full-frame treated-production raster checks. Those component/joint checks still accepted connected wrong-material fragments and open tears, and a low-percentile outline heuristic missed the director's clean-outline RGB `[20,16,21]`. This round adds independent source footprint/underlay domains, source donor depth certificates, the protected processed-paint outline metadata, and actual-native RGBA/layer ownership checks. Software evidence is explicitly not a fresh native renderer seal.

`proof/feedback1_verification.json`, `proof/feedback2_verification.json` and their fixtures are historical. Current commands, observed result lines, log hashes and implementation hashes are in `proof/feedback3_verification.json`. `proof/native_gates.json` explicitly says fresh recapture is pending; it does not relabel the rejected round-2 proof.

## Proof for the design owner

Run all seven stages in order from this worktree at 1920×1080 and 100% UI scale, then judge native clips at 2–4×:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-37
sh experiments/cutouts/frostglass_lancer/rr37_proof.sh density
sh experiments/cutouts/frostglass_lancer/rr37_proof.sh rest
sh experiments/cutouts/frostglass_lancer/rr37_proof.sh native
sh experiments/cutouts/frostglass_lancer/rr37_proof.sh sheets
sh experiments/cutouts/frostglass_lancer/rr37_proof.sh idle
sh experiments/cutouts/frostglass_lancer/rr37_proof.sh production
sh experiments/cutouts/frostglass_lancer/rr37_proof.sh review
```

These stages use the required visual runner. Captures stay ignored under `proof/native/`, `proof/native_rest/`, `proof/contact_sheets/`, `proof/idle_native/` and `proof/production_native/`. Reels: `proof/frostglass_lancer_review.mp4` and `proof/frostglass_lancer_protagonist_idle.mp4`. Native uncovered diagnostics are in `proof/production_case/proof/logs/uncovered_surfaces.json`. Rebuild software previews with `PYTHONPATH=tools:experiments/cutouts/frostglass_lancer python3 experiments/cutouts/frostglass_lancer/rr37_feedback3_preview.py`. Final inspected software samples are in `proof/feedback3_cpu/` (including nearest-neighbor 4× crops); these are construction previews. No inspection-fixture command was requested in this worker's scope.

## TODO_DESIGN placeholders

None.

## Chosen defaults

No player-facing value was chosen. Empty continuation texture capacity is padded by 4 px (`CONTINUATION_CANVAS_PADDING_PX`) to preserve the existing 2 px mesh grid/presentation anchor while permitting the own-glove joint continuation. Gate transform comparison epsilon is 0.0001 (`REST_TRANSFORM_EPSILON`, existing proof precision). Named test defaults in `tests/test_rr37_feedback3.py::MUTATION_DEFAULTS` select front cast frame 12, a 2 px island isolation radius, and donor target UV `(0,0)`; these affect only mutations. `rr37_feedback3_preview.py::PREVIEW_DEFAULTS` sets the proof-only crop `[140,130,430,430]` and nearest-neighbor scale 4. The seven retained native samples are the five director-requested failures and two rest controls. Source trace boundaries/shaft centres are measured from the approved paint; 2 px donor clearance, 2–3 px hidden shaft and 3 px tiny-component threshold come from feedback 3.

## Open issues

Fresh director native proof and 2–4× visual acceptance remain pending. Density `--check --only frostglass_lancer_cutout` correctly exits 1 for the two changed production rest records until the director runs the windowed density rebake; no native rest seal is forged. Headless Godot emits the existing macOS certificate and shutdown resource warnings while returning exit 0 and passing its checks. The intermediate narrow-tuck raster run found 55 rear-frame failures (`rr37-feedback3-shaft-all-focused.log`, `Ran 25 tests in 642.344s`, `FAILED (failures=1)`); the adjoining own-material clip coverage was repaired. A subsequent full raster found 8 released-spear connectivity failures (`rr37-feedback3-complete-focused.log`, `Ran 36 tests in 722.625s`, `FAILED (failures=1)`); the shared presentation anchor fixes that texture alignment. The remaining 2 px wrist pocket and two lunge gaps were closed with own-material continuations. Final results are recorded below. No other implementation failure is waived.

## Observed final verification

- focused: `RR37 ROUND3 UNCOVERED CPU: PASS (7 production-rest poses; not native proof)` / `RR37 ROUND2 UNCOVERED REGRESSION: PASS (all 5 requested native failures rejected; 2 rest controls clean)` / `RR37 BONE SAMPLES: PASS (1396 poses; headless transforms only)` / `RR37 FRONT PRODUCTION FRAMES: PASS (512 frames; 0 failures; software raster, native runtime poses)` / `RR37 REAR PRODUCTION FRAMES: PASS (512 frames; 0 failures; software raster, native runtime poses)` / `Ran 36 tests in 648.918s` / `OK` / `RR37 REJECTED NATIVE REGRESSION: PASS (6 rejected frames + 1 unchanged rear-idle control; components and joint seams detected)` / `RR37 REJECTED PRODUCTION RASTER: PASS (detects 6 components > rest 1)` / `RR37 BONE SAMPLES: PASS (1396 poses; headless transforms only)` / `MAQUETTE PRODUCTION LOGIC: PASS (1634 frames)` / `MAQUETTE PRODUCTION LOGIC: PASS (1634 frames)`
- references: `Ran 168 tests in 285.574s` / `OK`
- art_identity: `Ran 111 tests in 41.240s` / `OK`
- gates: `RR37 BONE SAMPLES: PASS (1396 poses; headless transforms only)` / `RR37 ALL GATES: PASS (0 unique errors; native=False)` / `RR37 FRONT: cut=0 bone=0 direction=0 walk=0 supports=0 spear=0 facing=0 reach=0 overreach=6` / `RR37 REAR: cut=0 bone=0 direction=0 walk=0 supports=0 spear=0 facing=0 reach=0 overreach=6` / `RR37 BONE SAMPLES: PASS (1396 poses; headless transforms only)` / `RR37 ALL GATES: PASS (0 unique errors; native=False)` / `RR37 FRONT: cut=0 bone=0 direction=0 walk=0 supports=0 spear=0 facing=0 reach=0 overreach=6` / `RR37 REAR: cut=0 bone=0 direction=0 walk=0 supports=0 spear=0 facing=0 reach=0 overreach=6` / `RR37 COMPACT SAMPLES: PASS (1396 poses; full transforms in ignored logs)` / `RR37 COMPACT SAMPLES: PASS (1396 poses; full transforms in ignored logs)`
- shadow_and_probe: `RR37 SHADOW RECORDS: PASS (2 v2 views; every other unit retained)` / `RR37 NATIVE PROBE LOAD: PASS`
- sfx: `SFX SYNC HARNESS RESULT: PASS (4243 observations, 0 failures)` / `SFX SYNC HARNESS RESULT: PASS (3516 observations, 0 failures)` / `SFX SYNC HARNESS RESULT: PASS (1688 observations, 0 failures)`
- registration: `TEST REGISTRATION AUDIT: PASS (814 scripts; full suite=461, quarantined=29, windowed probe=324)`
- bounds: `RR37 ACTION CAPACITY: PASS ([-267, -255, 534, 279]; zero canvas-edge pixels; CPU construction)`
- preservation: `RR37 FEEDBACK3 PRESERVATION: PASS (37914 protected tracked files; paintings, maquette, motion and every other rig byte-identical)` / `RR37 NON-LANCER REGISTRIES: PASS (all non-Lancer entries and metadata unchanged)` / `RR37 SHIPPED MOTION: PASS (director and compiled motion byte-identical; branch codex/rr-37)`
- final_scope: `RR37 FINAL SCOPE: PASS (only owned paths and the optional donor helper; all protected inputs and other rigs unchanged)` / `RR37 NON-LANCER REGISTRIES: PASS (exact equality for every other entry and metadata field)` / `RR37 DIFF CHECK: PASS` / `RR37 PROOF SHELL SYNTAX: PASS`
- density_check: `rest rebake needed: assets/units/frostglass_lancer_cutout/humanoid_v2/front/rest.png: rest pixels changed since recorded rebake` / `rest rebake needed: assets/units/frostglass_lancer_cutout/humanoid_v2/rear/rest.png: rest pixels changed since recorded rebake`
