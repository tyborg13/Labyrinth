# rr-18 — Glacial Mirror humanoid v2

Current handoff: [director feedback 3](rr18/feedback3.md). **All headless gates pass in both views.** The 13 rear continuation failures (14 pockets) are repaired; every original material-hit pixel is covered for all native UV candidates. All 682 presented frames have zero pockets, green-dominant texels and clean-piece defects. No exemptions or motion changes.

## Numbered unit requirements

1. Fifteen rigid boulders per view retain the specified labels/bones, two-bone targets, knee policy, stride/trailing roles and front torso-owned mirror. The immutable raw authoring partition remains **0 px against both protected paintings**.
2. Idle groups/motion remain unchanged and pass rigid/signed checks. Pelvis, legs and feet remain stationary.
3. Board, pre-battle, portraits, advance, Refraction, guard and hit/death/fade integration remains unchanged. Production logic passes **940 frames per view**; three SFX harnesses pass with zero failures. Production rest is **0 px** against the existing density rule's output.
4. Case-owned material data specifies rounded own-edge continuation and exact zero-green cleanup; generic proof helpers are optional and contain no creature-name branches. Seer/Thrall render inputs and pose rows remain unchanged. No shared humanoid runtime changed.
5. Every headless gate passes, including source/material provenance, raw identity, green, pockets/strays, action direction/coverage, knees/supports and dense reach. All ten mutations are caught. Fresh native proof remains director-owned.

## Source stages and proof

Raw authoring stays exact in `rr18/raw_cut/`; original paintings are unchanged. The prescribed presentation cleanup changes **1 front / 28 rear reference pixels** (three green replacements and 26 rear coverage pixels), using only existing same-boulder texels. It has its own exact derived references, then uses front clean / rear regrid 1.22 without a density override. This preserves raw identity while making every presented frame clean. See [handoff](rr18/feedback3.md), [green corrections](rr18/proof/green_sources.json) and [raw identity](rr18/proof/raw_identity.json).

Observed: `RR18 ALL GATES: PASS (0 unique errors)`; `Ran 208 tests in 161.968s`, `OK`; all ten mutations caught; art identity 111 tests, icon identity 7, sidecars 19 all OK; registration audit PASS (750 scripts). Exact result lines/log hashes: [verification](rr18/proof/verification.json). No full suites or windowed runs were attempted.

## Proof for the design owner

Fresh **1920×1080 / 100% UI scale** proof is required after these texture changes. Run in order:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-18 && sh experiments/cutouts/glacial_mirror/rr18_proof.sh density
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-18 && sh experiments/cutouts/glacial_mirror/rr18_proof.sh rest
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-18 && sh experiments/cutouts/glacial_mirror/rr18_proof.sh native
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-18 && sh experiments/cutouts/glacial_mirror/rr18_proof.sh sheets
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-18 && sh experiments/cutouts/glacial_mirror/rr18_proof.sh idle
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-18 && sh experiments/cutouts/glacial_mirror/rr18_proof.sh production
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-18 && sh experiments/cutouts/glacial_mirror/rr18_proof.sh review
```

Captures stay ignored under `rr18/proof/{native_rest,native,contact_sheets,idle_native,production_native}` and `*.mp4`. Repaired CPU crops/index are in ignored `rr18/proof/feedback3_repaired/`; they are not GPU proof. No fixture command is requested; the director prepares the fixture.

## Defaults and remaining work

No TODO_DESIGN remains. Only named debug fixtures were chosen. Existing 8 px crop context / 3× zoom and proof cameras/timeouts remain; material growth/quad padding use the existing 3 px tuck depth and the prescribed green margin is 12. Fresh native sealing and inspection are the remaining steps. All changes remain uncommitted and unstaged; no peer review or publication was performed. Earlier feedback handoffs are historical.
