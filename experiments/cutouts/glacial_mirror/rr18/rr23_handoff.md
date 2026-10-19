# rr-23 implementation handoff

The approved mq8b repaint is installed in the editable Mirror case and production
closure. Changes remain uncommitted. No peer review, publication or windowed run
was performed; those steps belong to the design owner.

## Numbered requirements

1. Both views were recut from the protected mq8b jobs. Fifteen rigid pieces per
   view retain their own painted pixels and non-green own-edge continuations.
   Raw authoring rest identity is **0 px against each protected painting**.
   The separate prescribed cleanup/continuation stage changes 7 front / 32 rear
   reference pixels (1 front / 6 rear green replacements included). Its own
   source-space rest and density-processed production rest comparisons are 0 px.
   No painting, maquette delivery or motion input was modified.
2. The two repainted heels use traced ankle overlaps in
   [rr23_registration.json](rr23_registration.json). Other terminals retain the
   supplied pivots. All feet overlap their shins at rest. Exact rigid pixel-square
   separation is **0.000000 px maximum ankle air in front and rear**, across all
   **344 presented frames per view**, covering every clip, including death.
3. Front `fore_near` / `fist_near` draw at 15 / 16 above torso 13 and head 14 in
   every clip. The order change alters **0 rest pixels**; a failing order change
   raises `TODO_DESIGN_near_arm_order` before promotion. At guard contact frame 24,
   the near fist overlaps 944 diagnostic ice-mask pixels. Rear depths remain as
   cut: fists 2 / 10 behind torso 11. Native contact crops remain director proof.
4. The shoulder line remains the supplied maquette line, checked against the
   specified front perspective tolerance. Painted fist width × height, source px:

   | View | Near | Far |
   |---|---:|---:|
   | Front | 48 × 53 | 41 × 36 |
   | Rear | 48 × 46 | 44 × 43 |

5. Preservation now compares with pinned integration commit
   `521fa8f204f6f3b5d0aca1d09ec2494107c155d9`, including committed, staged,
   unstaged and untracked protected paths. The explicit director-motion allowlist
   accepts only exact approved SHA-256 bytes. A disposable repository commits a
   protected mutation and proves it is caught even with an empty bare `git diff`.
6. Both density-processed expected rests and the two Mirror shadow records were
   rebuilt. Both Mirror headless gate sets and gait gates pass. Front maximum
   pelvis fit / total drop: 2.716829 / 4.715247 px; rear: 0.158067 / 3.500000 px.
   Director and compiled motion files remain byte-identical to the pinned base.
   Native rest rebake, density record sealing and renderer inspection remain
   pending; no headless snapshot is represented as native proof.

## Proof for the design owner

Run in order at 1920×1080, 100% UI scale. `density` performs the native rebake,
records the rests, refreshes the two shadows, checks density and seals integration.
`contacts` derives six validated 1920×1080 sheets from the fresh native capture:
front/rear guard contact, and two ankle sheets per view covering every clip.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-23 && sh experiments/cutouts/glacial_mirror/rr18_proof.sh density
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-23 && sh experiments/cutouts/glacial_mirror/rr18_proof.sh rest
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-23 && sh experiments/cutouts/glacial_mirror/rr18_proof.sh native
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-23 && sh experiments/cutouts/glacial_mirror/rr18_proof.sh sheets
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-23 && sh experiments/cutouts/glacial_mirror/rr18_proof.sh idle
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-23 && sh experiments/cutouts/glacial_mirror/rr18_proof.sh production
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-23 && sh experiments/cutouts/glacial_mirror/rr18_proof.sh review
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-23 && sh experiments/cutouts/glacial_mirror/rr18_proof.sh contacts
```

Captures stay gitignored in `proof/{native_rest,native,contact_sheets,idle_native,
production_native,rr23_native_crops}` and `proof/*.mp4`. The crop contract is
[rr23_crops_contract.json](rr23_crops_contract.json). No inspection-fixture command
was requested; the design owner prepares the fixture. CPU guard crops under
`proof/rr23_cpu_{front,rear}_guard.png` were inspected only as headless diagnostics.

## Chosen defaults

All new choices are diagnostic: ice-mask chroma margin 24; relative-transform
cache precision 6 decimals; crop labels 36 px; at most 3× nearest-neighbour zoom,
8 px context and RGB (30,30,36) background (matching existing proof). Test-only
disconnection is 100 px and its synthetic rest pixel is RGBA (80,90,110,255).
Ankle sheets use three columns and nine cells each, sampled at start,
contact (midpoint for clips without a contact), and end.
The baseline pin is the worktree's starting integration HEAD. Traced ankle
coordinates are measurements of approved paint, not animation tuning.

## Open issues

- No unresolved `TODO_DESIGN` placeholder remains. The near-arm-order sentinel
  is a tested failure path and was not triggered on the approved repaint.
- The unchanged Capacitor feedback shadow test compares *all* records to HEAD
  and rejects the authorized Mirror refresh. The Mirror-owned pinned audit
  verifies preservation with only the two authorized Mirror records changing.
- The unchanged gait-01 preservation test forbids every changed PNG in the
  working tree, so it rejects this approved repaint. Its mechanical walk gates
  still pass; rr-23 independently pins all four Mirror motion files and protects
  every other figure's sources and shared records.
- `process_board_density.py --check --only glacial_mirror_cutout` correctly
  reports both rests need a native rebake. Run `density` above before sealing.
- Full suites were excluded by the unit brief. Windowed proof was not attempted.

Exact observed test lines and log digests are recorded in `proof/verification.json`.

Observed final result lines:

```text
RR18 ALL GATES: PASS (0 unique errors)
RR23 FRONT MAXIMUM ANKLE AIR: 0.000000 px
RR23 REAR MAXIMUM ANKLE AIR: 0.000000 px
RR23 PRODUCTION FRONT: PASS (949 frames; 0 errors)
RR23 PRODUCTION REAR: PASS (949 frames; 0 errors)
RR23 FRESH BONE EVIDENCE: PASS
Ran 267 tests in 411.678s
FAILED (failures=2)
Ran 8 tests in 22.074s
OK
Ran 4 tests in 13.690s
OK
Ran 111 tests in 49.928s
OK
Ran 19 tests in 2.144s
OK
SFX SYNC HARNESS RESULT: PASS (4075 observations, 0 failures)
SFX SYNC HARNESS RESULT: PASS (3348 observations, 0 failures)
SFX SYNC HARNESS RESULT: PASS (1604 observations, 0 failures)
TEST REGISTRATION AUDIT: PASS (751 scripts; full suite=407, quarantined=29, windowed probe=315)
RR23 CROP PROBE LOAD: PASS (native-only input, 1920x1080 output)
```

All ten rr-18 mutations and all four rr-23 mutations printed `CAUGHT`.
The two failures in the 267-test run are the unchanged scope checks described
above; no assertion was weakened. Full suites and windowed probes were omitted
as directed by the unit brief.
