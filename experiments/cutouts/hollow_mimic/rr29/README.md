# rr-29 implementation handoff

All changes are uncommitted on `codex/rr-29`. The design owner owns commit,
peer review, native inspection and publication. No windowed process, art
creation, asset download or reviewer agent was used.

## Acceptance and numbered requirements

1. `mq11_front` / `mq11_rear` are maquette identity jobs with the exact supplied
   prompts, references and raw paintings. K=4; the front uses mq9's recorded
   palette parameters and `hollow_mimic/front/kit.json`, and the rear matches
   the new front. Both pair sheets were built and inspected. The director's
   PASS dated 2026-10-20 is transcribed, with re-judgment explicitly pending.
   Registry certification currently rejects the truthful staged
   `prompt_source` because the existing maquette validator requires a source
   under `spec/art_identity/maquettes/`. No exemption or invented source was
   added. `git mv` failed to create the common worktree index lock (Operation
   not permitted); equivalent checkout moves preserve every source byte, and
   remain unstaged for the director.
2. The new source cuts reconstruct both approved paintings with **0 differing
   pixels**, including hidden RGB. The hair plus mask stays rigid; rr20's
   other piece, skin, tuck and ownership rules are reused. All donor colours
   and rr28 continuations are recomputed. Fourteen additional torso source
   points deepen the covered tuck, and rear bolt/death receive clip-scoped
   own-torso texel copies traced from canonical tear failures. No provenance
   exemptions. The provided native receipt is `director_06`, not the brief's
   absent `director_04`; its opaque part-reference RGB exactly matches both
   staged mq11 part images. Original maquette/design files are untouched.
3. The generic `shoulder_pendulum` extension is opt-in. It uses the inherited
   landing clock, opposite same-side leg phase and half-step envelope, rotates
   at the real shoulder, samples the forearm at the protected 0.07 s delay,
   bends on its rest side by the supplied forward/back angle, and keeps the
   hand rigid with it. All other director bytes and non-move compiled tracks
   are unchanged. Independent authored FK and arc negative controls pass.
   The 2.5x full-cycle travel gate has two genuine shortfalls (table below).
4. Front `block`, near arm, **frames 9–41 inclusive** (zero based): the old
   static hand/sleeve depths are below the torso. The per-pose camera-side
   overlap rule promotes the hand and sleeve above it, then restores their
   original depths. The forearm shares rr20's existing sleeve mesh, so that
   mesh supplies its foreground depth. No other clip needs promotion in the current frame set.
   A geometric far-hand midline mutation also exercises the far-arm rule.
   Before/after crops are CPU diagnostics of approved paint, not native proof.
5. The native capture adapter, contracts, per-frame native depth validation,
   strict canonical tear census and production probes are prepared. No native
   renderer result is claimed. The final observed results and exact commands
   are in `proof/verification.json`; large logs and capture images stay local
   under `proof/`.

## Hand travel

Source pixels below are measured from presented Bone2D wrist paths relative
to the moving shoulder, so board root travel cannot inflate the result.
Multiply by screen scale 0.6035147873 for the measured board configuration.
Each same-side step is separately checked for non-collinearity.

| View / hand | rr20 slide | Pendulum | Ratio | 2.5x |
| --- | ---: | ---: | ---: | --- |
| Front near | 8.9443 | 20.6155 | 2.3049 | FAIL |
| Front far | 6.0828 | 17.4643 | 2.8711 | PASS |
| Rear near | 7.2801 | 20.6155 | 2.8318 | PASS |
| Rear far | 8.9443 | 20.6156 | 2.3049 | FAIL |

`proof/arm_measurements.json` retains exact numbers and every step's arc
measurement. `proof/draw_order_findings.json` lists every overlap frame and
its before/after crop path, e.g. `proof/draw_order/block_020_near_before.png`
and `_after.png`. Original rr20 paint crops are in
`proof/draw_order/rr20_block_020_near_before.png`, with all 33 source frames
and hashes in `proof/rr20_before_crops.json`.

## TODO_DESIGN and open decisions

- `TODO_DESIGN_pendulum_travel`: protected angles/lag do not meet two travel
  thresholds. No tuning was invented.
- `TODO_DESIGN_pendulum_terminal_lag`: exact 0.07 s delayed following still
  samples phase 0.9125 at the final frame. The protected data has no terminal
  recovery policy. No unrequested easing or compressed delay was added.
- `TODO_DESIGN_mq11_prompt_source`: resolve staged provenance versus the
  existing maquette source-path policy.
- `TODO_DESIGN_mq11_rear_residue`: the approved rear has green texels
  `(156,65) = [11,25,11,255]` and `(141,93) = [14,42,22,255]` in its head. Exact
  rest identity retains both; density treatment retains one in production.
  The rr20 residue gate reports these instead of recolouring protected art.

The first three fields are in `proof_status.json` / case integration data;
residue is a named field in `rr29_gates.py` and its generated gate report.
The native density check remains pending both director-rendered rest rebakes.
Historical rr20/rr28 assertions that pin old Mimic production data remain
intact; their failures are retained, not rewritten into passes.

## Chosen defaults

Only proof/test defaults were selected: crop zoom 4; crop padding 8 px; arc
line-departure threshold 0.25 source px; FK tolerance 0.0001; progress every
100 unique-frame checks; test process timeout 180 s; mutation angle 5 degrees
and frame 20; maximum dictionary failure-diagnostic representation 4000 chars.
The latter changes failure formatting only and prevents quadratic diffs of
large historic mesh dictionaries. Test fixture Git writes are refused. The
inherited disposable-commit skip applies when its qualified test ID matches;
other fixture writes are explicit failures in full discovery. The full
Python wrapper retags real nested Godot invocations to rr-29, preserving fake
engine IDs used by runner tests. All camera, canvas, capture budget, palette
and gait defaults otherwise come from the existing pipeline or director data.

The review sheet's non-player comparison slots use `kit.json.peers =
["hero_front", "hollow_mimic_front"]`, reusing the named hero and original
Mimic canon paint. These are proof-layout defaults only.


## Proof for the design owner

All commands start in the current worktree, use the mandated runners and
capture at 1920x1080 / 100% UI scale. Native and production probes construct
fixtures themselves; this brief requests no `tools/inspection_fixture.py`
command. A saved inspection fixture remains the design owner's phase.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-29 && sh experiments/cutouts/hollow_mimic/rr29_proof.sh density
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-29 && sh experiments/cutouts/hollow_mimic/rr29_proof.sh rest
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-29 && sh experiments/cutouts/hollow_mimic/rr29_proof.sh native
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-29 && sh experiments/cutouts/hollow_mimic/rr29_proof.sh sheets
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-29 && sh experiments/cutouts/hollow_mimic/rr29_proof.sh idle
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-29 && sh experiments/cutouts/hollow_mimic/rr29_proof.sh production
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-29 && sh experiments/cutouts/hollow_mimic/rr29_proof.sh review
```

Captures go to this case's `proof/native_rest/`, `native/`, `contact_sheets/`,
`idle_native/`, `production_native/` and `hollow_mimic_review.mp4`. The shell
script spells out each runner, proof contract and result manifest.

## Observed verification

- Focused rr29: `Ran 9 tests in 12.759s`; `OK`.
- Expanded focused (rr29, gait, rr28, shadows): `Ran 41 tests in 137.141s`;
  `FAILED (failures=2)` — the two historical rr28 Mimic production pins.
- Full Godot, once: `MAIN BODY ASSERTIONS: 378990`;
  `FULL SUITE RUNTIME: 494.912 seconds (budget 900 seconds)`;
  `TEST RESULT: PASS`.
- Full Python discovery, once: `Ran 1543 tests in 1634.532s`;
  `FAILED (failures=37, skipped=66)`;
  `RR29 PYTHON FULL SUITE: FAIL (110 Godot invocations forced to rr-29)`.
  Of those failures, 27 are refused fixture Git writes; one is the identity
  source-path policy; one is native density rest certification; seven pin
  historical Mimic production; one was the added/sorted standalone sampler
  registration. That registration was removed, original manifest bytes/order
  restored, and its focused check now reports `Ran 1 test in 0.002s`; `OK`.
  No failed historical assertion was rewritten.
- Identity tests: `Ran 111 tests in 37.056s`; `FAILED (failures=1)` from the
  registry's two staged-prompt provenance rejections. Registry command:
  `ART IDENTITY CHECK: FAIL (2 failures, 0 pending_reart warnings, 0 skipped replays)`.
- Canonical source/tear/material census:
  `RR29 CANONICAL TEAR FRONT: PASS (362 frames; 0 failing)`;
  `RR29 CANONICAL TEAR REAR: PASS (362 frames; 0 failing)`;
  `RR29 CANONICAL TEAR GATES: PASS (0 errors)`.
- Source/bone/direction/knee/support/reach/arm/depth gate:
  `RR29 SOURCE/BONE/DIRECTION/KNEE/SUPPORT/REACH/ARM/DEPTH GATES: FAIL (4 errors)`.
  These are the two travel shortfalls and rear-head residue in case/production.
- Each of six scenarios reports
  `RR29 PRODUCTION LOGIC: PASS (1316 frames; 0 errors)` (7896 total).
- `RR29 RR20 BEFORE CROPS: PASS (33 original frames; CPU diagnostic only)`.
  Projected bone-box decisions and actual presented sprite-box decisions agree
  in all 362 front frames: 0 differences.
- `RR29 OTHER FIGURES: PASS (5 checks)` after restoring the Briar Weaver proof
  receipt refreshed by the full suite. Its generated receipt was retained in
  this case's ignored logs; its original tracked bytes are restored.
- `TEST REGISTRATION AUDIT: PASS (763 scripts; full suite=415, quarantined=29, windowed probe=319)`.
  `git diff --check` and density helper import pass. Density `--check --only
  hollow_mimic_cutout` exits 1 for the two pending native rest rebakes.

Exact failure IDs, log hashes, changed-file inventory, source/screen-pixel
measurements and command/result records are in `proof/verification.json`.
The native-input folders observed under `tests/mq11_proof/director_06/` and
`director_08/` remain untouched and untracked; they are not worker-generated
runtime art or part of the implementation file inventory.

Reproduce the headless checks from the task worktree:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-29 && python3 -m unittest tests.test_rr29_mimic -v
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-29 && python3 tests/rr29_python_suite.py tests.test_rr29_mimic tests.test_gait01 tests.test_rr28_continuations tests.test_rr28_shadow
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-29 && python3 tools/godot_task_runner.py --task-id rr-29 --timeout 900 --stream -- godot --headless --path . --script tests/run_tests.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-29 && python3 tests/rr29_python_suite.py
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-29 && PYTHONPATH=tools python3 experiments/cutouts/hollow_mimic/rr29_gates.py
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-29 && OPENBLAS_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1 PYTHONPATH=tools python3 experiments/cutouts/hollow_mimic/rr29_gates.py --census
```

The main Godot full-suite result includes the extra sampler entry that was
subsequently removed; the final manifest exactly matches the original bytes.
The original ordering check was rerun and passes. The sampler remains covered
by the nine Python unit tests. Source pose rows and runtime data are unchanged
by that registration cleanup.
