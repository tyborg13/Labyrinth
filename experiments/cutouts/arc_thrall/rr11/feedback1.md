# rr-15 feedback 1 — target direction and visible tube

The closed-cap `tube_tip` already travels along rear forward. No sign flip
occurs in the target offset, two-bone solve or painted tube transform. The
backward-looking exposed end in the supplied sheets is the elbow/socket end;
the forward closed cap is occluded by the torso/head. Rear jab also requests
an endpoint inside the chain's minimum reach. No visual/runtime fix has been
applied: changing that pose requires the owner's target/landmark interpretation
or revised protected data. Changes remain uncommitted.

The prior armpit question is resolved by the director's two approved entries in
`gate_exceptions.json`. Those entries and all prior windowed proof are preserved.

## 1. Root cause evidence

Coordinates below are source pixels, before presentation rounding. Angles are
screen-space axis angles from elbow to cap; positive y points down. Full traces
also include the forearm transform's rotation, requested/solved reach, neutral
target, channels, elbow, held-item world angles and the final painted-cap point.

| View/action | Phase | Authored tip | Solved tip | Elbow | Tube axis |
| --- | ---: | --- | --- | --- | ---: |
| front jab | .45 | 122.390, 202.498 | 122.390, 202.498 | 174.440, 125.370 | 124.013° |
| rear jab | .45 | 137.872, 101.623 | 147.355, 111.131 | 76.329, 39.932 | 45.070° |
| front tether | .35 | 96.626, 173.960 | 96.626, 173.960 | 177.324, 127.637 | 150.143° |
| rear tether | .35 | 153.255, 56.935 | 153.255, 56.935 | 61.855, 98.888 | −24.655° |

Rear rest tip is `(44, 204.750003)`, and forward is
`(0.894427191, -0.447213595)`. At jab contact the solved tip's displacement
from rest has forward dot **+134.311136 px**; at tether hold it has dot
**+163.825466 px**. At phase .5 the tether tip is `(154.149, 56.488)`.
The rigid painted cap follows the same direction after presentation snapping.

Rear jab's authored shoulder-to-target distance is **43.037295 px**, while the
rest-length difference requires at least **56.466234 px**. The existing inner
reach clamp therefore moves the endpoint outward and puts the short upper arm
back across the shoulder-to-target ray. Flipping bend side cannot make that
unreachable target reachable while retaining both lengths. Front jab remains
inside its reachable annulus. No length, clamp, bend side or key was changed.

The retained native isolated pieces directly identify the overdraw:

| Rear native frame | Presented cap on 512 canvas | Opaque layers, back to front |
| --- | --- | --- |
| jab 18 | 274, 241 | tube z11; loincloth z11; **torso z14** |
| tether 35 | 283, 186 | hidden_torso z−9; tube z11; **head z13** |

The tube is parented to `fore_near`, and `held_items` is empty in both views.
There is no held-item world-angle override. The projected rest bend signs are
front −1 and rear +1, matching their painted geometry. The independent signed
IK/length gates pass. These observations locate the apparent reversal in the
visible portion of a partly occluded, correctly directed tube, with the rear
jab pose additionally constrained by minimum reach.

`proof/rr15_feedback1.json` records **TODO_DESIGN_REAR_TUBE_AIM_INTERPRETATION =
null**. Keep the current closed-cap target, or provide the approved revised
rear aiming interpretation/geometry. No replacement key, depth, stretch,
attachment or visible pose has been invented.

## 2. Front preservation

All **495** pre-feedback front pose records have byte-identical canonical JSON,
including every Bone2D and rigid sprite matrix. SHA-256:
`d4db893bb9c386313d844a1102dc05128f8f468c4471cdbb47b4a8b48b1bf805`.
The front layouts, textures and compiled/director motion bytes also match the
feedback-start snapshot. Runtime scripts, all assets, all Seer files and the
approved exceptions remain unchanged. The sampler adds diagnostic fields only.
No fresh GPU pixels were captured by this worker.

## 3. Seer check

Rear staff-hand motion is forward for mark, bolt and ward. At their maximum
positive hand-forward key:

| Action | Phase | Grip forward displacement | Crystal apex forward displacement | Staff world angle |
| --- | ---: | ---: | ---: | ---: |
| mark | .72 | +12.022598 px | +47.404137 px | +30° |
| bolt | .50 | +7.315841 px | +41.153819 px | +28° |
| ward | .30 | +3.420021 px | **−9.745687 px** | −8° |

The diagnostic crystal apex is the mean x of the highest opaque source row;
it adds no rig landmark. Ward's apex moves backward because the protected
authored staff angle tilts it that way while the grip moves forward. Front ward
does the same: apex **−7.964665 px**, grip **+5.488780 px**, angle **+8°**.
This is not a rear projection sign flip. No Seer data or runtime was changed.

## 4. Gate and proof

`tools/humanoid_cutout/action_direction.py` independently reconstructs FK and
the existing rest-length reach clamp. It checks the solved displacement caused
by a positive forward channel against the same body/lift pose with only that
target's forward channel zeroed: dot with the view projection must be **> 0**.
This isolates coordinate direction from lift, recoil and recovery. A positive
forward key alone does not promise positive *combined* displacement from rest;
changing that existing behavior would violate front preservation.

The gate runs through `bone_errors` and `rr11_gates.py` in every clip containing
a keyed hand/custom tube target. `tests/rr11/action_direction.gd` retains normal
pose records and additionally samples continuous Bone2D transforms at every
presented frame. This avoids letting pixel rounding erase tiny positive keys.
The `native` proof stage now uses this sampler, and refuses missing continuous
evidence. Reversal mutations fail in both views; missing frames/evidence fail.

Per-frame logs:

- `/private/tmp/labyrinth_codex/rr-15/feedback1/thrall_direction.json`
- `/private/tmp/labyrinth_codex/rr-15/feedback1/seer_direction.json`
- `/private/tmp/labyrinth_codex/rr-15/feedback1/seer_staff_apex.json`

Observed final results:

```text
Ran 57 tests in 14.060s
OK
Ran 29 tests in 47.517s
OK
RR11 SOURCE/CUT GATES: PASS (0 errors; both views)
RR11 BONE/CUT/KNEE GATES: PASS (0 errors)
RR15 FRONT ACTION DIRECTION: PASS (458 positive checks)
RR15 REAR ACTION DIRECTION: PASS (458 positive checks)
RR15 ARC_THRALL FRONT DIRECTION: PASS (458 positive checks; minimum dot 0.000647086)
RR15 ARC_THRALL REAR DIRECTION: PASS (458 positive checks; minimum dot 0.001525833)
RR15 HOARFROST_SEER FRONT DIRECTION: PASS (467 positive checks; minimum dot 0.001569506)
RR15 HOARFROST_SEER REAR DIRECTION: PASS (467 positive checks; minimum dot 0.001569506)
SFX SYNC HARNESS RESULT: PASS (1970 observations, 0 failures)
SFX SYNC HARNESS RESULT: PASS (1647 observations, 0 failures)
SFX SYNC HARNESS RESULT: PASS (791 observations, 0 failures)
RR11 NATIVE PROBE LOAD: PASS
```

The 57-test command includes the 32-test registration audit, 4 new direction
tests, the original 14 Thrall tests and the 7 native-cleanup regressions. The
29-test command checks Seer humanoid/rear/bone-evidence behavior. Commands,
trace hashes, acceptance status and chosen defaults are in
`proof/rr15_feedback1.json`; the feedback-only file list is
`proof/rr15_feedback1_changes.txt`. No full suite, windowed run, peer review or
commit was performed.

Chosen debug defaults: `PROOF_TIMEOUT_SECONDS = 180`; temporary landmark
overlays use radius 2 px, zoom 3, red for the cap and cyan for the elbow. The
reach/evidence tolerances and sample/presentation rates are inherited unchanged.

## Proof for the design owner

All stages retain 1920×1080 and 100% UI scale. Existing density/rest proof was
accepted at feedback start; no asset or runtime bytes changed in this feedback.
Exact recapture commands:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-15 && LABYRINTH_TASK_ID=rr-15 sh experiments/cutouts/arc_thrall/rr11_proof.sh density
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-15 && LABYRINTH_TASK_ID=rr-15 sh experiments/cutouts/arc_thrall/rr11_proof.sh rest
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-15 && LABYRINTH_TASK_ID=rr-15 sh experiments/cutouts/arc_thrall/rr11_proof.sh native
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-15 && LABYRINTH_TASK_ID=rr-15 sh experiments/cutouts/arc_thrall/rr11_proof.sh sheets
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-15 && LABYRINTH_TASK_ID=rr-15 sh experiments/cutouts/arc_thrall/rr11_proof.sh idle
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-15 && LABYRINTH_TASK_ID=rr-15 sh experiments/cutouts/arc_thrall/rr11_proof.sh production
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-15 && LABYRINTH_TASK_ID=rr-15 sh experiments/cutouts/arc_thrall/rr11_proof.sh review
```

The existing output paths are `proof/native_rest/`, `proof/native/`,
`proof/contact_sheets/`, `proof/idle_native/`, `proof/production_native/`,
`proof/thrall_protagonist_idle.mp4` and `proof/arc_thrall_review.mp4`.
No inspection-fixture command is requested by this brief.
