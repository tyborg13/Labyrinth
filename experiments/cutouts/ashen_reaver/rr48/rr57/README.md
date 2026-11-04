# rr-57 implementation contract

Standard rig-routing change, implemented in the prepared `codex/rr-57` worktree.
The design owner owns commit, peer review, inspection and publication.

1. Raise rake/sweep/fall sword-hand peaks to shoulder +12/0/-12 source px in each view. Preserve seconds, contact phase, exact contact transforms, and every fall transform from contact onward. Reachable hand targets and blade angles are in the staged source and both compiled copies.
2. Keep the original facing-flexion elbow policy. Front sweep/fall need an outer hand arc: a straight interpolation chord folds through the shoulder. The existing solver, presentation and typed-array contract remain in use.
3. Measure all 390 native-grid attack frames with the calibrated rr-48 CPU oracle. Keep full targets and report tears; never infer native-clean budgets from CPU alone. Emit source-registered underlay requests without changing paint. Run fresh native gates and the CPU-superset audit before accepting a budget.
4. Preserve the production walk-01 move and gait verbatim, and carry them into the staged/case source. Keep idle/hit/death and all contacts unchanged. The three baseline JSON files here preserve the exact production authority used for replay and regression comparison. The retained case had a stale positive-y rear axis; the attack-only compile adopts production’s already-approved negative-y rear axis, while leaving production’s projection unchanged. All zero-diff contact assertions use current production as the authority.

Implementation constraints: the current elbow branch prevents a rear sweep wrist behind the shoulder without inversion. Its retained legal shoulder-height guard is retained with the blade drawn back. Fixed arm lengths stop the low sweep 19 px (front) / 29 px (rear) above the far knee. At the rear rake height, even unrestricted grip rotation cannot clear the crest: the absolute geometric minimum tip y is 13.424, while the posed crest is y 9.168. These limits need director resolution, not unapproved anatomy or paint edits.

Only one shared-runtime line was added: opt-in `windup_torso_limit_deg`, active strictly before contact and safe for rest loads. The old torso clamp applies from contact onward. The rr-48 case compiler and held-item gate recognize this approved raised-wind-up exception; all other phases retain their limits.

Tools: `rr48_raised_motion.py` authors/replays the attack-only compile; `rr48_raised_report.py` measures exact poses; `rr48_raised_budget.py` records clean observations and masks; `rr48_raised_native_superset.py` fails closed when CPU misses native cavities/outline/slabs.

The design-owner handoff is `/private/tmp/labyrinth_codex/rr-57/result.md`, with hash-bound transforms, CPU findings, requests, test results and exact native/sheets/production commands. No native image is claimed from the implementation sandbox.

## Feedback 1 — front sword arm outside the helm

The director replaced the original front wind-ups with a side guard: wrist x <= posed sword shoulder x - 4 px; no far-arm/gauntlet paint may overlap head or hidden_head. Sweep/fall blade paint also stays clear. The rear and all contact-on channels/poses are protected by `feedback1_baseline_*` and the extended exact-phase probe.

`rr48_front_windup.py` solves the hand path on the outside arc. `front_guard_solver.gd` selects the nearest candidate that passes the unchanged authored/presented elbow and wrist gates. The requested 12-px-high front fall requires a fully extended side guard and produces detached paint in 18 native-grid frames and at the exact peak. The highest tested clean whole-pixel peak is 11 px above the shoulder; this explicit 1 px budget limit is recorded in `front_guard_budget.json`. Full-height motion remains hash-replayable under `/private/tmp/labyrinth_codex/rr-57/feedback1/full_target/`; its source-registered hidden-fill requests are retained under `experiments/cutouts/ashen_reaver/underlay_requests/rr57_feedback1/`.

`rr48_front_clearance.py` counts every painted arm and helm layer before draw-order occlusion. Its per-frame checks also run on the director's native images through the native-superset audit. Current results and exact native/sheets/production commands are in `/private/tmp/labyrinth_codex/rr-57/result_1.md`.

The default test group's pre-existing tracked-sidecar failure cannot be cleared without staging: HEAD contains `raised_attack_samples.gd` without its `.uid`. Both that sidecar and the new solver's sidecar are supplied uncommitted; the owner must stage each source/sidecar pair together. No test assertion was weakened.
