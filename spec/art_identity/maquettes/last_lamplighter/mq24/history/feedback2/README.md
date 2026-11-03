# mq-24 — feedback 2

The far hand and thumb meet the revised rules. The near fist remains
**diagnostic and unaccepted**: the fixed dimensions cannot seat the fixed
ring using only axial palm travel and wrist roll. No gate was relaxed and
no additional visible design choice was made. All changes are uncommitted.

## Requirement results

| Requirement | Observed result |
|---|---|
| Original 1: remove plates; mantle over shoulders | Preserved from accepted round 1. No pauldron objects/labels; torso owns mantle; exact 4/3 tongues and original neckline. All 1,372 native mantle/arm probes are clear. |
| Original 2 / feedback 2.1: free claw | **12°** is the smallest permitted whole-degree fan that passes. Four fingers at −18°, −6°, +6°, +18°. Native minimum front tip gap **0.015489864 H**, above 0.015 H. Other dimensions, roots, curls, pointed tips and thumb stay prescribed. |
| Original 3 / feedback 2.2: fist and ring | Three 90° knuckles per finger, positive blunt radii and exact lengths implemented. The closest permitted diagnostic candidate uses **−0.010 H axial adjustment, −3.8° wrist roll**. Ring/chain stay fixed. It cannot meet containment/contact/visibility/penetration gates. |
| Feedback 2.3: near thumb | Two joints **53° / 37.82154°**. Actual native distal-cap clearance **0.003845019 H** outside the nearest finger's middle segment. Total length 0.045 H. Pass. |
| Original 4: part labels | Fixed distinct hand colours, one rig part per hand, mantle torso-owned, no pauldron labels. |
| Preservation | Every non-hand source piece matches the pinned accepted round-1 digest. Native mantle coordinates/connectivity match that reference. All mq-20 protected bytes, joints, camera and retained meshes pass; **8/8 limb lengths pass**. |
| Proof | Fresh native/captures/replay are diagnostic. **6 caught / 0 survived** native target-gate mutations. The full director-contract assertion remains a failure; no accepted delivery is claimed. |

## Far-hand selection

`design_details.json` and `contract.json` record 12°. `feasibility.py` emits
all six alternatives and measures their actual claw apices through the
retained front camera; it does not use producer diagnostic values as targets.
The 0.015 H minimum is strict: the metric tolerance cannot admit 11°.

| Fan step | Minimum front tip gap / H | Pass |
|---:|---:|---|
| 9° | 0.013774351 | no |
| 10° | 0.014346640 | no |
| 11° | 0.014918493 | no |
| 12° | 0.015489863 | yes — selected |
| 13° | 0.016060711 | yes |
| 14° | 0.016630994 | yes |

## Fist infeasibility

The independent bound uses the pinned mq-20 ring vertices and director
numbers, independently of generator paths and the sampled pose search:

- A 0.075 H finger with proportions 0.45 / 0.33 / 0.22 has segment lengths
  0.03375 / 0.02475 / 0.0165 H. Three 90° knuckles place its middle centreline
  0.03375 H along the palm normal from the forearm axis.
- All fixed ring vertices lie within 0.020360236 H of the wrist. Even allowing
  the maximum 0.005 H middle radius, the clearance is at least
  **0.03375 − 0.020360236 − 0.005 = 0.008389764 H**. Required: 0.001 H.
  Axial translation and roll cannot change this bound, even between samples.
- The distal tip stays 0.01725 H off the palm plane. Subtracting the palm's
  0.006 H half-depth and the 0.003 H blunt tip radius still leaves a
  **0.00825 H physical gap**. A virtual palm bridge in the signed-crossing
  disk does not fill this gap in the real mesh.

The bounded search checks 401 rolls × 201 axial positions = **80,601 poses**.
It finds **zero feasible poses and zero upper-loop crossings**. The nearest
candidate's actual native middle clearances are approximately 0.02986,
0.03018, 0.02693 and 0.02396 H; maximum ring penetration is 0.00456558 H,
above 0.004 H. Its thumb contact succeeds independently.

The director was asked asynchronously for a changed construction constraint.
No answer or additional pose permission was assumed. A decided dimension or
articulation rule must change to produce the requested closed channel. The
ring, chain, wrist position and iron limbs were not moved to conceal the
conflict. There are **no TODO_DESIGN keys**: this is a conflict between fully
specified rules, not missing raw coordinates.

## Independent gates and native proof

`contract.json` remains independent of authoring data. Measurement recovers
stations, radii, curls, fan, thumb contact, ring crossings, clearance and
wrist pose from live opened meshes. Native mutations change Blender mesh
data, re-read it, check the relevant independently passing gate and verify
restoration. A failed full baseline cannot claim full mutation acceptance.
The table therefore says `opened_native_target_gates_only`.

The accepted round-1 mantle is pinned in `round1_preservation.json`.
Blender's existing normal bake fixes its source hem-rim winding. The oracle
independently derives adjacent-face consistency and outward orientation
from the pinned shell; it never adopts live candidate winding. The inherited
sabaton's global winding handling remains unchanged. No mesh was changed for
this comparison.

Fresh evidence (relative to this directory):

- `proof/feedback2-native-r1/native/maquette.blend`: native editable build.
- `proof/feedback2-native-r1/capture/`: front/rear clay and parts, all solos,
  `joints_px.json`, four exact `*_hand_*_3x.png` crops, same-scale
  `contact_sheet.webp`, segment and mutation tables, and failed acceptance.
- `proof/feedback2-regeneration-r1/`: fresh copied-source rebuild and pixel
  comparison; no native model or cache copied as input.
- `feedback2_feasibility.json`: whole-degree fan sweep and continuous bound.
- `verification_results.json`: exact commands, exit codes, result lines,
  evidence paths, failed gates and hash-bound log references.

The sheet order remains old art, mq-20 front, mq-24 front, mq-20 rear,
mq-24 rear. Native clays have the same physical 1:1 scale; old art uses exact
4×. Hand crops are exact 3× nearest-neighbour pixels. Prior-round narrative,
measurements and results are archived in `history/feedback1/`.

## Chosen defaults

`chosen_defaults.json` names construction/proof controls: 401×201 bounded
pose samples, 101 middle-surface samples and 121 root-angle samples for the
two-link thumb solve, balanced-link tie-break, inherited 12-sided sweep and
oval topology, forearm frame, mesh-normal adjacency traversal, numerical
epsilons/tolerances, four-solo batches, 1088px native canvas, 3× crops with
8px padding, sheet registration, test fixtures and 110s execution / 120s
response deadlines. Mantle interpolation and clearance controls are
unchanged. Chosen controls do not alter any prescribed design dimension.

## Proof for the design owner

The bridge must already allow mq-24. From this worktree, fresh destinations:

```sh
python3 -B -m spec.art_identity.maquettes.last_lamplighter.mq24.proof diagnose --out spec/art_identity/maquettes/last_lamplighter/mq24/proof/director-feedback2-native
python3 -B -m spec.art_identity.maquettes.last_lamplighter.mq24.proof regenerate --diagnostic --out spec/art_identity/maquettes/last_lamplighter/mq24/proof/director-feedback2-regeneration --capture spec/art_identity/maquettes/last_lamplighter/mq24/proof/director-feedback2-native/capture
python3 -B -m spec.art_identity.maquettes.last_lamplighter.mq20.proof verify
```

After the conflicting rule changes, use strict `proof prove`, then
`proof regenerate`, then `proof verify --capture ... --regeneration ...`.
Those gates do not convert diagnostic evidence into acceptance.

All Blender work used the approved bridge. No local windowed run or editor
scan was attempted. This offline native maquette has no Godot UI scene or
saved-run inspection fixture: `visual_probe_runner.py` at 1920×1080 and
`inspection_fixture.py` have no target here. Its native canvases retain the
brief's mq-20 physical registration. No full suites, peer review, sign-off,
preflight, task-queue edits or Git writes were performed.

The unchanged mq-20 history assertion still has `REVIEWED_COMMIT='HEAD'` in
this checkout. The director's integration fix was not imported or rewritten;
its failure is reported separately. mq-20 `proof verify` passes.

## Observed focused checks

- mq-24: `Ran 37 tests in 24.688s`; `FAILED (failures=1)` — full director contract.
- Combined focused maquette checks: `Ran 124 tests in 132.495s`; `FAILED (failures=2)` — same contract and unchanged mq-20 HEAD-history assertion.
- Delivery: `Ran 11 tests in 6.925s`; `OK`.
- Art identity: `Ran 111 tests in 95.392s`; `OK`.
- mq-20: `MQ20_HASH_BOUND_DELIVERY: PASS`.
- Resource audit: `ISOLATION AUDIT: 236 modules`; exit 0.
- Native: `MQ24_NATIVE_AUDIT: FAIL; caught=6; survived=0`.
- Native captures: `MQ24_DIAGNOSTIC_CAPTURE: COMPLETE; acceptance=False`.
- Replay: `MQ24_DIAGNOSTIC_REGENERATION: MATCH; acceptance=False`; four of four clay/parts comparisons match.

Changed files this round: `hand_construction.py`, new `fist_construction.py`
and `feasibility.py`, `contact.py`, `measure.py`, `rule_measure.py`,
`oracle.py`, `proof.py`; `design_details.json`, `contract.json`,
`chosen_defaults.json`, new `round1_preservation.json`, README, measurements,
curated delivery, reports/logs and feedback-1 history under this mq24 folder;
and `tests/test_mq24_maquette.py`. No shared builder or other figure changed.
