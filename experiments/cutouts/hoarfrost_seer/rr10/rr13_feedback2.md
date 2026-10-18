# rr-13 feedback 2 — peer-review gate fixes

Stopped for director inspection: stricter locality flags 12 additional native
frames (33 hole pixels total). No exception was added, no source art or motion
changed, and no native capture was recaptured or rebound. Changes remain
uncommitted. Original peer-review findings 3/4 (walking and generic-module
creature specifics) remain deferred to rr-11.

## Changes

- Hole locality now requires overlap with the existing seam band, rather than
  containment of the whole hole. Boundary ownership remains >=80% of one pair,
  both owners required, with staff-bounded holes exempt. The native elbow's
  3x3 and 7x7 deletions are flagged as [9] and [49].
- Bone evidence requires ok=true, no reported errors, exact current input and
  compiled-motion hashes, and the complete two-view inventory: authored keys,
  endpoints and midpoints plus every presented clip frame. Missing/duplicate
  rows and wrong phases fail. The checks also apply to standalone native gates.
  `proof/samples.json` is retained and refreshed; every bone transform is
  identical to HEAD. Only input binding hashes changed.
- Torso/head tests exercise both signs at and above normal 4/6 degree and death
  25/20 degree limits. The 70% boundary negative fixture retains both owners.
- Keep all three layouts: `tools/rebake_cutout_rests.gd` lines 118/135 reads and
  updates the top-level family copies. Normalized parity across authoring,
  humanoid_v2 production and top-level copies passes in both views, including
  a depth-change mutation of each copy. No layout was changed or deleted.

## Observed focused proof

- rr10 Python: `Ran 63 tests in 51.544s` / `FAILED (failures=2)`.
  Both failures are existing historical captured-body assertions, unchanged:
  `test_captured_shoulder_and_belt_openings_close_and_regression_reopens` and
  `test_new_rigid_tucks_close_the_captured_wrist_and_foot_openings` (death 30).
  Each now returns [2] instead of []. The stricter locality exposes an extra
  hole; assertions were not weakened to clear it.
- Final bone-evidence tests, including a stale individual layout hash:
  `Ran 5 tests in 5.939s` / `OK`.
- Silhouette focused tests: `Ran 5 tests in 0.018s` / `OK`.
- Layout parity: `Ran 1 test in 0.438s` / `OK`.
- `test_rr07_production`: `Ran 5 tests in 71.388s` / `OK`.
- `test_maquette_rear_turn`: `Ran 18 tests in 14.512s` / `OK`.
- `RR10 RUNTIME: PASS (10 checks; headless logic only)`.
- `RR07 RUNTIME: PASS (73057 checks, 0 failures; headless logic only)`.
- `RR10 BONE SAMPLES: PASS (1258 poses; headless transforms only)`.
- `RR10 BONE/CUT GATES: PASS (0 errors)`.
- In-memory check mutations: remove torso limit CAUGHT (4 assertion failures),
  remove head limit CAUGHT (4), boundary fraction 0.7 CAUGHT (10), restore
  whole-hole locality CAUGHT (1). No errors or surviving mutations. Empty
  evidence, failed sampler, reported error, stale hash and missing rows are
  caught by the evidence regressions.
- `git diff --check`: exit 0. Full suites and windowed runs were not attempted.

Logs: `/private/tmp/rr13-f2-{focused,evidence-final,silhouette,parity,production,rear-turn,rr10-runtime,rr07-runtime,samples,gates,mutations,native-audit}.log`.

## Existing native capture audit

`python3 /private/tmp/rr13_f2_native_audit.py` calls the actual `native_errors`
gate over `proof/native/`, with `hole_details` collecting rejected component
sizes. Details and capture-manifest SHA are retained in
[the audit JSON](proof/rr13_feedback2_native_audit.json).

`RR13 NATIVE AUDIT: FAIL (13 errors; 12 unapproved hole frames)`.
The extra error is `stale native proof inputs`: only gates.py,
silhouette_gates.py and the new bone_evidence.py differ from the director's
capture bindings. That freshness failure remains enforced; no stale proof was
certified. Diagnostic crops are `/private/tmp/rr13-f2-native-failures/`.
The original `proof/native_gates.json` remains the historical director PASS.

| View | Clip | Frame | Hole pixels |
| --- | --- | ---: | ---: |
| front | death | 27 | 2 |
| front | death | 28 | 2 |
| front | death | 29 | 2 |
| front | death | 30 | 2 |
| front | death | 68 | 4 |
| front | mark | 18 | 3 |
| front | mark | 22 | 3 |
| front | mark | 48 | 3 |
| front | mark | 49 | 6 |
| rear | mark | 20 | 2 |
| rear | mark | 21 | 2 |
| rear | mark | 22 | 2 |

No further gate calibration or exception edits were made after this result.
The director inspects these frames before deciding the next step. Full-windowed
native/sheets/review commands remain in `rr10_proof.sh` and were not run here.

## Files and defaults

Implementation/test/evidence files changed this round:

- `experiments/cutouts/hoarfrost_seer/rr10_gates.py`
- `tools/humanoid_cutout/gates.py`
- `tools/humanoid_cutout/bone_evidence.py`
- `tools/humanoid_cutout/silhouette_gates.py`
- `tests/test_rr10_bone_evidence.py`
- `tests/test_rr10_layout_parity.py`
- `tests/test_rr10_humanoid.py`
- `tests/test_rr10_silhouette_gates.py`
- `tests/test_rr07_production.py`
- `experiments/cutouts/hoarfrost_seer/rr10/proof/samples.json`

This handoff, its audit JSON and README also record the result. No new design
TODO. The only new chosen test default is `FIXTURE_OVER_LIMIT_DEG = 1.0`.
60 fps and EPSILON reuse the existing proof contract; 7x7 is director-supplied.
Protected motion, paintings, exception list, runtime, other creatures, layouts
and density records are unchanged.
