# rr-18 — director feedback 1 handoff

The four prior TODOs are resolved. Strict seam acceptance is still incomplete; see `proof/seams.json` and `TODO_DESIGN_source_gap_calibration`. All work remains uncommitted.

## Feedback requirements

1. **Replacement walk:** copied the staged director motion byte for byte into authoring and production, then recompiled. The two stride swings belong to the camera-side long leg; body-mode trailing shuffle is excluded from planted stance/sliding assertions, following the Thrall pattern. Both legs still receive the every-frame facing check. No key or reach target was tuned. Both views have **0.537227184818 px** maximum presented target error and **0.0 px** stance slide.
2. **Knee policy:** case anatomy declares 10° near-straight in both legs/views, with facing bend sides +1 front / −1 rear. Every stride swing passes the 15° peak and swing-above-stance apex checks:

| View / stride swing | Peak bend | Swing at apex | Stance at apex |
|---|---:|---:|---:|
| Front / 1 | 47.473280° | 46.029155° | 17.477829° |
| Front / 2 | 53.880697° | 53.880697° | 17.477829° |
| Rear / 1 | 55.011649° | 55.011649° | 10.669783° |
| Rear / 2 | 43.590463° | 41.926301° | 10.669811° |

3. **Rest identity:** raw source composition is 0 px against both paintings. Production uses the registered front `clean` and rear `regrid` 1.22 pipeline without an override. Actual production composition and saved rest snapshot each compare at 0 px to independent density derivation. The density-derived snapshots explicitly have `native_pixels: false`; director renderer sealing remains pending. The `rest` probe now captures both raw-source and production-rest pairs and rejects differences in either.
4. **Gates/proof:** all listed headless gates except joint seam holes pass. The final strict gate exits 1 with 142 failing frames (20 front, 122 rear) among 682 scanned frames, containing 210 pockets. There are zero other clean-piece defects. Some pockets map entirely to existing transparent source gaps; `proof/seams.json` includes inverse source coordinates for every pocket. A calibration decision remains explicit rather than inventing paint, changing protected motion or granting exemptions. The exact seven windowed commands are below. No full suites or windowed runs were attempted.

## Files changed in this feedback pass

- `rr18_case.py`, `rr18_build.py`, `rr18_checks.py`, `rr18_density.py`, `rr18_gates.py`, new `rr18_seams.py`: director import, knee/role semantics, shared rigid-boulder raster registration, independent density rest, strict raster diagnostics.
- `rr18/` anatomy, inputs, cutout, imported/compiled data, layouts, regenerated cropped pieces/check masks and proof reports. Original source paint and hidden continuation texels remain unchanged in source coordinates; only bounds/registration change.
- `assets/units/glacial_mirror_cutout/` promoted motion, layouts, matching cropped pieces, density-treated rest and integration report.
- Mirror-only density adopted sources/outputs, identity rest measurements and generated shadow records.
- `tests/test_rr18_humanoid.py`, `tests/rr18/native_capture.gd`, `tests/rr18/rest_contract.json`: new gait/density checks, snapshot/crop regressions and production native rest proof. No generic humanoid implementation changes.
- This handoff, parent README and proof metadata. See `git diff --stat` for the exhaustive derived-file list.

## Observed proof

```
Ran 188 tests in 168.799s
OK
Ran 18 tests in 12.794s
OK
RR18 RUNTIME: PASS (5964 checks; headless logic only)
RR18 NATIVE PROBE LOAD: PASS
MAQUETTE PRODUCTION LOGIC: PASS (940 frames)  [front and rear]
SFX SYNC HARNESS RESULT: PASS (4075 observations, 0 failures)
SFX SYNC HARNESS RESULT: PASS (3348 observations, 0 failures)
SFX SYNC HARNESS RESULT: PASS (1604 observations, 0 failures)
TEST REGISTRATION AUDIT: PASS (750 scripts; full suite=406, quarantined=29, windowed probe=315)
RR18 SOURCE/CUT GATES: PASS (0 errors; both views)
RR18 FRONT SEAMS: FAIL (20 errors)
RR18 REAR SEAMS: FAIL (122 errors)
RR18 ALL GATES: FAIL (142 unique errors)
```

All six guard mutations are caught. Art identity: `Ran 111 tests in 38.484s`, `OK`. Icon identity: `Ran 7 tests in 0.075s`, `OK`. Source/density preservation checks cover 3,616 tracked files and all unrelated identity/density records. Shadow refresh retains every other unit. Current bindings match the samples and both 940-frame production reports. Full result lines, exact logs and hashes: [proof/verification.json](proof/verification.json). No master assertion was weakened.

## Proof for the design owner

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-18 && sh experiments/cutouts/glacial_mirror/rr18_proof.sh density
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-18 && sh experiments/cutouts/glacial_mirror/rr18_proof.sh rest
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-18 && sh experiments/cutouts/glacial_mirror/rr18_proof.sh native
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-18 && sh experiments/cutouts/glacial_mirror/rr18_proof.sh sheets
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-18 && sh experiments/cutouts/glacial_mirror/rr18_proof.sh idle
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-18 && sh experiments/cutouts/glacial_mirror/rr18_proof.sh production
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-18 && sh experiments/cutouts/glacial_mirror/rr18_proof.sh review
```

1920×1080 at 100% UI scale. Capture directories remain ignored: `proof/{native_rest,native,contact_sheets,idle_native,production_native}`; CPU-only diagnostic examples are `proof/seam_cpu/front_guard_0020.png` and `rear_refraction_0032.png`. No native captures exist from this worker. No `inspection_fixture.py` step was requested; the director owns fixture preparation.

## TODO_DESIGN placeholders, chosen defaults and open issues

- `TODO_DESIGN_source_gap_calibration`: decide how the strict joint-hole calibration treats posed pockets originating in approved transparent source gaps. The original four placeholders are removed; no failing seam was exempted.
- New chosen defaults: diagnostic progress every 50 frames (named `PROGRESS_INTERVAL_FRAMES`, matching the Thrall cadence), and the proof-only production-rest caption. All existing named test cameras, fixtures and timeouts remain unchanged. No perceptible gameplay value was chosen.
- Remaining acceptance: strict seam gate and director native rest/sprite/idle/production inspection. Some macOS headless launch/shutdown warnings remain in logs; passing assertion/exit results are recorded without suppressing warnings.
