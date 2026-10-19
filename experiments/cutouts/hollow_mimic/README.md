# rr-20 — Hollow Mimic humanoid v2

Feedback 3 is implemented on `codex/rr-20`, based on the director's merge
`c00205b71`. Changes remain uncommitted. The director owns commit, review,
inspection and publication. No windowed run or full project suite was attempted.

## Feedback 3 acceptance

1. Protected director motion is imported byte for byte in the case and
   production. Only the director's gait lift changed (5 → 7 px); the
   motion-only compiler proves all non-move tracks unchanged. Both shared walk
   gates pass, six swings per view. The maximum extra fit is 0.852 px front
   and 0.491 px rear; maximum total pelvis drop is 2 px in each view.
2. The front hair texels `(105,48)` and `(105,49)` remain owned by `head`.
   The shared detached-component classifier recognizes only components already
   separate in the approved rest. It requires exact source colours/texels,
   the rigid owner's independently sampled transform and actual visible owner.
   Novel, misplaced, stretched or misowned components still fail. Source art
   and all presentation paint remain byte-identical to this round's baseline.
3. The shared native gate classifies every enclosed pocket through the
   immutable paint/tuck check textures, transported by the same GPU geometry
   as the paint. This is the inverse-pose source query for rigid and skinned
   pieces; it does not substitute a CPU skin/raster oracle for native pixels.
   Every pixel is checked against every piece, including owners absent from
   the boundary. One pixel mapping into paint/tuck fails. Only all-air pockets
   pass, and every passed pocket has bounds. No new frame exception, motion
   change or paint extension was needed. The gait fill proposal stays
   **inactive**; its old 26 torso texels would change both rear move endpoints
   by 20 alpha pixels. Existing own-piece continuations from round 2 remain.
4. Current headless gates and focused tests pass in both views. All 16,732
   passed pockets across the four humanoid cases are individually listed in
   [the ignored pocket index](rr20/proof/logs/feedback3_passed_pockets.md).
   Full per-frame records stay ignored; tracked records retain summaries,
   extrema, failures and hashed links. Native acceptance is explicitly pending
   fresh director captures, rather than borrowing stale windowed evidence.

### Every swing's measured apex

Angles are degrees, from fresh presented Bone2D samples. Frame numbers are
zero-based. No tuning was chosen.

| View | Leg | Apex frame | Swing bend | Stance bend |
|---|---|---:|---:|---:|
| Front | near | 2 | 60.732 | 31.239 |
| Front | far | 9 | 69.624 | 35.749 |
| Front | near | 19 | 61.821 | 28.657 |
| Front | far | 28 | 76.049 | 32.647 |
| Front | near | 38 | 58.224 | 31.320 |
| Front | far | 45 | 72.697 | 23.720 |
| Rear | near | 2 | 92.144 | 22.588 |
| Rear | far | 9 | 58.723 | 57.913 |
| Rear | near | 19 | 87.862 | 23.344 |
| Rear | far | 28 | 58.054 | 53.591 |
| Rear | near | 38 | 78.963 | 21.574 |
| Rear | far | 45 | 52.765 | 40.158 |

### Shared-rule verdicts

These are all-frame CPU estimates, not native acceptance. Counts include
one-pixel air pockets. Every bound is in the linked index and full JSON logs.

| Rig | Frames front / rear | Air pockets front / rear | Verdict |
|---|---:|---:|---|
| Hollow Mimic | 362 / 362 | 1996 / 2655 | PASS / PASS |
| Seer | 467 / 467 | 3232 / 4589 | PASS / PASS |
| Thrall | 335 / 335 | 988 / 922 | PASS / PASS |
| Mirror | 344 / 344 | 374 / 1976 | PASS / PASS |

Mimic passes 355 presented detached-head components by exact source provenance.
Seer retains four existing director-approved robe-tip exception frames: front
move 11, 12, 15 and rear move 10. No exception file was changed. Thrall, Mirror
and Mimic require none for this census. Capacitor retains its separate rigid
pixel gate; its 696 presented frames and integration/production tests pass in
the focused reference set. All four reference rigs' case/asset bytes are
unchanged.

### Observed focused results

Exact commands, result lines, file inventory and evidence hashes are recorded
in [verification.json](rr20/proof/verification.json). Logs are under
`rr20/proof/logs/`.

- Unit, residue, gait/continuation, generic air/source mutations and production:
  `Ran 40 tests in 136.972s`; `OK`.
- Focused gait/Seer/Thrall/Mirror/Capacitor regression sets:
  `Ran 183 tests in 308.560s`; `OK`.
- `RR20 SOURCE/BONE/DIRECTION/KNEE/SUPPORT/REACH GATES: PASS (0 errors; both views)`.
- `RR20 CPU FRONT: PASS (362 frames; 0 failing frames)`;
  `RR20 CPU REAR: PASS (362 frames; 0 failing frames)`.
- `RR20 PRODUCTION LOGIC: PASS (6 scenarios; 7896 frames; 0 errors)`.
  Shade Bolt, all three copied attack kinds, movement per tile, block, hit,
  death, effects, cues and outcomes are checked through actual playback.
- `RR20 COMPACT SAMPLES: PASS (28 inventories; full transforms in ignored logs)`;
  `RR10 BONE SAMPLES: PASS (1008 poses; headless transforms only)`.
- `RR20 NATIVE PROBE LOAD: PASS`.
- `RR20 SHADOW RECORDS: PASS (2 v2 views; every other unit retained)`.
  Refresh is idempotent on the director's current cache; no cache bytes differ.
- `SFX SYNC HARNESS RESULT: PASS (4075 observations, 0 failures)`;
  `(3348 observations, 0 failures)`; `(1604 observations, 0 failures)`.
- `TEST REGISTRATION AUDIT: PASS (751 scripts; full suite=407, quarantined=29, windowed probe=315)`.
  These are registration classifications; the full suite was not executed.
- Protected-input, prior-rig byte, proof-ignore and sidecar audits pass.
  Inherited tests use the rr-20 wrapper, including their nested Godot calls.

The first concurrent verification batch rejected evidence while the shared
classifier was being finalized. The final batch above resampled after the
code stabilized and passes with current hashes. Earlier logs remain ignored.
Godot's existing certificate/resource teardown and image-load warnings remain
in the complete logs; no script/test failure is concealed.

### TODO_DESIGN placeholders

None. Feedback 3 resolves all three previous fields; they are cleared in the
case, cutout and production integration metadata. Protected staged data and
approved paintings remain untouched.

### Chosen defaults

No player-visible value was chosen. New values are test fixtures only:
`FIXTURE_SIZE_PX=32`, `FIXTURE_COLOR=[70,60,90,255]`, `FIXTURE_SHIFT_PX=4`,
`FIXTURE_TURN_RADIANS=0.3` in `tests/test_rr20_rest_space.py`. The cross-rig
census reuses `PROGRESS_INTERVAL_FRAMES=100` for logging. Existing construction
and proof defaults remain: `PROOF_UV_MARGIN_PX=1`,
`RASTER_COVERAGE_MARGIN_PX=1`, `MAX_CONSTRUCTION_PASSES=16`, `FIXTURE_VALUE=5`.
Diagnostic commands use `OPENBLAS_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1`.
The director's residue thresholds and the spec's tuck/gate values are unchanged.

### Proof for the design owner

Run this exact sequence at 1920×1080 and 100% UI scale. The wrapper invokes
the required task/visual runners and proof contracts. No inspection-fixture
command is required by this brief; fixture preparation belongs to the director.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-20 && sh experiments/cutouts/hollow_mimic/proof.sh density
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-20 && sh experiments/cutouts/hollow_mimic/proof.sh rest
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-20 && sh experiments/cutouts/hollow_mimic/proof.sh native
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-20 && sh experiments/cutouts/hollow_mimic/proof.sh sheets
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-20 && sh experiments/cutouts/hollow_mimic/proof.sh idle
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-20 && sh experiments/cutouts/hollow_mimic/proof.sh production
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-20 && sh experiments/cutouts/hollow_mimic/proof.sh review
```

Capture paths: `rr20/proof/native_rest/`, `native/` (including transported
feature masks), `contact_sheets/`, `idle_native/`, `production_native/`, and
`hollow_mimic_review.mp4`. All captures and full logs are gitignored.

Open proof limits: density `--check --only hollow_mimic_cutout` exits 1 solely
for the two already-pending native rest rebakes. Both native density rests and
the full native chain need the director's window server. Old native captures
are stale; `native_gates.json` records pending, not a renderer pass. The
accepted death boot clamp still shifts at most 1 px in each view; motion is
unchanged. Dense reach still reports overreach without failing: 7 front and
6 rear reports across 14 paths per view and 1000 phase intervals.

### Changed file ownership

Unit changes are in `experiments/cutouts/hollow_mimic/`,
`assets/units/hollow_mimic_cutout/` and `tests/test_rr20*` plus
`tests/rr20_regression_runner.py`. The complete concrete path list is in
`verification.json`. The only shared changes this round are
`tools/humanoid_cutout/rest_space.py` and its native-gate integration in
`tools/humanoid_cutout/gates.py`. No shared game runtime code changed.

## Original brief retained

Each view retains rigid head/hair/mask, torso, pelvis, gloves and boots, with
four skinned two-bone limbs. The front violet crack belongs to the head.
Source ownership reconstructs both approved paintings with 0 px mismatch;
feedback 1 cleans only two front and one rear chroma-key residue texels in
derived presentation. Protected paintings and maquette stay unchanged.

The upper body and both free arms use the specified rigid idle bob; the lower
body is still. Board, pre-battle and live portraits share the adapter. Shade
Bolt selects `bolt`; the en06 copy marker selects `mirror` regardless of copied
attack kind; every movement tile selects `move`; Recede then selects `block`.
Existing effects, cues, hit/death and the subsequent fade remain integrated.
