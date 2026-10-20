# rr-24 feedback 2 handoff

Changes are uncommitted on `codex/rr-24`, based on the director's reviewed
`7cdcebb1e2e037f252d989627df4d70ade9003a0`. Shared code and every other figure
remain unchanged. No full suite, windowed command, peer review, commit or
publication was run.

## Numbered requirements

1. **Own mq7b hidden colours.** The builder regenerates every hidden field
   from its current own piece's non-outline edge texels, preserving its alpha.
   `rr24_materials.py` validates RGBA provenance against those pieces. The
   source check covers every hidden piece, and both the headless source/cut
   entry point and native validator consume it. Exposed-pixel validation uses
   actual isolated surfaces/check masks and resolved occlusion; native proof
   uses GPU surfaces. Both-view skirt-colour mutations are rejected. The
   reviewed front jab 11 reproduced **46 skirt / seven sleeve foreign pixels**;
   the stronger check also found **11 torso pixels** there. The repaired frame
   retains the same 98 skirt / 36 sleeve / 202 torso exposed pixels, with zero
   foreign colours. Complete old/new evidence is in
   [feedback2_reproduction.json](feedback2_reproduction.json).
2. **Correct capture rest.** `rr24_capture_source.py` derives the Thrall-owned
   probe from the shared renderer. Rendering remains verbatim; the changes are
   a layout-driven rest selector, isolated evidence hashes, absolute location
   of the shared board-scale helper, and headless selector validation. All
   three Thrall paths (`rest`, `native`, `idle`) use it. The shared
   `tests/rr11/native_capture.gd` remains untouched. Real Godot headless loading
   reports `source/front/presentation.png` and
   `source/rear/presentation.png`. Raw and cleaned sources differ at **two
   front / five rear pixels**, so the old selector was demonstrably wrong.
   Raw mq7b identity remains a separate exact assertion; both composed rests
   still have **0 px mismatch**.
3. **Root-stabilised crops.** Collar and hem bounds are translated into each
   frame's rounded root coordinates before unioning. Each native image is
   cropped with its own integer-translated rectangle; no resampling is added.
   The metadata-only test reproduces the **382 px front / 338 px rear** walk
   overflow. The corrected widths are **142 / 96 px** at the same 2x zoom.
   All six clip/view collar plans fit the existing cells. The 1920x1080 sheet,
   320x360 cells, labels, zoom and 44-page contract remain unchanged. Capture
   metadata records root-relative bounds and each frame's root/crop rectangle.
4. **Fragments and preservation.** All 62 part-alpha fingerprints match the
   reviewed baseline. Layout fields (including depth), mesh fields, gait target
   coordinates, poses, raw paint and motion remain unchanged. Only colour
   fingerprints and their derived proof hashes are refreshed. The
   [preservation fixture](feedback2_preservation.json) pins this independently;
   [feedback2_repin.json](feedback2_repin.json) lists all 51 old/new baseline
   fingerprint updates. No alpha or fragment exemption was added. The director
   owns the rr-26 detached-component census after integration.
5. **Proof.** The exact windowed sequence is below. Capture folders remain
   gitignored under the case's `proof/.gitignore`. No renderer capture was
   attempted by this worker.

## Files changed and headless verification

The complete inventory is [feedback2_files_changed.txt](feedback2_files_changed.txt).
Implementation lives in `rr24_build.py`, `rr24_materials.py`,
`rr24_check.py`, `rr24_capture_source.py`, generated `rr24_native_capture.gd`,
`rr24_native_gates.py`, `rr24_crops.py` and the Thrall gate/proof wrappers.
The 16 recoloured piece files are mirrored into production and adopted density
sources. Tests are in `tests/test_rr24_feedback2.py`; mutations extend the
existing case-only runner. No existing test assertion was weakened.

Exact commands, result lines, exit codes and logs are in
[feedback2_verification.json](feedback2_verification.json). The focused runner
includes the directed Thrall, Seer, Mirror, Capacitor, gait and helper sets.

```text
Ran 335 tests in 428.703s
OK
RR24 CPU FRONT SEAMS: PASS (335 frames; 0 failing frames; native acceptance pending)
RR24 CPU REAR SEAMS: PASS (335 frames; 0 failing frames; native acceptance pending)
RR24 REST REFERENCE FRONT: source/front/presentation.png
RR24 REST REFERENCE REAR: source/rear/presentation.png
RR11 NATIVE PROBE LOAD: PASS
RR11 RUNTIME: PASS (5722 checks; headless logic only)
SFX SYNC HARNESS RESULT: PASS (4075 observations, 0 failures)
SFX SYNC HARNESS RESULT: PASS (3348 observations, 0 failures)
SFX SYNC HARNESS RESULT: PASS (1604 observations, 0 failures)
Ran 111 tests in 46.453s
OK
TEST REGISTRATION AUDIT: PASS (751 scripts; full suite=407, quarantined=29, windowed probe=315)
RR24 PROTECTED IDENTITY: PASS (26355 files; unrelated registry records retained)
```

All 11 guard-removal mutations were caught by assertions, with zero mutation
errors. CPU provenance scans counted **106,245 front / 147,700 rear** exposed
hidden-pixel observations and **zero foreign colours**. The targeted run also
passed: `Ran 27 tests in 14.032s` / `OK`.

The initial targeted run caught an over-broad new preservation fixture that
included colour fingerprints in its geometry hash; the fixture now excludes
only gait donor recipes and source-colour hashes, while separately pinning gait
target coordinates. The final results replace that initial attempt.

## TODO_DESIGN and chosen defaults

There are no active `TODO_DESIGN` placeholders and no new player-facing values.
No proof-layout defaults changed. Named test data pins the measured historical
walk widths (382/338), corrected widths (142/96), jab exposure counts
(98/36/202) and raw/clean differences (2/5). The foreign-colour mutation reuses
the existing magenta fixture. Crop translation rounds the sampled root to the
existing integer proof grid.

## Proof for the design owner

At 1920x1080 and 100% UI scale, run in order:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-24 && sh experiments/cutouts/arc_thrall/rr24_proof.sh density
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-24 && sh experiments/cutouts/arc_thrall/rr24_proof.sh rest
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-24 && sh experiments/cutouts/arc_thrall/rr24_proof.sh native
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-24 && sh experiments/cutouts/arc_thrall/rr24_proof.sh crops
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-24 && sh experiments/cutouts/arc_thrall/rr24_proof.sh sheets
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-24 && sh experiments/cutouts/arc_thrall/rr24_proof.sh idle
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-24 && sh experiments/cutouts/arc_thrall/rr24_proof.sh production
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-24 && sh experiments/cutouts/arc_thrall/rr24_proof.sh review
```

Intended output root: `experiments/cutouts/arc_thrall/rr11/proof/`.
It contains `native_rest/`, `native/rr24_policy_report.json` (including GPU
donor provenance), `rr24_crops/` (44 collar/hem pages), `contact_sheets/`,
`idle_native/`, `production_native/{front,rear}/`,
`thrall_protagonist_idle.mp4` and `arc_thrall_review.mp4`.

## Open issues

Native rest/density records, shadows, GPU gates and visual inspection remain
with the director because this worker has no window-server access. Headless
probe loading proves executable loading and source selection, not renderer
pixels. The density record check still needs the native rebake stage. Incidental
macOS certificate/resource shutdown messages are retained in the raw logs.
