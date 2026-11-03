# rr-44 — feedback 2 implementation and proof

Work is based on `c1adc9360` on `codex/rr-44`. All feedback-2 changes are
uncommitted. No peer review, publication, branch operation or windowed Godot
run was performed. The director's supplied paintings, underlays, recipes,
motion and provenance are unchanged.

## Feedback 2 acceptance

1. **Grip and boot defects.** The old presentation snapped the chain's crop
   independently of the fist's crop. Bone-space grip agreement could therefore
   pass while the painted item separated. The optional painted-grip binding
   now assigns the complete item transform from the presented fist, with no
   second origin snap. It stops at the facing-specific authored release.
   Held items no longer earn a detached-component exemption. Only an exactly
   verified released chain can earn that exemption.

   The rear chain also contained 20 boot texels. Those texels and the old
   hidden-coat duplicate now belong to the boot they touch at rest. Two front
   points follow their real source owners: the belt point belongs to the
   pelvis, and the visible coat-edge point belongs to the coat. Exact transfer
   coordinates are in `rr44_feedback2_ownership.json`; no new colour is used.
   A rear boot-edge texel is likewise transferred to the coat it touches.
   Ownership uses the existing rr-42 contact priorities and lexical tie-break,
   so independent builds cannot choose different owners.
   The unapproved procedural duplicate at torso source `(179,83)` is cleared;
   the already-owned approved black torso edge and its exact cap are retained.
   The same rule retires the far-shin donor at rear source `(131,216)`, which
   otherwise travels outside the boot in move 46. Its approved boot owner and
   paint remain intact. The foot donor at `(134,214)` is likewise retired over
   an already-owned coat cell. Exact source/owner RGBA assertions and the
   bound retirement field share `rr44_feedback2_ownership.json`; clearing any
   unrelated support cannot borrow that authority. Dropping the field fails.

   Removing boot ink changes the automatic chain-extremum measurement. The
   approved r1 death landing/rotation datum is retained rather than retuning
   the approved drop. `painted_end_source` records the cleaned artwork's actual
   endpoint separately; the virtual death datum is not described as paint.

   `rr44/fixtures/native_r1/` contains the director's two chain regressions,
   three boot witnesses and nine other witness frames, each with the native
   composite, every isolated native piece, frozen source and poses. Manifest:
   `1ba4c6511c9ac48dafb38408b5f80b600d3eb25a82baba20b03877429ebba2ad`.
   The full replay contains 892 poses, checked against all 14 native-origin
   anchors. Tests use these files, never ignored proof logs.

2. **Joint caps.** Every cap copies its own approved source texels across the
   joint. The new caps are separate layers: accepted backing is preserved when
   a cap moves away. Both sides of the far elbow retain their own sleeve
   paint. The grip cap returns to the hand at release, so no glove paint drops
   with the chain. Rigid-source cap bones use the source sprite's complete
   presented transform. Actual helper matrices are independently recorded and
   checked, including released death poses.

   The visible far sleeve retains the approved r1 vertices, UVs, triangles,
   weights and weight bounds exactly, checked against the hash-bound fixture.
   Its upper and fore bands are separate hidden overlays. Rigidifying the
   visible sleeve, or putting the new fore band in an old foreground backing,
   changes its approved contour/occlusion and creates flat fragments.

   Hidden caps have separate negative draw depths behind every existing
   backing (`2 * original_depth + hidden_floor - 1`, plus one for the fore
   overlay above its matching upper overlay). Interleaving a cap with
   another garment can split an unchanged textured region into flat fragments.
   Front neck caps close the late-death join with the same approved paint.
   Visible depths and authored depth tracks
   are unchanged. The CPU uses recorded painted-node transforms and draw
   depths, retaining an independent bone-space oracle. Rigid
   hole references use the painted source transform, including the attached
   chain's correction. Existing node names and IDs are retained.

3. **Director paint authority.** All 34 historical requests are decided in
   `rr44_feedback2_decisions.json`; the historical request catalogue remains
   unchanged. The accepted gambeson flank is bound to the supplied underlay
   hashes. The 20 backing regions are frozen as exact view/part/UV/RGBA values
   in `spec/peer_benchmark/staged/rr-44/feedback2_backing_acceptance.json`.
   Recolouring or clearing an accepted opaque texel fails.
   The continuation addendum freezes 168 effective r1 RGBA values across seven
   clips at already accepted UVs. The original static acceptance remains
   unchanged; wrong values, cleared pixels and the wrong clip all fail.

   The flat ratchet retains 4,202 CPU regions and 4,198 native regions, each
   across 743 frames. New regions and growth greater than 2px fail. The native
   baseline was measured from the original isolated native images, with every
   image hash checked. The material-reference domain is fixed to the immutable
   r1 source; correcting missing-paint demand cannot change that comparator.
   Exact own-paint joint bands are moving garment paint rather than backing.
   Spatial correspondence accounts for an existing region splitting or
   merging when occlusion changes, consuming each baseline pixel count once.
   For example, the old 10px and 6px rear-reel patches become one 17px patch
   under the corrected chain; 19px still fails the unchanged +2px limit.

   The original front far-leg backing keeps its alpha and skinning. Opaque supplied
   underlay texels replace its old constant donor inside that existing moving
   footprint. This addresses the flat patch exposed by the corrected chain.
   No paint is synthesised.
   Rear underlay scope stays inside the arm footprint. Continuation recipes
   retain immutable r1 source UVs, rebase them to current crops and remove
   targets superseded by opaque approved paint. Schema checks run on source
   and production recipes.

4. **Gates and proof.** Current result lines, failure lists, bindings and crop
   paths are recorded in `rr44/proof/feedback2_results.json`. Final native
   pixels and the director's 3–4× judgment remain pending. The windowed native
   stage also runs a bounded exact-source RGBA proof and the native flat
   ratchet before the complete gate bundle.
   The authored release retires only the chain/fist ownership adjacency;
   body-joint pairs remain active. The hash-bound rear death-31 native frame
   proves its 6px opening belongs to the released grip rather than a body seam.

## The four idle diagnostic categories

The native witnesses and per-pixel locations are in
`rr44/proof/feedback2_categories/{front,rear}.json`; eight named 4× crops sit
beside them. Every crop comes from the frozen native RGBA. Check masks are
explicitly identified as reconstructed CPU masks.

| Category | Measurement and calibration |
|---|---|
| `missing` | A transported required domain over transparent paint. Front idle 15 contains one legacy demand over source-transparent support. The hash-bound r1 domain fixture removes hypothetical demand, independently of the texture under test. Deleting actual opaque native paint still fails exact RGBA proof. |
| `foreign` | Exposed paint outside its own donor palette. Both chosen idle frames measure zero. Exact accepted source values extend donor authority; a recoloured native pixel fails. No colour-range tolerance was added. |
| `outline` | Dark ink in an exposed continuation. The rear idle crop shows supplied/accepted original ink. Authority is exact source-coordinate RGBA, not a dark-colour exemption. |
| `uncovered_outline` | Interior ink in an uncovered receiving surface. Both chosen idle frames measure zero. The independent exact-paint gate remains strict. |

Both immutable native idle witnesses have zero remaining source-authority
metrics. Classification fixes do not waive joint holes or detached components.
No unbound CPU/native rounding allowance was introduced.

## Other-rig preservation and elbow report

All 10,294 old/current runtime poses are byte-identical. Existing elbow
findings are report-only; no other rig was changed. The original 82 worst-case
crops remain in `rr44/proof/other_elbows/`. Every failing frame additionally
has its exact crop in `other_elbows/all_frames/report.json`: 2,351 failing
elbow records, 2,350 distinct frame images (one Mimic frame fails both arms).
Fresh sampled failures match the preserved nine reports exactly.

| Rig | Identical poses | Existing failing elbow records | Exact frame crops |
|---|---:|---:|---:|
| Seer | 1,258 | 5 | 5 |
| Thrall | 1,050 | 215 | 215 |
| Mirror | 968 | 9 | 9 |
| Weaver | 1,106 | 518 | 518 |
| Mimic | 1,008 | 49 | 48 |
| Mortar | 1,214 | 626 | 626 |
| Herald | 1,198 | 10 | 10 |
| Gloam | 1,096 | 481 | 481 |
| Lancer | 1,396 | 438 | 438 |

## Files and optional shared changes

The exact file inventory is `rr44/proof/feedback2_files.txt`.
It lists 194 modified tracked files and 3,022 new untracked files (3,216 total).
The 2,350 exact-frame elbow crops account for most new files. No changed file
falls outside the unit's allowed scope.

- `rr44/**`, `rr44_*.py/.sh/.json`: source cuts, exact own-paint overlays,
  ownership, immutable native fixtures, paint decisions, flat inventories,
  calibrated shards, strict grip and native-source gates, records and proof.
- `assets/units/chainbound_gaoler_cutout/**`: derived production pieces and
  layouts; existing routing and protected motion retained.
- Gaoler-only identity, density, rest and shadow records; supplied art jobs
  remain v5/v4 and their recipes replay byte for byte.
- `humanoid_held_follow.gd`, `humanoid_joint_caps.gd`, presentation/rig helpers:
  optional painted-grip binding, source-aligned cap bones and release parent.
- `painted_caps.py`, `cpu_pose.py`, `native_mesh.py`, `gates.py`: optional exact
  bands, overlay validation, matching CPU transforms and rigid cap structure.
- `tests/rr38/{samples,native_capture}.gd`: optional actual cap matrices and
  painted-reference transforms. Existing reference-set output is unchanged
  when the new fields are absent. Both dependency binders include the helper.
- `rr38_uncovered.py`: optional moving-paint and fixed reference-domain inputs;
  legacy callers retain their original calculation.
- Native/CPU joint-boundary gates consult the optional release policy for
  adjacency retirement. Existing callers and undeclared grips retain their
  original ownership rules; no free-space owner or frame exemption is added.
- Focused regressions, producers and the Python resource declaration. New
  `test_rr44_feedback2.py` writes only unique temporary test directories and
  declares the `gaoler` resource for its production-bundle reader. It does
  not depend on an ignored proof case or proof logs.
- `tests/rr44_density_inputs.py` reconstructs new joint-cap adoption inputs
  from their declared source garments. The old density comparison assertion
  is retained. A regression verifies all 13 crops without supplying either
  the cap PNG or production source to the oracle.
- `tests/rr44/surface_probe.py` checks every actual source frame before the
  full UV sweep; `other_elbow_crops.py` creates bounded exact-frame crops with
  source/report/pose hashes and complete coverage verification.
- `.gdignore` markers keep fixtures, Blender evidence and capture/report
  output out of Godot imports. Thirty-four missing art/density/script sidecars
  are supplied. PNG import metadata was generated in an isolated PNG-only
  project at identical relative paths; four UIDs came from Godot's
  `ResourceUID.create_id`. No existing sidecar or source pixel was rewritten.

## Observed final headless checks

The final source rebuild compares all 546 source files with no changed bytes.
Source rests and rebuilt density rests are both 0px in both views.

```text
Ran 20 tests in 19.812s — OK (feedback 2 and source cuts)
Ran 6 tests in 54.380s — OK (motion and mutations)
Ran 9 tests in 23.159s — OK (feedback 1 regressions)
RR44 CPU/NATIVE CALIBRATION: PASS (1336/1336 native signatures; 892 fresh frames; max shard 6.219s)
RR44 SHARD EXECUTION: 448 shards; 0 process failures
RR44 CPU SWEEP: PASS (892 frames; 0 findings; native_calibrated=True)
RR44 ALL GATES: PASS (0 errors; native=False)
RR44 TWO-LEG WALK: PASS (254 poses; 0 errors)
MAQUETTE PRODUCTION LOGIC: PASS (1440 frames) [each view]
RR38 PRODUCTION CONTACTS/POSES: PASS (0 errors) [each view]
V2 BOARD SPRITE GEOMETRY: {"cases":8,"errors":[],"native":false,"orientation_mutations_rejected":0,"placement_mutations_rejected":0}
RR38 SHADOW RECORDS: PASS (2 v2 views; every other unit retained)
RR44 REGISTRATION AUDIT: PASS (all mq-15 rows; new native far-arm projection; unchanged certified body/feet)
ART IDENTITY CHECK: PASS (0 failures, 0 pending_reart warnings, 0 skipped replays)
```

The eight geometry cases cover the four facings in both layouts; the zero
native mutation counts above are not claimed as native-renderer mutation proof.
The preservation audit retained 147 unrelated art records, 112 density entries
and 2,187 density outputs, with no foreign rig files changed. Both native idle
witnesses have zero remaining source-authority metrics. The Python resource
audit covers all 229 modules. Full-suite results and exact failure lists are
recorded below and in `rr44/proof/feedback2_failure_lists.md`.

The first full Python attempt was stopped when its independent density oracle
raised on a new cap absent from the old rig. After extending that oracle,
`Ran 2 tests in 4.066s` / `OK` covers the original density assertion and the
new independent-cap regression. The ten earlier failure cases also passed:
`Ran 10 tests in 38.849s` / `OK`. The final full run starts after this fix.

The full run's sidecar test checks the real Git index, where the round-1
metadata was absent. The supplied sidecars and `.gdignore` markers were then
checked through that same unchanged test using a temporary proposed index:
`Ran 1 test in 4.803s` / `OK`. The actual index and object database were not
modified. `proof/feedback2_metadata.json` binds the supplied files and records
the passing follow-up; the full-run failure is retained verbatim.

## Full suites and follow-ups

The final full Python run completed after the last implementation/test-helper
change:

```text
Ran 2137 tests in 2341.731s
FAILED (failures=1, skipped=66)
```

There were zero errors. The sole failure is the cached-index sidecar test
described above; its supplied-file follow-up passes the unchanged guard.
The optional learned timing cache could not be written in the shared Git
directory. The result summary and all test results were saved.

The full Godot run completed with:

```text
MAIN BODY RUNTIME: 537.214 seconds
MAIN BODY ASSERTIONS: 495687
FULL SUITE RUNTIME: 901.609 seconds (budget 900 seconds)
TEST RESULT: FAIL (58 failure(s))
```

The failure list consists of 57 child results and the global budget assertion:
54 shared-deadline cancellations, two individual SFX deadlines, and one
menu-input child. All 173 other children passed. Every root failure is listed
in `proof/feedback2_failure_lists.md`, with complete result rows in
`proof/feedback2_godot_programs.json`.

The three individual/assertion failures were rerun sequentially with their
original limits. Both SFX children again reached 180s; menu reported seven
assertions. A separate focused group checked the 54 shared-deadline children:
35 passed, three reached individual deadlines, two failed to compile, and
14 reached the shared deadline again. No assertion or budget was rewritten.
The affected runtime child was then run directly:

```text
RR38 RUNTIME: PASS (239 checks; headless registration, views, portraits and clocks)
```

An isolated comparison restores the runtime, Gaoler production and its
density/shadow records from the pinned pre-rr-44 base
`e7913f0df5632595aa0a00566b3e06c3882ceba0`. Sixteen test/consumer sources are
byte-identical. Both SFX deadlines and both `fix_11` compile failures reproduce
there. The latter reference undeclared `GameData` at
`tests/suites/enemy_no_action_suite.gd:36` and `:128`; this helper's hash matches
the base. The comparison changed no actual checkout source.

The baseline menu had one startup assertion. A later current-runtime menu run
with failure-state logging passed every original assertion and deadline:

```text
TEST RESULT: PASS — main menu input and startup transitions
```

The logging wrapper and its hash are preserved in `proof/feedback2_results.json`.
Earlier menu failures remain recorded as intermittent results. The full suites
are not claimed green. The exact focused/baseline failure lists, result hashes,
commands and remaining deadline cancellations accompany the full-run records.

After the suites and diagnostics, every previously bound unit artifact remained
unchanged. The preservation audit again passed: protected director inputs byte
exact, no foreign rig files changed, and all 147 unrelated art records, 112
density entries and 2,187 density outputs retained. HEAD, branch and the real
Git index are unchanged.

## Original contract

The native-certified far-arm joints are unchanged this round. Exact values
remain in `rr44/maquette/spec_native.json` and `joints_source_px.json`.

| Joint | Native 3D position | Registered front px | Registered rear px |
|---|---|---|---|
| Shoulder far | `(0.24498456, -0.29676955, 1.51405107)` | `(112.79796, 81.29601)` | `(145.20204, 98.18662)` |
| Elbow far | `(0.34321393, -0.28902272, 1.24536728)` | `(106, 110)` | `(152, 118.92861)` |
| Wrist far | `(0.41538397, -0.37657563, 0.94565747)` | `(94, 137)` | `(164, 147.08433)` |

The retained native fit has front IoU `0.8489029631`, largest semantic
centroid error `4.9718029895px`, and every mq-15 acceptance row green. The rear
is the single proper half-turn `diag(-1,-1,1)`.

| Requirement | Delivery |
|---|---|
| 1. Art identity | v5/v4 unchanged; numerical recipe replay and scoped identity check pass. |
| 2. Maquette | Existing sealed native delivery retained; fresh registration audit checks every mq-15 row and the true rear half-turn. Joint positions remain those reported in `rr44_FEEDBACK1.md`. |
| 3. Cuts and rests | Both approved source rests remain 0px; root sleeves, rigid fists and one rigid held chain retained. New caps preserve original node IDs and visible overlap order. |
| 4. Painted backing | Exact supplied underlays, exact accepted r1 values, exact own-paint caps and justified clears are the complete authority. |
| 5. Motion | Director keys, body-frame delayed follow, both pendulums and elbow policy retained. Facing-specific approved death release and landing datum retained; cleaned painted endpoint recorded separately. |
| 6. Budgets | No new motion clamp. Press lift stays 22px. The retained clamp is death `coat_near_tip.lift_px`, 4→2.5px in both views. No floor is crossed. |
| 7. Elbows | Current all-frame gate and inversion/missing-policy mutations pass. The hash-bound rr-42 press/hit fixture still fails in both views. Other rigs are report-only. |
| 8. Gate bundle | Painted exposure, flat ratchet, joins, components, grip, elbows, rr-37/walk and four-facing rr-40 geometry; final native acceptance belongs to the director. |
| 9. Records/routing | Scoped deterministic rest/density/shadow refresh; unrelated records retained and production routing unchanged. |

## TODO_DESIGN, chosen defaults and open issues

There are no active `TODO_DESIGN` placeholders. Historical names remain in the
preserved request catalogue and are resolved by the decision record.

Proof defaults: 2 frames per production sweep shard, 85s child limit, 8 sweep
workers; 4 frames per calibration/surface/crop shard and 8 calibration workers;
12px crop context at 4×; existing 0.0001 matrix tolerance
and 0.751° presentation tolerance. Mutation fixtures use a 4px displacement,
RGBA `(254,7,199,255)` and a 1px region at `[0,0,1,1]`. New cap UV crops keep
the existing 2px source-grid parity. Deterministic rebuild proof uses Python
hash seed 29 and compares all 546 source files. These are engineering/proof fields, not
new motion, balance, audio or visual tuning.
The before-release boundary probe uses a named `0.000001` phase epsilon.
The final Python shard limit is 4,200s because the audit estimates its longest
serialized resource shard at 3,105.080s, above the runner's 2,400s default.
Per-Godot launch limits are unchanged.
Full Godot uses a 1,200s outer runner limit around the unchanged 900s suite
budget. Failed-child follow-ups use one worker for sequential comparisons and
three for the shared-deadline subset, retaining the existing 180s child and
900s parent limits. The read-only menu diagnostic uses the existing 85s proof
limit and the original test's assertions/deadlines. The comparison base is
pinned explicitly rather than following a moving branch.
The isolated metadata project uses the named `gl_compatibility` renderer and
Godot's default lossless PNG import settings. Its four opaque UIDs are
engine-generated identities and have no player-visible value. Its 85s runner
limit is the existing proof-child limit.
Debug-only overview sheets use a 1600×900 grey `#555555` canvas: a 4×2 grid
of 400×450 tiles for category crops, and a 3×3 grid of 533×300 tiles with
510×270 maximum thumbnails for the other-rig overview. The underlying exact
frame crops remain separate in their reports.

Windowed proof is pending because this sandbox has no macOS WindowServer.
No windowed command was attempted or retried.
Fresh native rest/density seals and the final native gate verdict remain with
the director; headless records are explicitly identified as such.
The project-wide deadline/standalone-test failures remain open with their
failure lists and comparison evidence. The nine other rigs' elbow findings
remain report-only. No active design decision is outstanding.

## Proof for the design owner

Run from `/Users/borgerding/workspace/Labyrinth.worktrees/rr-44` at 1920×1080,
100% UI scale. The director is rerunning `native`, `sheets` and `review` this
round; all seven exact stage commands are retained here.

```sh
bash experiments/cutouts/chainbound_gaoler/rr44_proof.sh density
bash experiments/cutouts/chainbound_gaoler/rr44_proof.sh rest
bash experiments/cutouts/chainbound_gaoler/rr44_proof.sh native
bash experiments/cutouts/chainbound_gaoler/rr44_proof.sh sheets
bash experiments/cutouts/chainbound_gaoler/rr44_proof.sh idle
bash experiments/cutouts/chainbound_gaoler/rr44_proof.sh production
bash experiments/cutouts/chainbound_gaoler/rr44_proof.sh review
```

Outputs: `rr44/proof/native/`, `native_rest/`, `contact_sheets/`,
`idle_native/`, `production_native/`, `chainbound_gaoler_review.mp4` and
`chainbound_gaoler_protagonist_idle.mp4`. The owner judges the native clips in
both views at 3–4×. The owner also owns the inspection fixture and commit.
