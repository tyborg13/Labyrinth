# rr-18 — Glacial Mirror humanoid v2

Current handoff: [director feedback 2](rr18/feedback2.md). The approved rigid-air calibration is implemented and all design placeholders are resolved. **Acceptance remains incomplete:** the final strict scan retains 13 rear-frame failures containing 14 pocket occurrences, each mapping one pixel into an existing continuation. Every remaining failure has an inspected, ignored CPU crop linked from the handoff. No frame exceptions, art changes or motion tuning were added.

## Numbered unit requirements

1. Fifteen rigid boulders per view retain the specified source labels/bones, two-bone hand/foot targets, minimum tucks, facing knee policy, stride/trailing roles and torso-owned front mirror. Source rest remains **0 px** against both approved paintings. All **313 Mirror PNGs** remain byte-identical in this feedback pass.
2. The existing upper-body idle, stationary pelvis/legs/feet and three proof groups remain unchanged. Headless idle rigidity passes; native proof is pending.
3. Existing board, pre-battle, portrait, per-tile move, Refraction, guard, hit/death/fade integration remains unchanged. Production callbacks pass **940 frames in each view**; the three SFX harnesses pass with zero failures. Density rest remains **0 px** against the processed output: front clean / rear regrid 1.22. No density override.
4. The Mirror opts into a generic, data-driven rigid-air seam policy in case anatomy. The shared proof-only extensions are `tools/humanoid_cutout/{rigid_air.py,anatomy.schema.json,gates.py}`. Other figures retain the strict default; no generic creature-name or runtime-rendering branch was added. Seer/Thrall paint/layouts/compiled motion remain unchanged, with 990 exact Thrall and 1,258 exact Seer pose rows retained.
5. Source/cut, idle/signed motion, direction/coverage, every stride swing, support, dense reach and production-rest checks pass in both views. The scan covers **682 presented frames**; front seams pass, rear seams retain **13 errors**. A synthetic punched stone hole, missing tuck, single-pixel hole and torso hole all fail; air passes. No remaining failure was waived. Native rigid/sprite/idle/seam proof is wired to the same policy and awaits the director's renderer.

## Proof and reproduction

The final focused rr-10/11/14/15/16, rr-07 production, audit and rr-18 set reports `Ran 198 tests in 168.006s`, `OK`. All eight mutations are caught. Registration reports `TEST REGISTRATION AUDIT: PASS (750 scripts; full suite=406, quarantined=29, windowed probe=315)`. SFX harnesses pass 4075 / 3348 / 1604 observations with zero failures. Full suites are not run, per the brief/director.

[Current handoff](rr18/feedback2.md) contains every remaining crop, exact headless commands, chosen defaults and open issues. [Verification](rr18/proof/verification.json) contains exact result lines, logs and hashes. [Feedback 1](rr18/feedback1.md) is historical; its calibration TODO is resolved by feedback 2.

## Proof for the design owner

No windowed command was attempted. Run in this order at **1920×1080 / 100% UI scale**:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-18 && sh experiments/cutouts/glacial_mirror/rr18_proof.sh density
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-18 && sh experiments/cutouts/glacial_mirror/rr18_proof.sh rest
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-18 && sh experiments/cutouts/glacial_mirror/rr18_proof.sh native
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-18 && sh experiments/cutouts/glacial_mirror/rr18_proof.sh sheets
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-18 && sh experiments/cutouts/glacial_mirror/rr18_proof.sh idle
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-18 && sh experiments/cutouts/glacial_mirror/rr18_proof.sh production
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-18 && sh experiments/cutouts/glacial_mirror/rr18_proof.sh review
```

Captures stay gitignored under `rr18/proof/{native_rest,native,contact_sheets,idle_native,production_native}` and `*.mp4`; current CPU-only failure crops are under `rr18/proof/seam_cpu`. The `native` gate retains the reported failures. Native rest sealing and inspection are pending. No fixture command is requested; the director prepares the fixture.

## Changes, defaults and remaining work

This pass changes only case policy/placeholder metadata, shared opt-in proof helpers/schema, Mirror seam reports/crops, tests/mutations and this handoff. No paint, motion, runtime-renderer, density, shadow, input, analytics, save or combat value changes. Three small generic extensions are listed/tested; all other protected content passes the 3,616-file audit.

No TODO_DESIGN remains. New defaults are diagnostic crop padding (8 px), inherited 3× crop zoom and named synthetic test fixtures; no player-facing value was selected. Remaining work is the 13 reported rear-frame continuation failures and director-native proof. Changes remain uncommitted and unstaged; no peer review or publication was performed.
