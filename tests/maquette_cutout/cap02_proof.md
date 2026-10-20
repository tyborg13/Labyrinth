# cap-02 implementation and proof

All changes are uncommitted in `codex/cap-02`. Implementation, focused proof and
this handoff are complete; inspection, commit, review and publication belong to
the design owner.

## Requirements and cause

1. **Whole-run plan.** Every production writer now replays its unchanged clip
   loop in logic mode before saving any native frame. Each capture callback
   contributes the actual padded action-canvas screen rectangle, using the
   board's presentation center/texture origin and current canvas transform.
   The union receives the existing outward rounding and 16 px margin once.
   The native pass uses a fresh scene and one fixed crop. Planning rows, gait
   samples and reference rigs are cleared; planning failures are retained.
   Escapes stop the process before saving the offending frame and name the
   scenario (output directory), clip, frame, canvas and crop. No manifest,
   encoder, gate, renderer-pixel normalization, gameplay or input rule changed.

   The confirmed cause is the room-to-combat board-centering tween, not only
   actor movement. The original diagnostic run observed Capacitor's canvas at
   y=172.3447 after its initial crop started at y=190, and rear Mimic's canvas at
   y=247.0516 after its initial crop started at y=256. Their actor tiles were
   unchanged. See `/tmp/cap02-cause/{capacitor,mimic}.log` and the director logs
   named in the brief. The initial crop was computed during the moving board
   transform. Source: `scripts/run_scene.gd:_sync_board_view_rect`.

   Cap-01's conservative fixture/facing envelope is retained in board-local
   coordinates and transformed throughout the replay. The existing room
   centering endpoint also contributes its transform: a recreated native scene
   can sample the cubic tween earlier than the logic pass. This uses the
   existing `_board_centering_target`; no duration, margin or motion is tuned.
   An intermediate rear-Mortar check caught this earlier-replay case at idle
   frame 0; the endpoint regression and final rerun pass after the correction.

2. **Regression.** The new fixture extends the real Mimic production writer and
   exercises its two-pass orchestration. Four frames span two scenarios,
   entrance motion after the first frame, movement to another tile and copied
   action texture-origin travel. The initial fixture-only crop reproduces the
   escape. The complete plan is `[269, 156, 1045, 744]` for all four frames, with
   exact decoded lossless WebP bytes. Tests also cover earlier native replay,
   conservative facing bounds following the board, run-state reset, no writes
   during planning, fresh scene/row isolation, and contextual failure before
   writing. A disposable mutation that drops observed frame bounds fails.

3. **Equivalence.** All four available saved cap-01 rectangles are contained.
   The planned rectangles grew; they are not unchanged. Exact comparison:
   `/tmp/cap02-endpoint/equivalence.json`.

   | Run | cap-01 saved crops | Final planned crop |
   | --- | --- | --- |
   | Seer | `[635,104,576,537]`, `[635,113,576,536]` | `[635,63,576,615]` |
   | Mortar front | `[559,116,653,541]`, `[559,123,653,541]` | `[559,72,653,619]` |

   Baselines were read, not modified:
   `/tmp/cap01-seer-plan/logic_frames.json`,
   `/tmp/cap01-review-seer-crop/logic_frames.json`,
   `/tmp/cap01-mortar-plan/logic_frames.json`, and
   `/tmp/cap01-review-mortar-crop/logic_frames.json`.

4. **Focused proof only.** The exact results below were observed. No full suite
   or windowed run was attempted. No peer review, Git mutation or publication
   was performed.

## Files changed

- `tests/maquette_cutout/capture_storage.gd`: frame union, conservative board
  transforms, plan/write separation, contextual containment failure.
- Production writers: `tests/maquette_cutout/production_capture.gd` and
  `tests/rr{07,10,11,12,17,18,20,21,22}/production_capture.gd`: shared helper
  integration, unchanged scenario-loop extraction, pre-pass and state reset.
  A direct source comparison confirmed all ten extracted clip loops equal
  their original bodies, including Mortar's prebattle step.
- `tests/maquette_cutout/production_crop_plan_test.gd`: real-writer synthetic
  replay and exact WebP/geometry checks.
- `tests/test_production_crop_plan.py`: subprocess success/failure and omitted
  frame mutation checks.
- `tests/maquette_cutout/cap02_proof.md`: this handoff.

## Observed focused proof

All commands ran from this worktree, with `LABYRINTH_TASK_ID=cap-02` for Python
discovery and the mandatory task runner for every Godot process.

| Command/check | Exact result | Log |
| --- | --- | --- |
| `python3 -m unittest discover -s tests -p 'test_production_crop_plan.py' -v` | `Ran 3 tests in 9.489s` / `OK` | `/tmp/cap02-crop-endpoint-tests.log` |
| `python3 -m unittest discover -s tests -p 'test_native_frames.py' -v` | `Ran 15 tests in 5.993s` / `OK` | `/tmp/cap02-endpoint-native-tests.log` |
| `python3 -m unittest discover -s tests -p 'test_capture*.py' -v` | `Ran 35 tests in 7.516s` / `OK` | `/tmp/cap02-focused-capture.log` |
| Synthetic writer | `PRODUCTION CROP PLAN: PASS (0 failures; 4 frames; 2 scenarios)` | `/tmp/cap02-endpoint-synthetic.log` |
| Deliberate post-plan escape | `PRODUCTION CROP ESCAPE: REJECTED (scenario=rear/copied_action clip=mirror frame=99)`; expected exit 1, no frames written | `/tmp/cap02-crop-escape.log`; also exercised by the final Python tests |
| Seer | `MAQUETTE PRODUCTION LOGIC: PASS (1441 frames)` | `/tmp/cap02-endpoint-seer.log` |
| Mortar front | `MAQUETTE PRODUCTION LOGIC: PASS (1516 frames)` | `/tmp/cap02-endpoint-mortar-front.log` |
| Mortar rear | `MAQUETTE PRODUCTION LOGIC: PASS (1516 frames)` | `/tmp/cap02-endpoint-mortar-rear.log` |
| Capacitor | `MAQUETTE PRODUCTION LOGIC: PASS (1011 frames)` | `/tmp/cap02-endpoint-capacitor.log` |
| Rear Mimic, whirlwind_slash | `MAQUETTE PRODUCTION LOGIC: PASS (1316 frames)` | `/tmp/cap02-endpoint-mimic-rear.log` |
| Containment comparison | Four `CAP02 CONTAINMENT ...: PASS` results | `/tmp/cap02-endpoint/equivalence.json` |
| `git diff --check` | exit 0, no output | current worktree |

The five production reports are
`/tmp/cap02-endpoint/{seer,mortar-front,mortar-rear,capacitor,mimic-rear}/logic_frames.json`.
Their final crops are respectively `[635,63,576,615]`, `[559,72,653,619]`,
`[708,184,728,582]`, `[565,118,716,608]`, and `[789,193,492,533]`.
Every final production subprocess exited 0. These are geometry/logic checks,
not renderer proof.

The synthetic persisted capture is `/tmp/cap02-endpoint/synthetic/`, containing
`native_storage.json`, four `frame_*.webp` files and full-reference PNGs.

Reproduce synthetic proof:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/cap-02 && python3 tools/godot_task_runner.py --task-id cap-02 --stream -- godot --headless --path . --script tests/maquette_cutout/production_crop_plan_test.gd -- --output /tmp/cap02-owner/synthetic
```

Reproduce production geometry checks using the appropriate script/options:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/cap-02 && python3 tools/godot_task_runner.py --task-id cap-02 --stream -- godot --headless --path . --script tests/rr10/production_capture.gd -- --type hoarfrost_seer --logic-only --validate-crop --output /tmp/cap02-owner/seer
cd /Users/borgerding/workspace/Labyrinth.worktrees/cap-02 && python3 tools/godot_task_runner.py --task-id cap-02 --stream -- godot --headless --path . --script tests/rr22/production_capture.gd -- --type slag_mortar --logic-only --validate-crop --output /tmp/cap02-owner/mortar-front
cd /Users/borgerding/workspace/Labyrinth.worktrees/cap-02 && python3 tools/godot_task_runner.py --task-id cap-02 --stream -- godot --headless --path . --script tests/rr22/production_capture.gd -- --type slag_mortar --opposite --logic-only --validate-crop --output /tmp/cap02-owner/mortar-rear
cd /Users/borgerding/workspace/Labyrinth.worktrees/cap-02 && python3 tools/godot_task_runner.py --task-id cap-02 --stream -- godot --headless --path . --script tests/rr17/production_capture.gd -- --type storm_capacitor --logic-only --validate-crop --output /tmp/cap02-owner/capacitor
cd /Users/borgerding/workspace/Labyrinth.worktrees/cap-02 && python3 tools/godot_task_runner.py --task-id cap-02 --stream -- godot --headless --path . --script tests/rr20/production_capture.gd -- --type hollow_mimic --view rear --mirror-card whirlwind_slash --logic-only --validate-crop --output /tmp/cap02-owner/mimic-rear
```

## Proof for the design owner

The sandbox has no macOS window-server access. Run the existing director
sequences at 1920×1080, 100% UI scale:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/cap-02 && LABYRINTH_TASK_ID=cap-02 sh experiments/cutouts/hollow_mimic/proof.sh production
cd /Users/borgerding/workspace/Labyrinth.worktrees/cap-02 && LABYRINTH_TASK_ID=cap-02 sh experiments/cutouts/storm_capacitor/rr17_proof.sh
```

The first sequence covers both Mimic views and all three copied cards. The
second is the Capacitor director sequence requested in the brief. Their capture
paths are `experiments/cutouts/hollow_mimic/rr20/proof/production_native/<view>/<card>/`
and `experiments/cutouts/storm_capacitor/mq5/proof/production_native/`.

For isolated lossless-WebP production proof in fresh output folders, the exact
windowed commands and unchanged canonical gates are:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/cap-02 && python3 tools/visual_probe_runner.py --task-id cap-02 --no-headless --display-driver macos --audio-driver Dummy --timeout 900 --expect-size 1920x1080 --proof-contract tests/rr20/production_contract.json tests/rr20/production_capture.gd -- --type hollow_mimic --view rear --mirror-card whirlwind_slash --capture-encoding webp --output /tmp/cap02-windowed/mimic/rear/whirlwind_slash
cd /Users/borgerding/workspace/Labyrinth.worktrees/cap-02 && python3 -B experiments/cutouts/hollow_mimic/production.py --input /tmp/cap02-windowed/mimic/rear/whirlwind_slash/frames.json
cd /Users/borgerding/workspace/Labyrinth.worktrees/cap-02 && python3 tools/visual_probe_runner.py --task-id cap-02 --no-headless --display-driver macos --audio-driver Dummy --timeout 900 --expect-size 1920x1080 --proof-contract tests/rr17/production_contract.json tests/rr17/production_capture.gd -- --type storm_capacitor --capture-encoding webp --output /tmp/cap02-windowed/capacitor
cd /Users/borgerding/workspace/Labyrinth.worktrees/cap-02 && python3 -B experiments/cutouts/storm_capacitor/rr17_gates.py production --input /tmp/cap02-windowed/capacitor/frames.json --output /tmp/cap02-windowed/capacitor/verification.json
```

No inspection-fixture command was requested. Inspection for this capture-tool
change is the production capture proof above.

## TODO_DESIGN placeholders

None.

## Chosen defaults

Test-only geometry: board x=13.5, entrance y=70, room endpoint y=180, origin
`(400,300)`, tile step `(100,50)`, moved/escaped tiles `(5,4)` / `(12,4)`, texture
offsets `(-200,-120)` / `(0,400)`, four frames across two synthetic scenarios,
and failure frame 99. The test board uses the existing 255 px source / 512 px
action-canvas convention. Expected rectangles are derived oracles. The Python
subprocess budget is the named `PROOF_TIMEOUT_SECONDS = 180`. Production
numbers, timing, assets, encoding selection and the 16 px margin are unchanged.

## Open issues

- Actual windowed capture/proof remains with the design owner.
- The pre-existing RGB/RGBA `proof_png` blit warning and macOS CA-certificate
  warning remain observable in the storage/headless checks. The existing
  storage suite passes; its assertions and pixel checks were not weakened.
  Some pre-existing production fixtures also report ObjectDB leaks at exit.
- Crops are larger and production adds one logic replay. No performance
  benchmark was requested or run; the existing advisory targets are unchanged.
