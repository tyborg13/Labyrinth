# rr-13 feedback 3 — final continuation round

**Partial result: 8/12 director pinholes closed; four waist holes remain.**
Stopped for the director's decision. Changes remain uncommitted. No exceptions,
gate calibration, motion, paintings, runtime, other creatures or feedback-2 test
assertions changed. No windowed run, review, commit or publication was performed.

## Source changes and limits

- Front staff shoulder: 37 new hidden torso texels close mark 18/22/48/49.
- Rear near armpit: 31 new hidden torso texels close mark 20/21/22.
- Front top edge: 26 new near-sleeve continuation texels under head/torso close
  death 68. This uses the adjoining shoulder surface: the torso's inverse texels
  at that pose are outside rest alpha, while the sleeve's covered texels exist.
- The new source points are measured from the director's 512-canvas holes and
  stored in `joint_continuations.json`. The expansion reuses the existing 3 px
  minimum tuck. Source additions are clipped to named covers and connected
  material; garment patches retain their original bounds/grid/weight fields.
- Both rest composites remain exactly 0 px different. Every original opaque
  RGBA texel and all 1,258 bone/part pose records are unchanged. No deformation
  field changed. The new regression removes just the added fill and reopens
  each of the eight repaired seams.

## Unclosed waist holes

| View | Clip | Frame | Canvas pixels | Count |
| --- | --- | ---: | --- | ---: |
| front | death | 27 | (244,272), (245,272) | 2 |
| front | death | 28 | (244,272), (245,272) | 2 |
| front | death | 29 | (244,273), (245,273) | 2 |
| front | death | 30 | (244,273), (245,273) | 2 |

The sampled robe field maps those holes to source (117,144)/(118,144), both
transparent in the approved painting. The rigid torso maps them to
(115,145 or 146)/(116,145 or 146), also transparent. The covered robe-top
extension was implemented, but has no eligible covered texels at these exact
samples. I could not close these four with the existing deformation fields
while retaining 0 px rest identity. I did not paint those transparent source
positions or change skin weights to force a pass. Full per-pixel traces are in
[the CPU report](proof/rr13_feedback3_cpu.json).

## CPU proof and fixtures

`cpu_pose.py` is the CPU diagnostic explicitly authorized for this round. It
poses the actual triangles from snapped Bone2D evidence, uses the existing
fixed-subpixel raster convention, and retains opaque fragments when a later
folded triangle samples transparency. It is not a native GPU oracle.
`rr13_cpu_proof.py` runs the unchanged posed-owner, joint-hole and material
logic on every frame, with the unchanged case exception list.

Observed full scan:

- `RR13 CPU FRONT: FAIL (467 frames; 4 unapproved joint-hole frames; 0 material failures)`.
- `RR13 CPU REAR: PASS (467 frames; 0 unapproved joint-hole frames; 0 material failures)`.

All 934 frames were scanned. There are no other unapproved CPU hole frames.
The director's GPU captures remain stale; none were recaptured or rebound.

The fixture regeneration tool preserves the historical GPU owner body and
adds only CPU-posed texels newly introduced by the fixed source fills.
Historical seam/rest-hole/reference masks and negative-regression tuck masks
remain unchanged. The original body is retained as `*_historical.png`, with
its original hash. This avoids replacing native sampling with a different CPU
whole-body raster or manually painting holes closed. All existing assertions
are unchanged. The two positive historical tests still return [2] and fail;
their required pass is not claimed:

- `test_captured_shoulder_and_belt_openings_close_and_regression_reopens`.
- `test_new_rigid_tucks_close_the_captured_wrist_and_foot_openings` (death 30).

## Observed focused checks

- rr10: `Ran 63 tests in 52.692s` / `FAILED (failures=2)`, the two above.
- New continuation regressions: `Ran 2 tests in 2.301s` / `OK`.
- `test_rr07_production`: `Ran 5 tests in 72.031s` / `OK`.
- `test_maquette_rear_turn`: `Ran 18 tests in 15.078s` / `OK`.
- `RR10 RUNTIME: PASS (10 checks; headless logic only)`.
- `RR07 RUNTIME: PASS (73057 checks, 0 failures; headless logic only)`.
- `RR10 BONE SAMPLES: PASS (1258 poses; headless transforms only)`.
- `RR10 BONE/CUT GATES: PASS (0 errors)`.
- Build: front/rear `PASS (rest mismatch: 0 px; 3 joint_meshes; protected tracks byte-identical)`;
  `RR10 TUCK COVERAGE: 0 missing source pixels (both views; see proof/build.json)`.
- Original opaque texels, pose records, garment field hashes and feedback-2
  gate/test file bytes were checked unchanged. `git diff --check`: exit 0.
- Full Godot/Python suites were not run.

All round-3 scratch output is under `/private/tmp/labyrinth_codex/rr-13/`:
`f3-*.log`, `cpu-final/{front,rear}/report.json`, `waist_source_trace.json` and
`cpu-final/front/front_death_0027.png` through `front_death_0030.png`.
These PNGs are CPU diagnostic frames, not renderer captures. No scratch capture
was added to Git; the existing proof ignore policy remains unchanged.

## Files changed this round

- `joint_continuations.json`, `rr10_build.py`, `joint_continuations.py`:
  source continuation recipes and masks; regenerated torso/near-sleeve paint,
  checks, tucks, layout hashes and source records.
- Three Seer production surfaces, their untouched density sources/output records
  and integration record. Layout copies retain parity and unchanged geometry.
  Density paint was reprocessed.
  Native rests were retained, and their four stale part fingerprints remain
  honestly pending director rebake.
- `cpu_pose.py`, `rr13_cpu_proof.py`, `rr13_seam_fixtures.py` and
  `test_rr13_continuations.py`; immutable before-alpha/geometry test fixtures.
- Historical feedback-4/5 fixture owner data/provenance, updated only from
  actual new source fills; original native owner snapshots retained.
- `proof/samples.json`, build and CPU reports, README and this handoff.

Chosen defaults: CPU progress logging every 50 frames, as
`PROGRESS_INTERVAL_FRAMES`; all raster/canvas/tuck values reuse existing
contracts. Test poses and source points come from director-observed defects.
No new player-facing value, art, design TODO or gate exception was invented.
The four waist holes and two historical assertion failures remain open.

## Proof for the director

Changed hidden assets invalidate density rest fingerprints; rebake first:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-13 && sh experiments/cutouts/hoarfrost_seer/rr10_proof.sh density
```

Exact requested windowed proof commands, all unrun here:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-13 && sh experiments/cutouts/hoarfrost_seer/rr10_proof.sh native
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-13 && sh experiments/cutouts/hoarfrost_seer/rr10_proof.sh sheets
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-13 && sh experiments/cutouts/hoarfrost_seer/rr10_proof.sh review
```

The existing script uses the required visual runner and 1920x1080/100% contracts.
`sheets` and `review` continue to refuse failed or stale native proof.
