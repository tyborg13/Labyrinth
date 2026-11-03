# rr-42 feedback 1 implementation handoff

The current round is documented in [rr42_FEEDBACK2.md](rr42_FEEDBACK2.md). This file preserves the feedback-1 implementation history.

All changes are uncommitted on `codex/rr-42`. Headless acceptance passes. Native pixels, windowed visual judgment and publication remain with the design owner. No windowed command, peer review, sign-off, commit, push, branch operation or queue edit was performed.

This report supersedes the round-0 status. `rr42/proof/rr42_receipts.json` remains the historical round-0 receipt; the current receipt is **`rr42/proof/feedback1_receipts.json`**, with complete source-UV fragment decisions, final log hashes, result lines and resolved execution attempts. Large transform logs and CPU crops remain ignored proof outputs.

## Numbered acceptance requirements

1. **Paint authority.** The protected rr-42 paint, masks, prompt, provenance and preview are unchanged. The latest protected rr-38 director tracks are copied byte for byte to the editable case and production. Underlay authority now includes every inventoried exposed hidden-source UV, including texels outside the footprints and previously excluded limb attachments. `rr42_feedback1_repairs.json` records **188 UVs: 72 exact supplied RGBA replacements and 116 clears**. Density authority also preserves exact painter RGBA where the raw source already matched the painter but the former density-treated production did not. Procedural recipes cannot overwrite that authority. No new paint was synthesized.
2. **Fragments and continuation fills.** The partition receipt and current handoff receipt enumerate **20 original-paint fragments / 221 source texels**. Ten fragments / 200 texels are re-owned to their rest-contact pieces, with their exact original RGBA; ten fragments / 21 texels are cleared under the director's speck rule. Each row includes source, target or clear, contact counts, UVs and reason. The rear reel witness adds one isolated presented one-pixel boot speck. Expanded storage retains original skin-weight fields and sprite snapping anchors, so existing shared vertices retain their old weights. Old detached generated coat/boot fills and continuation targets stay retired. The final rear missing-surface inventory is empty (`rr42/proof/rear_holes.json`); no rear underlay was painted.
3. **Director motion and measured channel limits.** Death is the supplied forward slump over planted feet. Both views retain hip drop **6 px**, torso lean **24°**, torso forward **8 px**, helm bow **16°**, chain drop/release and chain-arm fall **−36**. Hip/lean floors **3 px / 12°** are respected without approaching them. Press retains lift/forward **22 / 18**. Only the following channels are clamped, toward rest, to the largest passing tested values on the declared **0.25-unit grid**:

   | Clip | Channel | Authored peak | Accepted peak |
   | --- | --- | ---: | ---: |
   | death | `coat_near_tip.lift_px` | 4 px | 2.5 px |
   | pin | `chain.angle_deg` | 55° | 30.5° |
   | reel | `chain.angle_deg` | 75° | 38.25° |

   All higher grid candidates were rejected by calibrated witnesses or complete clips. Search receipts are `rr42/proof/feedback1_{death_coat_near_tip_lift_px,pin_chain_angle_deg,reel_chain_angle_deg}_search.json`; accepted clips were independently resampled through actual headless Godot Bone2D transforms. Search tools can re-test the original authored peaks after promotion while retaining unrelated live clamps. No other authored channel, timing or curve shape changes.
4. **Strict gates, mutations and calibrated proof.** The final sweep passes **892 / 892 frames**, with `painted_exposure=True`, packed/reference skinning and every nearest-UV choice, with independent choices between layers. Visible hidden texels require exact registered director RGBA or an authorized clear. Required opaque paint remains independent of output alpha. The presence check pairs a requirement and its own layer alpha with the same UV choice; it cannot combine mutually exclusive choices of that one layer. Other layers remain independent. The earlier 13 one-pixel false presence findings and their correction are recorded in `rr42/proof/feedback1_presence_pairing.json`. Mutations restore old fills inside and outside footprints, inject old recipes, delete required paint, enlarge clear masks and corrupt clear geometry; the gates reject them. The final bundle passes zero errors. Diagnostic implementation and policy receipts are hashed alongside runtime inputs, so changes invalidate the sweep.
5. **Deterministic derived records.** Rebuilt editable and treated production parts, density inputs/output records, rests, source seam/hole references and both Gaoler shadow entries. Fresh headless production Godot rest poses match both stored rests at **0 pixels**. The front/rear difference from historical original rests is exactly the authorized **8 / 13 cleared visible texels**. Density and art registry edits are limited to this Gaoler's entries; the shadow updater asserts all other units remain unchanged. Rest evidence explicitly records `native_pixels=false`, and native integration readiness stays pending.

Feedback points 1–4 are covered respectively by items 3, 2, 1, and 4–5 above. There are **no unresolved `TODO_DESIGN` placeholders**.

## Files changed

- `rr42_build.py`, `rr42_underlay.py`, `rr42_density.py`, `rr42_fragments.py`, `rr42_references.py`, `rr42_motion.py`: exact paint/air, fragment transfer, retained weight fields, source references, channel-only clamps and deterministic records.
- `rr42_exposure.py`, `rr42_gates.py`, `rr42_sweep.py`, `rr42_runtime_gates.py`: expanded exact-RGBA certification, correlated own-layer UV requirements, all-rounding proof and diagnostic hashes.
- `rr42_candidate.py`, `rr42_channel_search.py`, `rr42_angle_budget.py`, `rr42_repairs.py`, `rr42_detached_inventory.py`, `rr42_feedback1_report.py`, `rr42_feedback1_{clamps,fragments,repairs}.json`: reproducible headless searches, complete repair receipts and handoff evidence.
- `rr42/**` and `assets/units/chainbound_gaoler_cutout/**`: this unit's derived source/production parts, layouts, masks, donor certificates, rests, compiled/current copied motion, integration and proof records. Generated candidate outputs are scoped in the case `.gitignore`.
- Gaoler-only entries/sources in `spec/assets/board_pixel_density/**`, its art identity entry and its two shadow-cache entries in `assets/generated/unit_shadow_cache.res`.
- `tests/test_rr42_gaoler.py`, `tests/rr42/angle_samples.gd` and UID: nine focused tests and actual production-sampler/Bone2D batching. `tests/test_rr38_gaoler.py` now pins the immutable historical fixture to its tracked local director and build SHA while still requiring live production to match the currently protected director. Existing thresholds are unchanged.
- `tools/humanoid_cutout/gates.py`: optional/additive support for a visible mesh's retained `weight_bounds` when checking its hidden layer. Existing rigs default to their original bbox. The unchanged-reference compilation checks pass.

## Observed verification

Focused tests only, as requested in feedback 1. Neither full suite was rerun; round-0 worktree import/class-cache/proof-folder failures remain historical, without rewritten assertions. Final log copies and SHA-256 values are under `rr42/proof/logs/feedback1_final/` and the current compact receipt.

```text
Ran 86 tests in 156.182s
OK
Ran 9 tests in 29.234s
OK
Ran 125 tests in 276.047s
OK
RR38 CPU/NATIVE CALIBRATION: PASS (263/263 frame/kind signatures; 314 native errors; 0 misses)
RR39 NATIVE UNCOVERED TIES: PASS (64 resolved: 33 outline, 31 missing; 0 remaining; exact retained native pixels)
RR38 RUNTIME: PASS (239 checks; headless registration, views, portraits and clocks)
V2 BOARD SPRITE GEOMETRY: {"cases":88,"errors":[],"native":false,"orientation_mutations_rejected":0,"placement_mutations_rejected":0}
PREPARED UNIT CANVAS RESULT: {"cases":64,"checks":4864,"errors":[],"native":false,"orphans":0,"pixel_differences":[]}
TEST REGISTRATION AUDIT: PASS (841 scripts; full suite=487, quarantined=29, windowed probe=325)
RR42 SOURCE AUTHORITY: PASS (0 errors; 4589 justified clear texels)
RR42 REST EQUIVALENCE: PASS (front=0px rear=0px; native_pixels=False)
RR38 SHADOW RECORDS: PASS (2 v2 views; every other unit retained)
CHECK-OK
RR42 CALIBRATED SWEEP: PASS (892 frames; 0 findings; painted_exposure=True; native_pixels=False)
RR42 ALL GATES: PASS (0 errors; native=False)
RR42 FEEDBACK1 RECEIPTS: WRITTEN (headless_ok=True; native_pixels=False)
```

The 86-test group covers Gaoler source/historical/reference-compilation checks, board density and sidecars. The final nine-test rerun includes the added rounding-correlation regression and outside-footprint restoration mutation. The 125-test group covers historical native calibration, retained native ties, the rr-40 isolated production-package mutation and all 111 art identity checks. The prepared-canvas entry point also runs the rr-40 sprite-geometry oracle. Engines used only the task runner.

```sh
LABYRINTH_TASK_ID=rr-42 python3 -B -m unittest tests.test_rr42_gaoler tests.test_rr38_gaoler tests.test_board_pixel_density tests.test_godot_sidecars -v
LABYRINTH_TASK_ID=rr-42 python3 -B -m unittest tests.test_rr42_gaoler -v
LABYRINTH_TASK_ID=rr-42 python3 -B -m unittest tests.test_rr38_feedback3 tests.test_rr39_native_ties tests.test_rr40_feedback tests.test_art_identity_gate -v
python3 tools/godot_task_runner.py --task-id rr-42 --stream -- godot --headless --path . --script tests/rr38/runtime_checks.gd
python3 tools/godot_task_runner.py --task-id rr-42 --stream -- godot --headless --path . --script tests/prepared_unit_canvas_equivalence_test.gd
python3 tools/test_registration_audit.py --json /private/tmp/rr42-f1-final-registration.json --markdown /private/tmp/rr42-f1-final-registration.md
python3 -B experiments/cutouts/chainbound_gaoler/rr42_sweep.py --exposure
python3 -B experiments/cutouts/chainbound_gaoler/rr42_gates.py
python3 -B experiments/cutouts/chainbound_gaoler/rr42_runtime_gates.py
```

Resolved attempts remain recorded: an initial new mutation fixture selected a UV inside a footprint and was corrected to outside UV `[177,181]`; the reference/sidecar run initially encountered tracked generated candidate PNGs without imports and now has a scoped generated-output exemption; the old own-layer pairing produced 13 false presence findings; an extra direct invocation of the RefCounted rr-40 helper timed out at 300 s. The valid `tests/prepared_unit_canvas_equivalence_test.gd` entry point passed all 88 geometry cases and 4,864 equivalence checks. No windowed run was attempted or retried.

## Proof for the design owner

Run from this worktree. These seven exact commands use `tools/visual_probe_runner.py` for renderer work at **1920×1080, 100% UI scale**. Inspect press, the forward death slump, chain drop, and front/rear walk at **2–4×**. The superseded kneel is absent by director decision.

```sh
sh experiments/cutouts/chainbound_gaoler/rr42_proof.sh density
sh experiments/cutouts/chainbound_gaoler/rr42_proof.sh rest
sh experiments/cutouts/chainbound_gaoler/rr42_proof.sh native
sh experiments/cutouts/chainbound_gaoler/rr42_proof.sh sheets
sh experiments/cutouts/chainbound_gaoler/rr42_proof.sh idle
sh experiments/cutouts/chainbound_gaoler/rr42_proof.sh production
sh experiments/cutouts/chainbound_gaoler/rr42_proof.sh review
```

Capture roots: `rr42/proof/{native_rest,native,contact_sheets,idle_native,production_native}`. Movies: `rr42/proof/chainbound_gaoler_{protagonist_idle,review}.mp4`. Current full headless poses, gate results and sweep are in `rr42/proof/production_case/proof/logs/`; retained CPU diagnostic crops are under its `rr42_crops/`, and are not native captures. No final failing-frame crop is required because the final sweep has zero findings. The brief assigns inspection-fixture preparation to the design owner and supplies no fixture scenario/command; none was invented.

## Chosen defaults and open issues

Only proof values were chosen: **0.25** authored units per channel-search step; **4** frames per shard; **2** shard workers; **180 s** shard deadline; **300 s** Bone2D batch deadline; **128** triangles per raster batch; **12 px** crop context; **4×** crop enlargement. These are plain constants/named fields in the proof tools and current receipt. Adaptive witness frames and full-clip results are recorded in the search receipts/requests. Speck threshold **6 px** and motion floors/targets are director decisions, not defaults.

Open acceptance: the design owner's native captures and visual judgment. No design question or headless failure remains. This handoff makes no native-clean or full-suite-green claim.
