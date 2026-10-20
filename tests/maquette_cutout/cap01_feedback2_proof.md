# cap-01 feedback 2

This supersedes feedback 1's exact headless production counts and per-folder
production gate paths. Native capture inventories, canonical gates, writers,
formats, renderer bindings, encoding settings and game data remain unchanged.
All implementation changes are uncommitted.

## Changes and acceptance

1. Production inventory validation reads the capture's observed clips, phases,
   named contacts and manifest errors. Counts and phase ranges are reported;
   no headless count table is loaded. Native captures retain exact inventories.
   Production comparison matches `(capture view, stage, presented_phase)`, with
   raw `phase` as fallback when `presented_phase` is absent. Repeated identities
   match by occurrence, so duplicate phases are retained and hashes cannot be
   cherry-picked. Every matched renderer pixel hash must agree. Up to two
   unmatched frames per clip per side are allowed across that case's views;
   every unmatched frame is listed with its file, view, stage, phase and hash.
   Canonical gate JSONs and process exits are still compared exactly.
2. Production gates receive one combined case input, including both view
   streams and any captured walk-sample dictionaries. A stable merge avoids
   inventing cross-view phase restarts while preserving genuine within-view
   restarts for the unchanged gate to reject. One verdict and observed exit
   are written to `<case>/production/production_gates.json` and
   `production_gate_exit.json`. The old per-folder records are retained intact
   and recognized as historical r1 records.
3. `capture_director.py validate --before ...` checks and reuses the existing
   capture, regenerates only combined production gate records, recovers missing
   native exit evidence if necessary, and writes counts/ranges/outcomes. It
   never invokes a windowed capture. Before/after runs also write a validation
   summary beside their performance report.
4. Only focused tests and headless validation were run. No benchmark, windowed
   after capture, full suite, peer review, commit or publication was run here.

## Observed results

- `Ran 27 tests in 6.683s` / `OK` —
  `/tmp/cap01-feedback2-focused.log`.
- `CAPTURE VALIDATION: PASS; /private/tmp/cap01-feedback2-before-validation.json`
  — `/tmp/cap01-feedback2-before-validation.log`.
- Existing Seer front: **1,440 frames**. Mortar front and rear: **1,515 each**.
- `PRODUCTION SELF EQUIVALENCE seer: PASS (1440 matched; 0 unmatched)`.
- `PRODUCTION SELF EQUIVALENCE mortar: PASS (3030 matched; 0 unmatched)`.
  Details: `/tmp/cap01-feedback2-production-self.json`.
- Canonical combined production outcomes on the existing capture:
  Seer exit **0**, no errors; Mortar exit **1**, one error:
  `rear: missing production walk samples`.
- Native outcomes retained: Seer exit **1**, Mortar exit **0**.

Tests cover count variation, missing contacts/clips, invalid/narrow phase
ranges, exact hash mutation rejection, duplicate-phase multiplicity, listed
unmatched frames, the two-per-side limit, no common frames, combined-view walk
inputs, real restart detection, director routing, gate-error differences,
legacy-record preservation, and the validation CLI.

## Clarifications and limits

The existing real capture does not literally sample phase 0 and 1 for every
clip: hit spans `0.013332..0.949332`, several actions start after 0, and looping
idle wraps between samples. Validation therefore retains the existing
canonical progression span (`>= 0.5`), checks finite phases within `[0,1]` and
all exact named contacts, and reports `sampled_start` / `sampled_end` explicitly.
No new endpoint tolerance was invented. Exact endpoint enforcement remains a
pending director clarification; it would reject this completed before capture.

The comparison uses the renderer's `presented_phase` because raw idle phases
are wall-clock values and do not align between runs. This interpretation was
raised with the director and remains available for steering. The two-frame
allowance is exactly the requested value; it is not expanded for idle or any
other clip.

Both actual Mortar production manifests omit `walk_samples`. Combining them
cannot create that evidence. The unchanged canonical gate consequently still
reports its missing-walk error once, as a retained failure. No case-rig or
headless samples were relabeled as production samples, and no gate was bypassed.
A genuine source for absent production walk evidence remains a director choice.

Full before/after equivalence remains for the director to observe after capture.

## Files changed

- `spec/peer_benchmark/humanoid_cutout_rig.md` — production equivalence proof policy.
- `tools/capture_production.py` — new production assembly, observed validation
  and phase-matching helpers outside renderer bindings.
- `tools/capture_inventory.py` — production completeness and combined report
  inventory; native exact inventories unchanged.
- `tools/capture_gate_runner.py` — canonical gate receives combined production.
- `tools/capture_director.py` — reuse/validate phase, combined collection,
  production matching and validation summaries.
- `tests/test_capture_production.py` — new focused fixtures and regressions.
- `tests/test_capture_director.py` — updated count-variation expectations and
  end-to-end routing/reuse checks.
- `tests/maquette_cutout/cap01_feedback2_proof.md` — this handoff.

No new player-facing defaults or TODO_DESIGN values were introduced. The named
engineering default `PRODUCTION_PHASE_FIELD` is `presented_phase`, with raw
`phase` as fallback. The
matching allowance `MAX_UNMATCHED_PER_CLIP = 2` comes from feedback 2; phase
span/tolerance values preserve the canonical gate. The test fixtures and
private output directories are engineering-only.

## Proof for the design owner

Run from the task worktree. These paths preserve the existing before capture
and use a fresh after destination:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/cap-01
python3 tools/capture_director.py validate --before /tmp/cap01-proof/before --output /tmp/cap01-proof/before-validation-r2.json
python3 tools/capture_director.py benchmark --before /tmp/cap01-proof/before --output /tmp/cap01-proof/encoding-r2.json
python3 tools/capture_director.py after --output /tmp/cap01-proof/after-r2 --encoder-report /tmp/cap01-proof/encoding-r2.json
python3 tools/capture_director.py compare --before /tmp/cap01-proof/before --after /tmp/cap01-proof/after-r2 --output /tmp/cap01-proof/equivalence-r2.json
```

Only `after` is windowed. The exact expanded commands were generated without
running them and are available in `/tmp/cap01-feedback2-benchmark-commands.txt`
and `/tmp/cap01-feedback2-after-commands.txt`. No inspection fixture was requested.
