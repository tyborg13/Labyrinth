# rr-45 — Frostglass Lancer shaft occlusion

Implementation is uncommitted on `codex/rr-45`. The design owner retains commits,
peer review, inspection fixtures and publication. No windowed command was run.

## Numbered requirements

1. **Find and identify every sampled show-through.** `rr45_depth.py` reads the
   protected mq-14 native specification (`measurements.json`), its camera,
   spear path, mounted breastplate/vambrace/gauntlet points and registered 3D
   cloak panel. The cutout animation retains that depth while moving the
   projected pieces. Cloth uses the nearest registered panel vertex; armour
   uses its mounted surface plane. This is a depth contract for this 2D rig,
   not a new 3D animation simulation. Screen overlap supplies coverage only.
   Padded hidden seam tucks are not treated as physical front surfaces.

   The check covers all 512 presented frames per view, every clip, and both
   rests. The prior rr-43 ordering produces 813 frame/piece findings: far arm
   368, far cloak 346, near cloak 88, torso 11. No gripping-fist violation was
   found; its existing foreground ownership is checked and retained.
   [FINDINGS.md](FINDINGS.md) lists every view, clip, zero-based frame, piece and
   bound crop. [before.json](before.json) holds the full inventory and SHA-256
   bindings. These current-baseline images are software rasters of actual
   headless runtime poses. [native_before.json](native_before.json) and its
   ten crops use exact retained rr-37 native pixels from the immutable rr-39
   archive; they are historical negative controls, not fresh rear-v2 proof.

2. **Fix the cause and retain a rigid, straight shaft.** The old ownership
   builder explicitly promoted the entire spear above the body to protect
   its crystal. Its replacement places the existing spear behind the body,
   cloak and far arm. The only production rendering data changes are the
   spear's `z_index`: front 23 → 3, rear 24 → 4, derived from existing layers.
   The builder retains all other grip/head layers. Source and production
   layouts agree. `rr45_preservation.py` permits only this layer delta while
   reconstructing the immutable rr-43 layout certificates. The rest/density
   report is resealed against the new bindings at zero pixel differences;
   the Lancer’s two density evidence hashes and two integration layout hashes are refreshed. No generic runtime,
   painting, texture, joint, transform,
   motion, timing, naming, gameplay, input, analytics or save change was made.
   Both rest assemblies remain identical, and the rr-43 ownership,
   transform and shaft-gap gates pass. [after.json](after.json) reports zero
   depth violations in 1,026 frames/rests. Software before/after pairs are at
   `../proof/logs/rr45_software/` (left baseline, right repair, 4× nearest).

3. **Native regression gate.** `rr45_occlusion.py` applies the same depth
   obligation to isolated native layers and verifies that their draw order
   explains the actual composed pixels at the overlaps. It requires current
   input bindings, complete unique inventories, exact image digests and sizes.
   Native capture now records source-space bone matrices to transport the
   cloak depth field. Old captures require recapture. The gate is called by
   `rr37_gates.py`, so `native`, `sheets` and `review` all enforce it. It rejects
   ten actual retained frame/piece defects (seven cloak, two far arm, one
   torso), while their rest controls remain clean. Restoring the prior layer
   on current front/rear poses also fails. Reversing only diagnostic 3D depth
   removes the obligation with identical screen pixels, proving the check is
   not an overlap-only heuristic. Fresh native success remains unverified in
   this sandbox and must be established by the commands below.

## Observed focused proof

- `Ran 26 tests in 188.210s` / `OK` for `tests.test_rr37_lancer`,
  `tests.test_rr43_lancer`, `tests.test_rr45_lancer`.
- `RR45 ALL FRAMES: PASS (1024 presented frames + 2 rests; 0 depth violations)`.
- `RR45 OLD DRAW ORDER MUTATION: PASS (front and rear rejected)`.
- `RR45 NATIVE NEGATIVE CONTROLS: PASS (10 real frame/piece failures; rest controls clean; stale proof rejected)`.
- `RR45 CRYSTAL VISIBILITY: PASS 1024 frames; 0 losses` (software comparison of every certified crystal-mask pixel before/after the layer change).
- Source and production: `RR37 ALL GATES: PASS (0 unique errors; native=False)`.
- D1–D5 each: `PASS (54 frames; native=False; defects=0)`.
- `RR37 PRESERVATION: PASS (5698 protected files; other rigs byte-identical)`.
- `FROSTGLASS GAMEPLAY PROBE: PASS`; `V2 BOARD SPRITE GEOMETRY` reports
  `cases:88`, `errors:[]`, `native:false`.
- Follow-up guards: `Ran 6 tests in 29.020s` / `OK`; rest/depth follow-up:
  `Ran 9 tests in 51.115s` / `OK`. Other-field and wrong-depth mutations still fail.
- `RR41 ALL FRONT ROUNDING: PASS (2048 UV/pose cases; 512 poses x 4 choices; every clip including move; no fresh native capture)`.
- Python resource audit: `ISOLATION AUDIT: 228 modules`; new
  `test_rr45_lancer` declares `[]`, audited as reads or per-test temp writes.

Focused logs are `/private/tmp/labyrinth_codex/rr45-focused.log`,
`rr45-source-gates.log`, `rr45-production-gates.log`, `rr45-cpu-defects.log`,
`rr45-gameplay-logic.log`. Gameplay manifest:
`/private/tmp/labyrinth_codex/rr45-gameplay-logic/manifest.json`.
The first gameplay invocation omitted `--logic-only` and timed out at 300s
waiting for a renderer signal. The corrected headless invocation passed.

Final suites (complete logs and SHA-256 bindings in `../../rr45_verification.json`):

- Godot: `MAIN BODY ASSERTIONS: 495687`; `FULL SUITE RUNTIME: 826.846 seconds (budget 900 seconds)`;
  `TEST RESULT: FAIL (4 failure(s))`. All 232 standalone programs completed.
  Failures are unchanged SPX emblem import-cache loading, undefined `GameData`
  in `enemy_no_action_suite.gd` (180s timeout), and its two FIX-11 dependents.
  Lancer packaging/motion programs pass. No failed assertion or failing source
  was rewritten.
- Python: `Ran 2118 tests in 2251.061s` / `FAILED (failures=1, skipped=66)`.
  The Lancer-containing shard passes all 209 tests with zero failures/errors;
  all enabled other-rig reference tests pass. The sole full-run failure is
  `test_sb02_movement.Movement.test_incremental_submission`: the unchanged
  movement planner peaked at 7335 µs against 4000 µs under suite load.
  An unchanged isolated repeat passes: `Ran 1 test in 17.802s` / `OK`.
  This does not relabel the full run as passing.
- Post-suite `RR37 PRESERVATION: PASS (5698 protected files; other rigs byte-identical)`.
- Initial full Python found two frozen-layout assertions and one old rest
  evidence binding. Their repair allows only the authorized spear-depth delta,
  retains the immutable art certificates, and reseals identical rest pixels.
  All pass in the final 209-test Lancer shard. The initial concurrent Godot
  run hit its 900s outer cap; the final run above completed separately.

Final logs: `../proof/logs/rr45_final/`. Complete changed-file list:
`../../rr45_changed_files.txt`. These checks do not replace director windowed proof.

## Proof for the design owner

Run at 1920×1080, 100% UI scale; judge both complete views/clips at 2–4×.
The sandbox has no macOS window-server access, so none was attempted.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-45 && LABYRINTH_TASK_ID=rr-45 sh experiments/cutouts/frostglass_lancer/rr37_proof.sh native
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-45 && LABYRINTH_TASK_ID=rr-45 sh experiments/cutouts/frostglass_lancer/rr37_proof.sh sheets
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-45 && LABYRINTH_TASK_ID=rr-45 sh experiments/cutouts/frostglass_lancer/rr37_proof.sh review
```

Outputs: `../proof/native/`, `../proof/contact_sheets/`,
`../proof/frostglass_lancer_review.mp4`; depth diagnostics and any failing
native crops are in
`../proof/production_case/proof/logs/shaft_occlusion.json` and
`../proof/production_case/proof/logs/shaft_occlusion_crops/`.
No `inspection_fixture.py` command was requested by the brief; fixture
preparation is assigned to the design owner.

## TODO_DESIGN placeholders

None. All player-visible inputs remain the approved ones.

## Chosen defaults

Only diagnostics/test values: 100,000 depth units per metre (10 µm precision,
matching epsilon); nearest-vertex batches of 2,048 source pixels; 8px crop
context; 1m diagnostic depth reversal; front guard frame 20 and rear lunge
frame 36 for layer mutations; software pairs front guard/20, lunge/32, cast/31 and rear idle/22,
lunge/36, cast/31, pin/45; 4× nearest enlargement. The 640px pose canvas, 1920×1080/100% proof, 60fps frame
inventory, task-runner timeouts and other fixture conventions are existing
project values. Native maquette dimensions and sprite layer relationships
are measured/derived inputs, not new tuning.

## Open issues

Fresh native captures and director inspection remain outstanding. The final
Godot run has four unchanged base failures; the full Python run has the
load-sensitive timing failure described above (isolated repeat passes).
