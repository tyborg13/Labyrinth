# ptf-06 combined-gate failure isolation

Baseline: this worktree's ptf-06 HEAD `73c796805`, compared with the reported combined HEAD `456e3e579`. Every listed program ran here before production edits, through `tools/godot_task_runner.py --task-id ptf-06 --stream -- godot --headless --path . --script <program>`. The enemy-intent assertions were extracted into a focused entry point calling only `enemy_intent_continuity_suite.run`; the main/full suite was not invoked.

## Attribution

“Failed alone” records the initial reproduction, before the fixes or texture-cache bootstrap.

| Program | Failed alone | Cause | Fix / outcome |
|---|---|---|---|
| `warband_test` | No | Combined-only layout golden failures do not reproduce. | Unchanged; `Warband suite: 0 failures`. |
| `snare_test` | No | Combined-only layout golden failures do not reproduce. | Unchanged; `Snare suite: 0 failures`. |
| `save_resume_boundary_test` | Yes | New canonical `omen:tithe_of_ash` discovery IDs collide with the legacy vocabulary neutralizer; the old blanket vocabulary scan also rejects this current authored ID. | Preserve exact catalog omen IDs during migration; exempt only exact serialized current omen IDs in the legacy scan. `TEST RESULT: PASS — committed save/resume boundary matrix`. |
| `departed_run_cleanup_test` | Yes | Profile migration rewrites that same canonical discovery ID, breaking saved progression equality. | Same production migration fix; no cleanup code or assertion changes. Three cases, `errors: []`, `orphans: 0`. |
| `event_feedback_test` | Yes | The test selects the last tooltip descendant, now a nested keyword panel. That produces both the width failure and Label-to-TextureRect script error. | Identify the outer reward panel by `reward_id`. Keep the 420 px minimum, 128 px icon, and ornament assertions intact. `Event feedback suite: 0 failures`. |
| `flurry_retirement_test` | Yes | Its shared equipment-tooltip test expects the original `PanelContainer` owner; ptf-06 returned an HBox. | Restore the owner type with a zero-margin transparent outer panel, retaining the approved card/keyword layout and metadata. `PASS (8944 checks, 0 failures)`. |
| `glossary_test` | Yes | Same equipment-tooltip owner regression. | Same production fix; shared assertion unchanged. `PASS (6513 checks, 0 failures)`. |
| `board_tile_tooltip_test` | Yes | Same shared equipment-tooltip owner regression. | Same production fix; board hover code and shared assertion unchanged. `PASS checks=217 failures=0`. |
| `suites/full_scene_choices_program` | No | Combined-only campfire failures do not reproduce. | Unchanged; passes alone. |
| `suites/full_scene_clock_program` | Yes, environment only | Two Unknown Presence `resource_path` assertions fail while the fresh worktree lacks its imported texture; source-image fallback has no resource path. None of the combined Wait/copy failures reproduce here. | Import the existing texture into an isolated minimal cache project and copy only its ignored import artifacts. No clock code, asset, sidecar or assertion changes. See the post-import result below. |
| Enemy-intent continuity assertions | No | Combined-only named-intent/row failures do not reproduce. | Unchanged; `1918 checks, 0 failures`, covering 44 enemy types and 274 authored intent resolutions. |

The clock program's cold-cache failure is the only initial branch-local failure not caused by ptf-06. It is kept separate from the six programs fixed by this patch.

## Changes

- `scripts/item_preview_builders.gd`: restore the framed owner API without changing its material, spacing, copy or keyword panels.
- `scripts/run_engine.gd`: preserve exact current raw/namespaced omen IDs before legacy string replacement.
- `tests/save_resume_boundary_test.gd`: narrow the retired-vocabulary pin to distinguish current authored omen IDs from retired content. Unknown legacy IDs still must migrate.
- `tests/suites/event_feedback_suite.gd`: locate the owning reward tooltip explicitly rather than the last nested glossary tooltip.
- `tools/ptf06/focused_test.gd`: check every current omen ID survives profile/run migration, unknown retired IDs still migrate, and equipment tooltips retain their framed owner and keyword panels.
- `tools/ptf06/enemy_intent_test.gd` and UID: focused entry point for the main suite's relevant enemy-intent assertions.
- `tools/ptf06/recheck_programs.py`: standard-library runner for exactly the listed programs, with two workers and per-program logs.

No approved content values, card mechanics, artwork or player-facing defaults changed. No TODO_DESIGN placeholders were added. Tests use a three-fight synthetic omen counter; the only runner default is two isolated workers. Everything remains uncommitted.

## Reproduction and evidence

Initial commands and full logs: `/private/tmp/labyrinth_codex/ptf-06/combined-feedback/before/results.json` and adjacent `*.log` files. Recheck results for the six affected programs: `/private/tmp/labyrinth_codex/ptf-06/combined-feedback/after/results.json`.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/ptf-06 && python3 tools/ptf06/recheck_programs.py --output-dir /private/tmp/labyrinth_codex/ptf-06/combined-feedback/recheck
cd /Users/borgerding/workspace/Labyrinth.worktrees/ptf-06 && python3 tools/godot_task_runner.py --task-id ptf-06 --timeout 60 --stream -- godot --headless --path . --script tools/ptf06/focused_test.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/ptf-06 && python3 tools/godot_task_runner.py --task-id ptf-06 --timeout 60 --stream -- godot --headless --path . --script tools/ptf06/affected_test.gd
```

Focused result: `PTF06 focused: 0 failures` (`combined-feedback/focused.log`). Only the listed programs and ptf-06 focused checks ran; no Python or full Godot suites were run in this round.

The fresh worktree needed its script-class cache. The broad headless import was stopped after that cache was available; it is not claimed as a successful complete import. For the clock resource-path assertions, a minimal project contained only the existing `umbra_presence.png` and its existing `.import` settings. Its headless import ran through the mandatory task runner and exited 0. Only ignored `umbra_presence.png-*` cache artifacts were copied back. Logs and fixture are under `combined-feedback/clock-import*`; no source asset or import sidecar changed.

Post-import clock result: `MAIN DOMAIN ASSERTIONS full_scene_clock_program: 1164`; `TEST RESULT: PASS` (26.891 seconds), recorded in `/private/tmp/labyrinth_codex/ptf-06/combined-feedback/clock-after-import/results.json`. This confirms its initial failure was the missing cache, not ptf-06 behavior. All requested programs pass their latest individual run; no branch-local failures remain unresolved.

The second owned focused entry point reports `PTF06 affected search and inline suites: 0 failures` in `combined-feedback/affected-focused.log`. The choices program's initial branch-only run reports `772` assertions and `TEST RESULT: PASS`. `git diff --check` passes. Tracked changes are confined to the files listed above and task documentation; no source assets or import sidecars changed.
