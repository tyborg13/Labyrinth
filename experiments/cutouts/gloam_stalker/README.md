# rr-35 — feedback 3 gate quality

This round changes validation and tests only. Motion, layouts, cuts and assets
are unchanged from the director's accepted delivery and windowed proof commit
`187ce0327`. The new edits remain uncommitted.

- CPU seam diagnostics now use the shared compiled-clip evidence validator
  before any raster processing. It derives all view/clip/frame counts and phases
  from the compiled clips, rejecting empty, truncated or duplicated inventories.
- Both legacy consumers use `rr35_baseline.py`: immutable revision
  `f1fae7475b2c034f85cd785f080434283c94bfee`, with SHA-256 checks for the reach
  implementation and all three foreign-record registries. Tests reject an
  rr-35-containing revision and tampered source bytes.
- Pixel controls duplicate approved plate pixels onto each arm, the head and
  each cape in both views, preserving the torso. All ten controls fail when the
  exclusivity loop is removed; the existing ownership gate itself is unchanged.

The new tests reproduced the old CPU failures before the fix. The original
six-test run reported `FAILED (failures=2, errors=3)` (the baseline API did not
exist yet). The intact pixel guard passed, and removing that guard produces ten
assertion failures. An unchecked `HEAD` baseline also produces two assertion
failures, one per consumer. See [feedback3_mutations.json](rr35/proof/feedback3_mutations.json)
and the ignored `proof/logs/feedback3/` logs.

Current validation and exact commands are in
[feedback3_verification.json](rr35/proof/feedback3_verification.json).
Observed results are `Ran 28 tests in 125.148s` / `OK`,
`Ran 177 tests in 434.327s` / `OK`, and 353 CPU frames per view with zero failures.
The pinned legacy comparison reports 23 byte-identical JSON reports.
The old preservation script at `187ce0327` and the updated script both report
the same two production rest-PNG mismatches against round 0, after the
director's native rebakes. Those assertions and assets are unchanged. The new
pinned foreign-record checks pass.

Only `tests/rr35/run_reference_tests.py` is covered by the native receipts among
this round's changed code. All five existing frame manifests differ from current
bindings only at that key; their contents are untouched. Visual approval stands,
but strict provenance needs **rest, native, sheets, idle, production, review**
again using the exact commands below. **Density does not need a rerun**: no
density input, rest asset, shadow cache or density capture script changed.
The audit is [feedback3_bindings.json](rr35/proof/feedback3_bindings.json).

## Accepted rig and feedback-2 measurements

The two remaining design items are resolved using the director's feedback-2
decisions. The director committed that implementation and completed windowed
proof. No active `TODO_DESIGN` placeholders remain.

## 1. Front slash

The protected staged motion is imported byte for byte into the case and
production. Front `hand_far.forward_px` is **26 at contact / 21 at follow-through**;
rear remains **20 / 16**, with its existing lift override. Move remains lift
**3 px**, lane narrowing **0.4**. No staged bytes were edited by the worker.
The input hashes are in [feedback2_inputs.json](rr35/proof/feedback2_inputs.json).

| View | Rest → contact reach | Required minimum | Wind-up 0.3 → contact 0.48 travel |
|---|---:|---:|---:|
| Front | 16.643815 px | 16 px | 45.185107 px |
| Rear | 25.734375 px | 18 px | 41.814693 px |

Travel is report-only. The 4° action lean gate is unchanged. The source blade
tip, authored rest/wind-up/contact transforms and exact measurements are in
[gates.json](rr35/proof/gates.json).

## 2. Rear near-leg reach

Only `legs.near.rear.minimum_reach` declares **3.5 px**, with the exact reason:

> r3 crouch foreshortens the rear near thigh; director judges the native rear move frames (rr-35 feedback 2)

Every other leg/view keeps the existing 4 px arithmetic. The optional anatomy
field affects the offline gate only; no runtime IK or pose calculation changed.
Omitting it preserves the previous report shape and arithmetic. The schema
requires a finite, nonnegative margin and a reason.

| View / leg | Worst move reach | Phase | Margin | Required minimum |
|---|---:|---:|---:|---:|
| Front / near | 65.765822 px | 0.337 | 4 px | 12.174472 px |
| Front / far | 38.417991 px | 0.136 | 4 px | 16.005186 px |
| Rear / near | 25.094914 px | 0.860219238 | 3.5 px | 24.909323 px |
| Rear / far | 54.279551 px | 0.308 | 4 px | 11.942929 px |

The required mutation restoring 4 px fails: **25.094914 < 25.409323 px**.
It also fails at the reported presented frame **43 / phase 0.86**:
**25.095001 < 25.409323 px**. The failing control refines the unchanged path
more finely than the passing gate, whose sampled minimum is 25.095001 at 0.86.
All 51 presented move frames per view pass the current per-leg thresholds.
Exact paths, presented-frame checks and mutation output are in
[feedback2_reach.json](rr35/proof/feedback2_reach.json).

## 3. Rebuild and verification

The layouts, motion compilation, production assets and density derivations are
rebuilt. Motion-conditioned hidden coverage is regenerated from the approved
source surfaces, followed by the all-frame CPU component/seam checks.
The accepted round-0 source cut, rest paint, carapace ownership, draw order,
stance knee policies and other clips are preserved.

Exact commands, exits and result lines are in
[verification.json](rr35/proof/verification.json). Full logs are gitignored under
`rr35/proof/logs/feedback2/`. Historical reports remain under
[round0/](rr35/proof/round0/verification.json) and
[feedback1/](rr35/proof/feedback1/verification.json).
Full suites and windowed runs were not attempted.

Observed final result lines:

```text
Ran 22 tests in 122.766s
OK
Ran 177 tests in 429.001s
OK
RR35 ALL GATES: PASS (0 unique errors; native=False)
RR35 FRONT CPU SEAMS/CLEAN: PASS (353 frames; 0 failures)
RR35 REAR CPU SEAMS/CLEAN: PASS (353 frames; 0 failures)
RR35 LEGACY REACH REPORTS: PASS (23 byte-identical JSON reports)
```

The focused reference run also compares reach reports against the previous
implementation, with 23 byte-identical JSON reports. Other rigs and source files
are hash checked by [rr35_preservation.py](rr35_preservation.py); all 311 accepted
cut/density PNGs remain unchanged. Generic feedback-2 changes are confined to
`anatomy.schema.json`, `reach.py` and the new `reach_policy.py`, tested by the
focused rr-35 mutations, anatomy/reach regressions and reference equivalence.
The earlier optional per-view stance policy and `walk_gates.py` change remain
unchanged from round 0.

Reproduce headless proof from the task directory:

```sh
PYTHONPATH=tools python3 -B experiments/cutouts/gloam_stalker/rr35_case.py
PYTHONPATH=tools python3 -B experiments/cutouts/gloam_stalker/rr35_build.py
PYTHONPATH=tools python3 -B experiments/cutouts/gloam_stalker/rr35_density.py --rebuild-derived-sources
PYTHONPATH=tools python3 -B experiments/cutouts/gloam_stalker/rr35_evidence.py --refresh
PYTHONPATH=tools python3 -B experiments/cutouts/gloam_stalker/rr35_gates.py
PYTHONPATH=tools python3 -B experiments/cutouts/gloam_stalker/rr35_seams.py
python3 -B -m unittest tests.test_rr35_cutout tests.test_rr35_production
PYTHONPATH=tools python3 -B experiments/cutouts/gloam_stalker/rr35_preservation.py
```

`rr35_continuations.py` and `--actions` regenerate the recorded motion-conditioned
coverage from current samples; normal rebuild/density/sample refresh follows.
The exact expanded focused reference command is recorded in verification.json.

## Proof for the design owner

These exact stages use the visual runner at **1920×1080, 100% UI scale**. Capture
artifacts stay gitignored. The sandbox cannot run windowed proof.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-35 && sh experiments/cutouts/gloam_stalker/rr35_proof.sh density
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-35 && sh experiments/cutouts/gloam_stalker/rr35_proof.sh rest
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-35 && sh experiments/cutouts/gloam_stalker/rr35_proof.sh native
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-35 && sh experiments/cutouts/gloam_stalker/rr35_proof.sh sheets
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-35 && sh experiments/cutouts/gloam_stalker/rr35_proof.sh idle
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-35 && sh experiments/cutouts/gloam_stalker/rr35_proof.sh production
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-35 && sh experiments/cutouts/gloam_stalker/rr35_proof.sh review
```

Outputs: `rr35/proof/{native_rest,native,contact_sheets,idle_native,production_native}`
and the idle/review MP4s at the proof root. `density` performs the native rest
rebake, rest recording, scoped Gloam shadow refresh and provenance seal. The
director completed density, rest rebakes and shadow refresh in `187ce0327`.
No new `inspection_fixture.py` command was requested; the director owns fixture
preparation, commit, review and publication.

Both source rests retain 0 visible-pixel mismatches. As recorded in round 0,
front `(173,170)` has invisible RGB `(27,15,20)` under alpha 0; only the derived
copy normalizes that texel to transparent black. The protected painting is exact.
Measured near/far stance bends remain **32.537166°/53.242111° front** and
**61.332177°/40.635037° rear**.

## Chosen defaults and files

No new defaults were chosen in feedback 2. All changed thresholds and data values
are director decisions. Existing diagnostic defaults remain in
[chosen_defaults.json](rr35/proof/chosen_defaults.json).
[Complete current file inventory](rr35_files_changed.txt).
