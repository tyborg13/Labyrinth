# rr-18 — director feedback 3 handoff

**Every headless gate passes in both views.** The 13 rear failures / 14 pocket occurrences are repaired, including coverage of each old material-hit pixel for **every permitted native UV candidate**. All 682 presented frames are free of green-dominant texels, pockets, stray/outline/outside defects and flat-surface provenance failures. Work remains uncommitted and unstaged. No frame exemptions or motion changes were added.

## Numbered director requirements

1. **Rear continuation pockets:** the two affected boulders (`upper_far`, `thigh_far`) receive connected Euclidean own-edge extensions around the three diagnosed source locations, at the existing 3 px tuck depth. The paired visible/hidden texture quads also retain that 3 px padding, with the original anchors and bone poses unchanged. Edge texels come from the covered boulder's own eligible visible surface, as in rr-15. Regression fixtures check every old target pixel remains opaque even under all of the native oracle's UV tie choices. No gap was waived or opened to bypass the gate.
2. **Green residue:** the strict rule is exactly `G > R + 12` and `G > B + 12`, with opaque alpha. It runs on every headless presented frame and every native isolated/composed frame; the production capture also checks each actual unit texture. The remaining residue originated in **three visible source texels**, not the hidden-fill assets. Their nearest non-green same-boulder replacements are recorded in [green_sources.json](proof/green_sources.json). The original paintings and raw authoring partition remain untouched.
3. **No flat patches:** every hidden/continuation texel is regenerated from its own boulder's nearest eligible non-outline, non-green visible surface. The added footprint is a connected round-distance stencil rather than a filled box. Exact own-surface provenance and adversarial flat-patch tests pass; exposed outlines and dark slabs remain zero. All 14 updated CPU crops were inspected.
4. **Headless proof:** source/cut, raw identity, idle/signed motion, action direction and coverage, both stride swings, knees/supports, dense reach, density rest, clean pieces, material provenance, green and rigid pocket checks pass in both views. All ten mutations are caught. Seer/Thrall sets remain green. No full suites or windowed runs were attempted.

## Raw authoring versus derived presentation

The raw source partition is retained in `raw_cut/` and is still **0 px against each protected painting**. Its PNG hashes and canonical painting path/hash are independently checked; a tamper regression fails on a one-pixel edit. The requested material repairs are a separate deterministic presentation stage, with references at `source/<view>/continued.png`. They differ from the protected source by **1 front / 28 rear pixels**: three prescribed green replacements and 26 rear edge-coverage pixels. Every colour is an existing texel from the same boulder; no new paint, palette or motion is invented. Visible presentation provenance is checked against the exact raw cut and cleanup algorithm, separately from hidden-surface provenance.

This separation resolves the source-identity conflict without changing the protected artwork or exempting green pixels. The raw source remains exact, while the cleaned presentation/native references are exact after the requested processing. Production then uses the existing front `clean` / rear `regrid` 1.22 density pipeline, without an override. Both density-derived production rests compare at **0 px**. The supplied director's earlier native seals are stale after these texture changes; refresh density/rest before the new native chain.

## Files changed

- `rr18_source_stage.py`, `raw_cut/`, cleaned presentation references and `rr18_materials.py`: immutable raw cut, prescribed green cleanup and rounded own-surface continuation generation.
- `rr18_repair.py`, `rr18_build.py`, anatomy/case recipe, layouts, pieces/check masks, gates/mutations and proof metadata: reproducible repair/build and stronger regression proof.
- Promoted Mirror assets, adopted density sources/outputs, Mirror identity/rest and shadow records; unrelated creatures retained.
- Generic proof-only extensions: `material_gates.py`, optional anatomy material policy, native green/reference checks, raw-source trace support and removal of the authoring-only raw pointer during promotion. No shared humanoid runtime or other figure's render input changes.
- `tests/test_rr18_materials.py`, `tests/test_rr18_humanoid.py`, native/production probe changes and documentation. No dependencies or gameplay/analytics/save changes.

## Observed results

```text
RR18 ALL GATES: PASS (0 unique errors)
Ran 208 tests in 161.968s
OK
RR18 NATIVE PROBE LOAD: PASS
MAQUETTE PRODUCTION LOGIC: PASS (940 frames)
RR18 SHADOW RECORDS: PASS (2 v2 views; every other unit retained)
SFX SYNC HARNESS RESULT: PASS (4075 observations, 0 failures)
SFX SYNC HARNESS RESULT: PASS (3348 observations, 0 failures)
SFX SYNC HARNESS RESULT: PASS (1604 observations, 0 failures)
TEST REGISTRATION AUDIT: PASS (750 scripts; full suite=406, quarantined=29, windowed probe=315)
```

Production logic passes **940 frames per view**. All ten mutation programs are caught, including green residue, flat patches and stone/air calibration. Art identity: `Ran 111 tests in 38.143s`, `OK`; icon identity: `Ran 7 tests in 0.076s`, `OK`; sidecars: `Ran 19 tests in 1.135s`, `OK`, with new untracked source sidecars also checked. Exact observed lines and log hashes are in [verification.json](proof/verification.json). Existing CA-certificate/shutdown warnings remain in logs; no existing master assertion was rewritten.

## Repaired crops

Updated CPU-only crops and their clip/frame index are in ignored `proof/feedback3_repaired/`; [index](proof/feedback3_repaired/index.json). They cover move 1; Refraction 13–17, 58–59; guard 7–8, 16 (two), 47–48. The formal coverage regression pins all 14 original material-hit screen pixels and requires them opaque for every allowed native UV candidate. These crops are diagnostic evidence, not fresh GPU proof.

## Reproduce headless proof

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-18 && python3 -B experiments/cutouts/glacial_mirror/rr18_build.py
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-18 && python3 -B experiments/cutouts/glacial_mirror/rr18_density.py --refresh-sources
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-18 && python3 tools/godot_task_runner.py --task-id rr-18 --stream -- godot --headless --path . --script tests/rr18/action_direction.gd -- --case experiments/cutouts/glacial_mirror/rr18 --output experiments/cutouts/glacial_mirror/rr18/proof/samples.json
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-18 && python3 -B experiments/cutouts/glacial_mirror/rr18_gates.py
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-18 && python3 -B experiments/cutouts/glacial_mirror/rr18_focused.py
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-18 && python3 -B experiments/cutouts/glacial_mirror/rr18_mutations.py
```

The small in-place repair helper preserves registration while applying the same material rules. The complete builder was rerun successfully from the approved inputs; source readoption follows a build, never already-treated production pixels.

## Proof for the design owner

Exact sequence at **1920×1080, 100% UI scale**. Refresh density/rest because presentation textures and their bindings changed, then run native, sheets, idle, production and review. No windowed command was attempted by this worker.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-18 && sh experiments/cutouts/glacial_mirror/rr18_proof.sh density
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-18 && sh experiments/cutouts/glacial_mirror/rr18_proof.sh rest
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-18 && sh experiments/cutouts/glacial_mirror/rr18_proof.sh native
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-18 && sh experiments/cutouts/glacial_mirror/rr18_proof.sh sheets
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-18 && sh experiments/cutouts/glacial_mirror/rr18_proof.sh idle
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-18 && sh experiments/cutouts/glacial_mirror/rr18_proof.sh production
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-18 && sh experiments/cutouts/glacial_mirror/rr18_proof.sh review
```

Captures remain ignored under `proof/{native_rest,native,contact_sheets,idle_native,production_native}` and `*.mp4`. No inspection-fixture command was requested; the director prepares it.

## TODO_DESIGN, chosen defaults and open issues

- **TODO_DESIGN:** none. The source-identity conflict is resolved by retaining the exact raw partition and applying only the prescribed operations to the derived presentation.
- **Chosen defaults:** named synthetic fixtures and proof-only 14-point coverage fixtures; existing 8 px crop padding / 3× zoom, cameras, step sizes and timeouts remain unchanged. Quad padding and edge growth use the already-declared 3 px tuck depth; green dominance uses the director's 12-channel margin. No player-facing tuning was chosen.
- **Open issues:** fresh director-native density/rest, sprite/idle/production proof and visual inspection only. Headless implementation is complete; production readiness remains pending that proof. No peer review, commit, staging, branch change or publication was performed.
