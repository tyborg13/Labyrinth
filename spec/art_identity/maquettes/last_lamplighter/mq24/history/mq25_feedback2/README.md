# mq-25 feedback 1 — top-bar allowance implemented; column scope needs resolution

The director's 8 px top-bar allowance and per-column hand boundary are
implemented. The current top bar is **6 px above** the native silhouette and
passes; the **12 px** regression fails. The previous global-bottom rule is
removed. Geometry, painting, prompts and existing sidecars are unchanged.

The literal lower-grip-ring/held-chain union still fails the newly required
**every occupied column** condition. No accepted seal was issued, and the
existing delivery was not replaced. `accepted` remains **false**.

## The remaining native-image result

All three prior front checks now pass: top bar within 8 px, lower-ring pixels
below their local hand edge, and chain pixels below their local hand edge.
The new universal column check finds **14 of 19** occupied front columns
qualify; the other five are:

| Column x | Lowest hand y | Lowest visible lower-ring/chain y |
|---:|---:|---:|
| 722 | 609 | 601 |
| 723 | 611 | 602 |
| 724 | 611 | 602 |
| 725 | 612 | 603 |
| 726 | 612 | 603 |

The chain does not occupy these five columns. Rear observations remain
explicit diagnostics and are not additional front acceptance requirements.

Counting the existing **`lantern_cap_ring`** in the ring/chain union would
make **30 of 30 columns qualify in both views**. That is recorded as an
**unselected measurement variant**, not silently adopted as the meaning of
the grip ring's lower half. The director was asked whether it belongs in the
union. `TODO_DESIGN_ring_chain_scope` records that pending scope decision in
`feedback1_validation/design_pending.json`. The earlier
`TODO_DESIGN_below_fist_definition` is resolved to **per column**.

Complete native pixel/column observations are in
`feedback1_validation/mq24_acceptance.json` and
`feedback1_validation/hardware_scope_options.json`.

## Implementation and requirement status

1. **8 px top bar:** `contract.json` pins 8 px at 1088 px. Exact native alpha
   inclusion or the permitted vertical peek is measured at the unchanged
   ring-top projection. The 6 px/12 px regression passes.
2. **Per-column lower boundary:** every occupied visible lower-grip-ring /
   held-chain column is reported and tested against its own lowest native
   hand pixel. A fixture proves a short column can qualify above the global
   hand bottom, and that one failing column rejects the universal condition.
3. **Accepted delivery and both verifies:** blocked by the five columns.
   mq-20 verify passes. mq24 verify correctly rejects the remaining check.
   `staging.py` and `proof stage` are implemented; failed verification is
   tested to leave the old delivery untouched. Successful staging archives
   the old delivery, promotes both verified proof chains, preserves existing
   import settings at their original resource paths, then verifies again.
4. **Geometry, prompts, history and sidecars:** all 57 source/native mesh
   hashes and all 247 protected input byte hashes remain unchanged. History
   tests retain their reviewed-commit pins. Sidecars were left in place;
   their real tracked guard now passes. No full suite was rerun.

## Native proof and observed focused results

A fresh bridge cold/cache-replay/independent-cold proof and exact float32
comparison pass. A fresh opened-native mq24 audit also passes and catches
all six mutations. Native PNGs from round 0 are revalidated against the
identical compiled specification and these fresh native geometry proofs;
no bitmap, shape, pose or renderer value changed.

```text
FITTED_RECIPE_PROOF: PASS; raw_hashes_identical=true; max_joint_error=1.8373953533280221e-06
EXACT_NATIVE_REPLAY: PASS; unrounded_float32=true; mesh_count=57
MQ24_NATIVE_AUDIT: PASS; caught=6; survived=0
MQ20_HASH_BOUND_DELIVERY: PASS
```

Focused final results:

- mq24: `Ran 48 tests in 28.591s`; `FAILED (failures=1)` — only the unchanged
  native-delivery acceptance assertion, now solely the five column failures.
- Delivery and tracked sidecars: `Ran 30 tests in 9.254s`; `OK`.
- Art identity: `Ran 111 tests in 86.519s`; `OK`.
- Resource declaration audit: `ISOLATION AUDIT: 236 modules`; exit 0.
- mq24 verify: `ValueError: mq-24 acceptance failed`; exit 1.

The new top-bar, per-column and failed-proof staging regressions pass within
the mq24 run. Raw logs, geometry readback and mutation/segment tables are in
`feedback1_validation/`. Exact commands and outcomes are recorded in
`verification_results.json`. Round-0 narrative and outcomes were preserved
under `history/mq25_round0/`; its older full-suite timeout is historical.
The complete 57-piece hash list remains
`ratification_validation/geometry_sha256.md`.

## Chosen defaults and protected files

No new player-visible value was chosen. New invisible test controls are named
in `tests/test_mq24_maquette.py:FIXTURE_DEFAULTS`: a 20×4 boolean column
fixture, its hand spans and hardware coordinates, a [0, 0, 1] displacement,
and an invalid all-zero SHA-256. Native alpha threshold 128 and containing-
pixel projection are inherited. The staging backup path is explicitly named
`history/feedback1_delivery_before_acceptance.tar.gz`; no archive or delivery
replacement is created before verified acceptance. The 8 px value and
per-column rule come directly from the director.

Provided geometry inputs, both paint-job trees' existing files and the
admitted prompt bytes were not rewritten. All edits are uncommitted. No
preflight, task-queue edit, Git write, commit, reviewer agent or sign-off was
run. Full suites are assigned to the director at merge.

## Proof for the design owner

Current candidate: `proof/mq25-feedback1-native/capture/`.
Fresh native model: `proof/mq25-feedback1-cold/determinism/cold/maquette.blend`.
The same inspected native images are retained in
`ratification_validation/native_delivery/`; this feedback changes only gates.

After the ring/chain scope is resolved, use fresh directories for accepted
native proof and copied-source regeneration, then promote only after verify:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-25 && python3 -B -m spec.art_identity.maquettes.last_lamplighter.mq24.proof prove --out spec/art_identity/maquettes/last_lamplighter/mq24/proof/director-feedback1-native
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-25 && python3 -B -m spec.art_identity.maquettes.last_lamplighter.mq24.proof regenerate --out spec/art_identity/maquettes/last_lamplighter/mq24/proof/director-feedback1-regeneration --capture spec/art_identity/maquettes/last_lamplighter/mq24/proof/director-feedback1-native/capture
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-25 && python3 -B -m spec.art_identity.maquettes.last_lamplighter.mq24.proof stage --capture spec/art_identity/maquettes/last_lamplighter/mq24/proof/director-feedback1-native/capture --regeneration spec/art_identity/maquettes/last_lamplighter/mq24/proof/director-feedback1-regeneration
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-25 && python3 -B -m spec.art_identity.maquettes.last_lamplighter.mq24.proof verify --capture spec/art_identity/maquettes/last_lamplighter/mq24/delivery --regeneration spec/art_identity/maquettes/last_lamplighter/mq24/delivery/validation/regeneration
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-25 && python3 -B -m spec.art_identity.maquettes.last_lamplighter.mq20.proof verify
```

No local windowed command was attempted. This offline maquette has no Godot
UI scene or saved-run fixture, so `visual_probe_runner.py` and
`inspection_fixture.py` have no applicable target. Blender work used only the
approved headless bridge.
