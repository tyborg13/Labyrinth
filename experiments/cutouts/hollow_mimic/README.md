# rr-20 — Hollow Mimic humanoid v2

Feedback 2 implementation is uncommitted on `codex/rr-20`. The integrated
shared gait/runtime code is retained. The director owns commit, review,
inspection and publication. No windowed run or full project suite was attempted.

## Feedback 2 acceptance and current limits

1. The case builds against gait-01. Protected director motion is imported
   byte for byte, `leg_roles` is retired, both legs use the shared projected
   walk and pelvis fit, and the production adapter remains data driven.
   Unit shadow refresh restores exactly the two Mimic sources while asserting
   every other cached entry and source hash is unchanged.
2. `move` uses the supplied six-step, 0.8 s near-led gait. `bolt` and `mirror`
   use the supplied `hand_far` thrusts. Dense reach reports full-extension
   overreach without changing keys. The shared front walk gate passes. Rear
   far apex bend fails the binding comparison against the stance knee at
   frames 9 and 28. Protected data remains unchanged; see the TODO below.
3. `joint_continuations.json` retains source coordinates traced from the
   director's native seam failures and the new poses. The rr-15 domain and
   nearest own-piece non-outline edge donor rule add covered paint beneath
   existing rest covers. `joint_source/` retains the pre-extension hidden
   layers; a derivation gate and mutation test verify every added texel.
   The gait-01 candidate in `gait_continuations.proposal.json` closes the two
   new move pockets with 26 own-torso donor texels. It adds 20 visible pixels
   at each rear move endpoint, so it remains **inactive** pending the rest
   envelope decision. No exemption or motion edit was added. Some native neck gaps map to
   transparent rest space in every relevant piece, and the front hair speck
   already exists in the source art. These remain design decisions; native
   acceptance is pending, not asserted.
4. Committed `samples.json`, `gates.json` and `native_gates.json` contain
   summaries, extrema and failures only. Full records live in ignored
   `proof/logs/*.full.json`, linked by SHA-256. Shared native/sheet/review
   readers accept both this format and legacy full reports. Native capture
   measures the same board step/scale as the gait sampler.
5. Focused verification and exact result lines are in
   `rr20/proof/verification.json`. Strict failures remain visible. The
   director's previous density/rest/idle (252 frames)/production (1282 frames,
   zero errors) passes apply to the prior inputs; the new motion/continuations
   require a fresh windowed chain.

### TODO_DESIGN fields

The named fields are retained in `case.py`, `rr20/inputs.json`, `cutout.json`
and production integration metadata:

- `TODO_DESIGN_rear_far_apex_knee`: rear move frame 9 is 50.870° swing versus
  57.913° stance; frame 28 is 53.229° versus 53.591°. The supplied lift is 5 px.
- `TODO_DESIGN_front_head_detached_source_texels`: front source (105,48) and
  (105,49) are detached painted hair texels. Rotation moves them beyond the
  strict 2 px distance. Removing or connecting them changes the rest image.
- `TODO_DESIGN_joint_continuation_rest_envelope`: a representative remaining
  native rear death frame 5 neck hole maps into transparent source space in
  head (118,100)–(120,102), torso (118,99)–(121,101), and sleeve
  (117,100)–(120,102). An own-piece continuation there changes rest alpha.

### Chosen defaults

New values are proof/construction only: `PROGRESS_INTERVAL_FRAMES=100`,
`PROOF_UV_MARGIN_PX=1` for retaining all opaque triangle fragments,
`RASTER_COVERAGE_MARGIN_PX=1` (the rr-15/gait-01 pixel-square construction
margin), `MAX_CONSTRUCTION_PASSES=16`, and `FIXTURE_VALUE=5` in the summary mutation test. CPU diagnostic
commands limit BLAS to one thread. No playback tuning was chosen. The tuck
and continuation depth stays the spec's 3 px. Equal-distance donors retain
row/column order. The director's residue thresholds stay unchanged.

### Observed focused results

- Unit tests: `Ran 26 tests in 109.748s`; `FAILED (failures=2, errors=1)`.
  All three failures are the protected rear apex-knee comparison, including
  production setup. The missing production walk sample issue is fixed.
- Six current production captures total 7896 headless frames. Three gates pass
  and three fail only on the rear walk's apex comparison. Contacts, existing
  cues and outcomes have no additional gate errors.
- Cross-rig regressions: `Ran 135 tests in 408.659s`; `FAILED (failures=1)`.
  Gait-01's unit-scoped no-PNG-change assertion rejects rr-20's owned PNGs.
  It is unchanged. Independent prior-rig byte checks pass.
- Mirror/evidence: `Ran 43 tests in 66.418s`; `OK`.
- Inherited RR14 tests rerun with every nested runner forced to rr-20:
  `Ran 17 tests in 3.488s`; `OK`; six Godot invocations. Their first invocation
  used their hardcoded rr-14 IDs despite the environment override; the rerun
  corrects that and leaves all inherited assertions unchanged.
- Art identity: `Ran 111 tests in 62.059s`; `OK`.
- CPU diagnostics (estimates, not native acceptance): front has zero seam-hole
  frames and 53 detached-speck frames; rear has 73 hole frames, including move
  frames 6 and 26. Both inspect 362 presented frames and retain current bindings.
- Sampler: 1008 poses; native probe load, registration audit, sidecars and all
  three SFX sync programs pass. Godot also emits resource teardown warnings;
  the complete logs are retained. No windowed/native acceptance is claimed.

### Proof for the design owner

Run this exact sequence at 1920×1080 and 100% UI scale after resolving the
TODO_DESIGN decisions. The wrapper invokes the required task/visual runners
and proof contracts. Native failure crops now go to ignored `proof/logs/`.
Existing director native rests are retained as previews; changed part hashes
correctly require fresh native density certification.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-20 && sh experiments/cutouts/hollow_mimic/proof.sh density
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-20 && sh experiments/cutouts/hollow_mimic/proof.sh rest
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-20 && sh experiments/cutouts/hollow_mimic/proof.sh native
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-20 && sh experiments/cutouts/hollow_mimic/proof.sh sheets
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-20 && sh experiments/cutouts/hollow_mimic/proof.sh idle
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-20 && sh experiments/cutouts/hollow_mimic/proof.sh production
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-20 && sh experiments/cutouts/hollow_mimic/proof.sh review
```

Capture locations: `rr20/proof/native_rest/`, `native/` (including transported
feature masks), `contact_sheets/`, `idle_native/`, `production_native/`, and
`hollow_mimic_review.mp4`. All captures, CPU crops and full logs are gitignored.

Small shared extensions in this round are limited to a sampler report-writer
hook, hashed full-evidence loading, an optional supplied sample report for
native gates, and pruning the ignored proof tree before binding traversal.
No shared game runtime code was changed.

## Original brief retained

Each view retains rigid head/hair/mask, torso, pelvis, gloves and boots, with
four skinned two-bone limbs. The front violet crack belongs to the head.
Source ownership reconstructs both approved paintings with 0 px mismatch;
feedback 1 cleans only two front and one rear chroma-key residue texels in
derived presentation. Protected paintings, maquette and motion stay unchanged.

The upper body and both free arms use the specified rigid idle bob; the lower
body is still. Board, pre-battle and live portraits share the adapter. Shade
Bolt selects `bolt`; the en06 copy marker selects `mirror` regardless of copied
attack kind; every movement tile selects `move`; Recede then selects `block`.
Existing effects, cues, hit/death and the subsequent fade remain integrated.
The director-accepted death clamp remains a maximum 1 px presented boot shift.
