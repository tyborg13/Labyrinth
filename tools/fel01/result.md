# fel-01 implementation and proof

The final normal-Health census scored 65 player-turn starts in nine fights. All three seeds ended in Section I, so the selection produced three provisional samples under the three-per-section cap. The full six-section census and 12-fixture selection are open. A separate diagnostic campaign using the existing run_hunt Health override reached all six sections, and all 12 diagnostic checkpoints inspected through Continue matched the recorded combat fields.

## Requirements

1. `hunt.gd` extends the real-scene hunt. It scores each settled player turn before the hunt dispatches that turn's input. `board_score.gd` reads production tile polygons, sprite rectangles, painter order and rest alpha masks. The trace retains each turn. A fight retains its highest-scoring turn with a covered tile and a playable targeted card. An actual diagnostic turn with score 34 had no playable targeted card, so it could only supply the first two captures. `census.py` maximizes the combined score for 12 distinct fights while capping each section at three and representing all four fight kinds. [Census and tile contents](census.md)
2. `checkpoint.gd` calls the normal explicit save and copies its durable run and profile files. `resume_probe.gd` stages those bytes in isolated storage and boots the production Continue branch, which calls `ProgressionStore.load_checkpoint_for_resume` and installs the run. It compares the live combat boundary, units, positions, surfaces, intents and ordered hand with the recorded witness. All three normal-Health samples passed. The separate diagnostic cohort returned `FEL01 WITNESS PASS states=12`.
3. `native.sh` uses `visual_probe_runner.py` and the 1920×1080 SubViewport pattern, 100% UI scale and `LABYRINTH_CEL_LOOK=all`. It captures rest, settled tile-hover fade, and the first playable targeted card aimed over the same tile. The probe writes those three PNGs and a 5760×1080 contact sheet per fixture. It prints the validated PNG paths individually. The three sample paths passed headless. Each sampled hover tile was outside the selected card's legal target set, so the proof exercises the active aiming UI at an invalid endpoint. Windowed proof and PNGs are pending.

## Normal-Health census

| Fixture | Seed | Section, zero based | Fight | Kind | Turn | Stacked | Covered tiles | Covered units | Score | Hover |
|---|---:|---:|---|---|---:|---:|---:|---:|---:|---|
| 01-s0-seed15-0-0_2-t2 | 15 | 0 | 0-0_2 | Normal | 2 | 1 | 11 | 3 | 18 | (3, 6) |
| 02-s0-seed17-0--1_1-t2 | 17 | 0 | 0--1_1 | Normal | 2 | 1 | 13 | 2 | 18 | (2, 4) |
| 03-s0-seed17-0-2_-1-t5 | 17 | 0 | 0-2_-1 | Normal | 5 | 1 | 11 | 2 | 16 | (3, 5) |

The selected state directories are under `tools/fel01/samples/`. The final campaign took 74.697 seconds wall clock. Seed 15 scored 24 turns over three fights, seed 16 scored 19 over three fights, and seed 17 scored 22 over three fights. Earlier normal-Health trials used earlier driver revisions. All ended in Section I, including seed 12 during the first dragon fight.

| Seeds | Wall seconds | Outcome | Logs |
|---|---:|---|---|
| 3 | 10.444 | Defeat after 32 decisions | [Godot log](/private/tmp/labyrinth_codex/fel01-natural-seed3.log) |
| 1 | 28.028 | Defeat after 60 decisions | [Godot log](/private/tmp/labyrinth_codex/fel01-policy-seed1.log) |
| 8–10 | 57.475 | Three defeats | [Campaign report](/private/tmp/labyrinth_codex/fel01-policy-campaign/report.md) |
| 12–14 | 146.583 | Three defeats | [Campaign report](/private/tmp/labyrinth_codex/fel01-policy-campaign2/report.md) |
| 15–17 | 74.697 | Three defeats | [Campaign report](/private/tmp/labyrinth_codex/fel01-natural-final/report.md) |

The final census selection returned `FEL01 CENSUS INCOMPLETE candidates=9 provisional=3 missing_sections=[1, 2, 3, 4, 5]`. Raw Godot logs are available for [seed 15](/private/tmp/labyrinth_codex/fel01-natural-final/seed-000015/godot.log), [seed 16](/private/tmp/labyrinth_codex/fel01-natural-final/seed-000016/godot.log) and [seed 17](/private/tmp/labyrinth_codex/fel01-natural-final/seed-000017/godot.log).

## Resume and capture dry run

```text
FEL01 RESUME PASS 01-s0-seed15-0-0_2-t2 boundary units positions surfaces intents hand
FEL01 PHASES PASS 01-s0-seed15-0-0_2-t2 rest hover=(3, 6) fade=1 card=quick_stab hover_is_legal_target=false
FEL01 RESUME PASS 02-s0-seed17-0--1_1-t2 boundary units positions surfaces intents hand
FEL01 PHASES PASS 02-s0-seed17-0--1_1-t2 rest hover=(2, 4) fade=1 card=shadow_step hover_is_legal_target=false
FEL01 RESUME PASS 03-s0-seed17-0-2_-1-t5 boundary units positions surfaces intents hand
FEL01 PHASES PASS 03-s0-seed17-0-2_-1-t5 rest hover=(3, 5) fade=1 card=sidestep_slash hover_is_legal_target=false
FEL01 DRY RUN PASS states=3
```

[Full dry-run log](/private/tmp/labyrinth_codex/fel01-final-samples-dry.log)

### Diagnostic coverage with the stock hunt Health override

The three early diagnostic runs used the stock hunt's 9,999 starting Health, which persists into the fixture UI. They used earlier scorer revisions. The 12 diagnostic saves remain in `/private/tmp/labyrinth_codex/fel01-diagnostic-bundle` for the checkpoint evidence. The full capture dry run stopped at the fifth fixture when the resumed hand had no playable targeted card. The witness-only pass compared all 12.

| Section, zero based | Normal | Objective | Guardian | Dragon |
|---:|---:|---:|---:|---:|
| 0 | 10 | 2 | 0 | 3 |
| 1 | 7 | 1 | 3 | 3 |
| 2 | 11 | 2 | 1 | 2 |
| 3 | 7 | 1 | 0 | 2 |
| 4 | 9 | 1 | 0 | 1 |
| 5 | 4 | 0 | 1 | 1 |

| Seed | Wall seconds | Exact result |
|---:|---:|---|
| 1 | 1,034.227 | `RUN HUNT: seed=1 outcome=fight_limit decisions=2618` |
| 8 | 502.646 | `RUN HUNT: seed=8 outcome=fight_limit decisions=1506` |
| 12 | 884.450 | `RUN HUNT: seed=12 outcome=victory decisions=2106` |

Direct-run wall times are measured from trace creation to summary write. Logs for [seed 1](/private/tmp/labyrinth_codex/fel01-census-001-seed1.log), [seed 8](/private/tmp/labyrinth_codex/fel01-census-seed8.log), [seed 12](/private/tmp/labyrinth_codex/fel01-census-seed12.log), the [diagnostic dry run](/private/tmp/labyrinth_codex/fel01-diagnostic-dry.log) and all [12 diagnostic witnesses](/private/tmp/labyrinth_codex/fel01-diagnostic-witness.log) are retained.

## Python and tooling checks

- Default Python group via `python3 tools/run_python_suite.py --shards 4 --changed-since HEAD --output-dir /private/tmp/labyrinth_codex/fel01-python-default` returned `SELECTED MODULES: 23 of 59`, `Ran 196 tests in 29.789s` and `OK`. The group included the rules-text lint. The runner reported `Operation not permitted` when updating its Git timing cache after the tests. [Python log](/private/tmp/labyrinth_codex/fel01-python-default.log)
- The isolated ranking check returned `FEL01 RANK CHECK PASS states=12 section_cap=3 distinct_fights=12 kinds=4 partial_cap=3`. `bash -n tools/fel01/native.sh` exited 0.
- The macOS Godot runs printed `ERROR: Condition "ret != noErr" is true. Returning: ""` in `get_system_ca_certificates` at startup. They continued through the outcomes and comparisons above.

## Chosen defaults

- Seeds and batches are listed above. The final hunt uses normal starting Health, `--no-embrace`, three concurrent seeds, 120 fixed FPS, the inherited ×8 scene time scale, fastest combat pacing, and eight settle frames. Each seed has a 1,800-second watchdog. Inherited limits are 400 decisions per fight, 50 unchanged fight decisions, 120 decisions per noncombat screen, and 20 scene seconds without a legal offer.
- The bot skips incidental menu exploration, prefers outward rooms, and estimates legal offers using the production pass forecast for up to 12 ranked options. Policy weights for Health, defeat, victory, closing distance, exit distance, kills, Block, control status and reducing enemy Block are 2.5, 500, 1,000, 0.35, 9, 5, 0.15, 0.7 and 0.2 respectively. These weights drive bot choices. Hover ties use the greatest single occlusion fraction, then board draw order. Equal fight scores retain the earliest eligible turn.
- The capture probe waits 0.35 seconds plus two frames after input. Its process timeout is 180 seconds.

## Proof for the design owner

Windowed command for the three provisional samples:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fel-01 && tools/fel01/native.sh --samples
```

Windowed command once `census.py` has packaged the full 12 into `tools/fel01/fixtures/`:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fel-01 && tools/fel01/native.sh
```

Each run writes to a fresh `tools/fel01/captures/native.*/` directory. No native run was attempted in this sandbox. For reference, the final headless hunt and sample dry run were:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fel-01 && python3 tools/run_hunt.py --task-id fel-01 --script tools/fel01/hunt.gd --fixed-fps 120 --seed 15 --runs 3 --processes 3 --health 0 --no-embrace --minutes 30 --seed-timeout 1800 --output-dir /private/tmp/labyrinth_codex/fel01-natural-final
cd /Users/borgerding/workspace/Labyrinth.worktrees/fel-01 && tools/fel01/native.sh --dry-run --samples
```

## Open issues

Normal-Health hunts have yet to reach Sections II–VI. The stock hunt override is available as diagnostic evidence and would require a design decision for the delivered capture cohort. There are no `TODO_DESIGN` placeholders in the current samples or implementation. The full 12-state selection and native PNG proof remain open. All changes are uncommitted under `tools/fel01/`.
