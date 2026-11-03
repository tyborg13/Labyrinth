# rr-43 feedback 1 — supplied house outline

This supersedes the round-0 outline exception in `HANDOFF.md`. The director's
new protected recipe is replayed exactly. The new sheet has no failing metric.
All changes remain uncommitted; the owner retains commits, review, inspection
and publication. No windowed run was attempted.

## Requirements and implementation

1. **Recipe and identity.** `tools/art_identity_lancer_recolour.py` binds the
   supplied `acc62d607d59b2a76c017e6a55e78ce0db20d2f7ea79ea6b047e748b1ff5a4cd`
   recipe and executes its literal fourth step. The raw-step record, processed
   image/metadata, provenance, registry and sheet were regenerated. Encoded PNG
   replay is identical to the director's image. The complete official metric
   table is in `outline_metrics.json`; all rows are PASS or INFO. Director sheet
   judgment and fresh native proof remain pending.
2. **Accepted partition.** `rr43_outline.py` overlays only the complete painting's
   four-neighbour silhouette edge on the retained source parts. It never computes
   an outline from an individual cut. The round-0 ZIP and its hash-bound inventory
   retain the original source/production paint, alpha, layouts and donor data.
   Source and production alpha/crops/geometry/recipes and all 82 ownership mask
   files are unchanged. Interior paint and hidden fills are byte-exact except
   where the whole silhouette edge intersects them. Both independent rest
   assemblies have zero mismatched pixels. Density processing preserves the new
   edge and the accepted production RGB everywhere else.
3. **Preservation.** The front art, rr-41 lining, front spear/grip/continuity gates,
   motion, timing, protected staged inputs and generic runtime/gate tool retain
   their accepted hashes. The only changed director input hashes in the old
   preservation record are the two explicitly supplied updates. Shaft registration
   uses the retained original paint so the outline cannot move its axis/grip.
4. **Gate behavior.** `tools/art_identity_gate.py` is byte-identical. The existing
   `lancer_rear_v2` replay still rejects extra outline and palette-match steps.
5. **Final proof.** A successful headless worktree import precedes both full
   suites. Exact results and portable logs are recorded in
   `../../rr43_feedback1_verification.json`. Persistent Briar setup
   failures were also reproduced after import at base `a49de4cd3`, using identical
   test source and normalized tracebacks, without changes to that unit.
6. **Owner proof.** Commands below retain the existing scripts/contracts.

## Artifact identities

- Processed rear SHA-256:
  `85845e1e0c66ab760afd6671390dfab71f5a20c7e62c3e8b1420b74250c7e8b7`
- Rear pieces manifest (`rear_outline_manifest.json`) SHA-256:
  `429afe4dda2ce0f915634731d553aa1b72f7c64f4dc5fab0bfdbddc5f62a48d9`
- Exactly 1,020 visible RGB pixels change; alpha is identical and no pixel drops.
- Rear `edge_light_share=0.0`; consistency chroma delta
  `0.006822991973786954`, value delta `0.017374465827681623`, both within `[0,0.03]`.

## Reproduction

Use the existing Python environment/dependencies. Do not invoke the historical
re-segmentation builder; the accepted partition is immutable for this feedback.

```sh
python3 tools/art_identity_gate.py check --kit spec/art_identity/jobs/frostglass_lancer/mq14_rear_v2/kit.json
PYTHONPATH=tools python3 -B experiments/cutouts/frostglass_lancer/rr43_outline.py
PYTHONPATH=tools python3 -B experiments/cutouts/frostglass_lancer/rr37_density.py --rebuild-derived-sources
PYTHONPATH=tools python3 -B experiments/cutouts/frostglass_lancer/rr43_outline.py --seal-manifest
PYTHONPATH=tools LABYRINTH_TASK_ID=rr-43 python3 -B experiments/cutouts/frostglass_lancer/rr39_density.py --seal-rests
```

Finalize the manifest after density derivation, then seal rest evidence after all
source JSON changes. The pose digest includes those JSON bindings; sealing too
early leaves stale evidence even when the composed pixels are identical.
`--seal-manifest` reproduces the recorded manifest byte for byte and refuses
changed geometry, interior paint or rest assemblies.

The outline derivation verifies its immutable baseline archive and supplied
processed master before writing parts. A full-part inner-edge outline mutation
is rejected independently. The original lower-shaft split mutations remain.

## Proof for the design owner

Run at 1920×1080, 100% UI scale. Inspect rear in every clip at 2–4×, front lunge
rise/recovery frames 56–62, and the new identity sheet.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-43 && LABYRINTH_TASK_ID=rr-43 sh experiments/cutouts/frostglass_lancer/rr37_proof.sh density
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-43 && LABYRINTH_TASK_ID=rr-43 sh experiments/cutouts/frostglass_lancer/rr37_proof.sh rest
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-43 && LABYRINTH_TASK_ID=rr-43 sh experiments/cutouts/frostglass_lancer/rr37_proof.sh native
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-43 && LABYRINTH_TASK_ID=rr-43 sh experiments/cutouts/frostglass_lancer/rr37_proof.sh sheets
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-43 && LABYRINTH_TASK_ID=rr-43 sh experiments/cutouts/frostglass_lancer/rr37_proof.sh review
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-43 && python3 tools/visual_probe_runner.py --task-id rr-43 --no-headless --display-driver macos --audio-driver Dummy --timeout 900 --expect-size 1920x1080 --proof-contract experiments/cutouts/frostglass_lancer/rr41_gameplay_contract.json --result-manifest experiments/cutouts/frostglass_lancer/rr37/proof/logs/rr43-gameplay-result.json --overwrite-result-manifest tests/frostglass_lancer_cutout_gameplay_probe.gd -- --output res://experiments/cutouts/frostglass_lancer/rr37/proof/rr43_gameplay_native
```

Capture paths: `rr37/proof/native_rest/`, `native/`, `contact_sheets/`,
`frostglass_lancer_review.mp4`, `rr43_gameplay_native/`. The identity sheet is
`spec/art_identity/jobs/frostglass_lancer/mq14_rear_v2/review_sheet.png`.
Existing native captures are stale for this image; headless/software results
are never presented as native renderer proof. No inspection-fixture command
was requested; the owner prepares the fixture.

## TODO_DESIGN placeholders

None. No missing player-facing decision was encountered.

## Chosen defaults

No new player-facing values. The retained test baseline ZIP uses the standard
ZIP epoch (1980-01-01) for deterministic packaging; all proof/test settings use
the accepted round-0 named defaults listed in `HANDOFF.md`.
The final full-Godot rerun uses a 1,200-second outer runner cap so the unchanged
900-second suite budget and per-child 180-second caps can report their complete
results; the first outer 900-second cap interrupted result emission. No test
assertion or in-suite budget is relaxed. This is recorded as
`godot_full_outer_timeout_seconds` in the verification data.

## Official rear gate metrics

| Metric | Value | Band | Result |
|---|---:|---|---|
| rear.height | 227 | INFO only | INFO |
| rear.width | 159 | INFO only | INFO |
| rear.height_drawn | 227.0 | [226, 255] | PASS |
| rear.symmetry | 0.7137578998541565 | [unbounded, 0.86] | PASS |
| rear.thin_abs | 0.005533943345570114 | [unbounded, 0.06] | PASS |
| rear.thin_rel | 0.07435209029642209 | [unbounded, 0.12] | PASS |
| rear.feature_px | 5.501545086757465 | [4.4, unbounded] | PASS |
| rear.regions | 603 | INFO only | INFO |
| rear.chroma | 0.12949255533674758 | [unbounded, 0.2] | PASS |
| rear.value | 0.23073612834537136 | [0.12, 0.4] | PASS |
| rear.edge_light_share | 0.0 | [unbounded, 0.06] | PASS |
| rear.orphan_share | 0.1583474878088872 | INFO only | INFO |
| rear.run_length | 1.8232767232767233 | INFO only | INFO |
| rear.art_scale | 1.0 | [0.75, 1.2] | PASS |
| rear.fit_scale | 1.0 | INFO only | INFO |
| rear_consistency.chroma_delta | 0.006822991973786954 | [0, 0.03] | PASS |
| rear_consistency.value_delta | 0.017374465827681623 | [0, 0.03] | PASS |

## Final observed verification

The worktree was imported headlessly through the task runner before the full
suites. No assertions or out-of-unit implementation were changed.

| Check | Exact result lines |
|---|---|
| Full Godot | `MAIN BODY ASSERTIONS: 495562`; `FULL SUITE RUNTIME: 856.690 seconds (budget 900 seconds)`; `TEST RESULT: PASS` |
| Godot program inventory | 226/226 completed; every return code 0, including SPX, no-action, FIX-11 test and FIX-11 probe |
| Final full Python | `Ran 2004 tests in 7835.722s`; `FAILED (failures=1, errors=2, skipped=66)` |
| Focused rr-43 plus fill gate | `Ran 14 tests in 149.654s`; `OK` |
| Final outline/partition checks | `Ran 5 tests in 25.218s`; `OK` |
| Reference sets | `Ran 168 tests in 617.369s`; `OK` |
| Art identity tests | `Ran 111 tests in 133.837s`; `OK` |
| Historical selection | `Ran 11 tests in 214.156s`; `OK` |
| Repaired rest evidence | `Ran 1 test in 23.076s`; `OK`; repeated within final full discovery with byte-identical evidence |

Final full discovery observed both inventories as
`RR37 FRONT PRODUCTION FRAMES: PASS (512 frames; 0 failures; software raster, native runtime poses)`
and
`RR37 REAR PRODUCTION FRAMES: PASS (512 frames; 0 failures; software raster, native runtime poses)`.
Every uncovered metric and action-canvas edge count is zero in both views.
`RR41 ALL FRONT ROUNDING: PASS (2048 UV/pose cases; 512 poses x 4 choices; every clip including move; no fresh native capture)`.
`RR41 FRONT PAINT PROVENANCE: PASS (512 frames; every clip; 0 procedural leg texels)`.
`RR41 REST/DENSITY RESEAL: PASS (fresh Godot rest-pose digest and both density evidence hashes byte-identical)`.

Source and production gates report zero unique errors. Material checks cover
54 CPU frames with zero defects. The gameplay logic probe passes 80 sprite
geometry cases (`errors: []`, `native: false`); the native probe's headless
load-only check passes. All 16 software previews were inspected. Source and
production sample bindings remain current at 1,396 poses each.

The registry reports
`ART IDENTITY CHECK: PASS (0 failures, 0 pending_reart warnings, 0 skipped replays)`.
Density reports `CHECK-OK`. Preservation reports
`RR37 PRESERVATION: PASS (5563 protected files; other rigs byte-identical)`.
Registration reports
`TEST REGISTRATION AUDIT: PASS (854 scripts; full suite=500, quarantined=29, windowed probe=325)`.

### Remaining full-Python failures

- Two Briar Weaver setup errors still fail while creating `review_stale_*` and
  `review_clean_*` beneath the missing `mq9/proof/logs` parent. Both programs
  were run after import at base `a49de4cd3`, where they fail identically. Test
  source bytes and normalized final-full-run tracebacks match exactly.
- The out-of-unit SB-02 `test_incremental_submission` timing assertion reports
  mixed cold plan **4,252 us > 4,000 us** in final full discovery. The same
  unchanged test passes in isolation in the candidate (`Ran 1 test in 10.571s`,
  `OK`) and imported base (`Ran 1 test in 12.654s`, `OK`). The full-run failure
  was not reproduced in either isolated run; no cause or pre-existing failure
  is claimed from those isolated passes. Its code and timing assertion remain
  unchanged.

The first Python run (`Ran 2004 tests in 9041.569s`,
`FAILED (failures=2, errors=2, skipped=66)`) additionally found a stale generated
rest-pose binding. Both pixel mismatches were already zero; the evidence was
resealed after the source JSON hash update, and the final full run passes that
assertion. The manifest now has a deterministic finalization command, and the
reproduction order above prevents the stale binding. The first full Godot
attempt hit its outer 900-second cap during concurrent Python work. Its log
and interrupted report are retained alongside the successful sequential run.

Portable logs, both initial attempts, final transcripts, all 226 successful
Godot program logs, normalized base evidence and exact artifact digests are
under `rr37/proof/logs/rr43_feedback1/`, referenced by the feedback verification
JSON. Fresh native captures and director sheet judgment remain outstanding.
