# ptf-02 combined-trial failure triage

Branch tested: `codex/ptf-02`, HEAD `4d36d4576` (release `7cf181c7e` plus
ptf-02). Input log: `/private/tmp/labyrinth_codex/ptf-combined/gate_godot_456e3e579.log`.
All runs used `tools/godot_task_runner.py --task-id ptf-02 --stream` with
`godot --headless`. No full suites, Python suites, windowed runs or peer reviews
were run. All changes remain uncommitted.

"Fails on this branch" records the initial run before repair. For programs
that passed, the cause column describes the failure in the supplied combined
log; those failures were not reproduced or changed on ptf-02.

| Program | Fails on this branch | Cause | Fix |
| --- | --- | --- | --- |
| `warband_test` | No | Combined-only legacy combat-layout golden hashes for revisions 4 and 5 | None; all 192 legacy layouts pass here |
| `snare_test` | No | Same combined-only Warband legacy goldens | None; natural Snare entry and legacy goldens pass here |
| `save_resume_boundary_test` | No | Combined-only retired-vocabulary assertion after migration | None |
| `departed_run_cleanup_test` | No | Combined-only saved-run/profile equality assertion | None; three cases, zero errors and orphans here |
| `event_feedback_test` | No | Combined-only relic preview TextureRect/Label mismatch and minimum width | None |
| `flurry_retirement_test` | No | Combined-only collectible equipment tooltip contract | None |
| `glossary_test` | No | Combined-only collectible equipment tooltip contract | None |
| `board_tile_tooltip_test` | No | Combined-only collectible equipment tooltip contract | None |
| `suites/full_scene_choices_program` | Yes | Two stale 4-HP Linger expectations | Chip `+4 HP` → `+6 HP`; duplicate clicks heal the 10-HP fixture once to 16, rather than 14 |
| `suites/full_scene_clock_program` | No | Combined-only turn-clock copy, damage ink and unrevealed-lap suffix expectations | None |
| Main enemy-tooltip continuity assertions | No | Combined-only named intent/action-row expectations | None; isolated unchanged suite passes |

Programs failing on ptf-02 but not caused by ptf-02: **none**.
Production behavior is unchanged. Only two test pins in `tests/run_tests.gd`
were updated to the approved 6-HP heal; the duplicate-input assertion still
requires exactly one heal.

## Observed result lines

```text
Warband suite: 0 failures
Snare suite: 0 failures
TEST RESULT: PASS — committed save/resume boundary matrix
DEPARTED CLEANUP RESULT: {"cases":3,"draining_at_menu":true,"errors":[],"native":false,"orphans":0}
Event feedback suite: 0 failures
FLURRY RETIREMENT TEST RESULT: PASS (8914 checks, 0 failures)
GLOSSARY TEST RESULT: PASS (6513 checks, 0 failures)
BOARD TILE TOOLTIPS: PASS checks=217 failures=0
MAIN DOMAIN ASSERTIONS full_scene_choices_program: 772
TEST RESULT: PASS
TEST RESULT: PASS
PTF02 ENEMY INTENT CHECKS RESULT: PASS (1918 checks, 0 failures)
PTF02 FOCUSED RESULT: PASS (120006 checks, 0 failures)
PTF02 HEARTH CHECKS RESULT: PASS (279 checks, 0 failures)
PTF02 SAVED MAP RESULT: PASS (7 checks, 0 failures)
```

The second unqualified `TEST RESULT: PASS` is the clock program. The initial
choices run had exactly the two reported Linger failures, then the repaired
program exited 0. Every other listed program exited 0 on its initial run.
Expected save-failure injection messages and the sandbox system-CA lookup
message do not represent failing assertions.

Logs and command/exit-code manifests:
`/private/tmp/labyrinth_codex/ptf-02/combined-feedback/initial-map/`,
`initial-ui/`, and `fixed/`. Focused logs are `focused.log`,
`hearth_checks.log` and `saved_map.log` in the same parent directory.

## Reproduction

From `/Users/borgerding/workspace/Labyrinth.worktrees/ptf-02`:

```sh
python3 tools/ptf02/combined_failure_checks.py --phase reproduce
python3 tools/godot_task_runner.py --task-id ptf-02 --timeout 600 --stream -- godot --headless --path . --script tools/ptf02/focused.gd
python3 tools/godot_task_runner.py --task-id ptf-02 --stream -- godot --headless --path . --script tools/ptf02/hearth_checks.gd
python3 tools/godot_task_runner.py --task-id ptf-02 --stream -- godot --headless --path . --script tests/ptf02_saved_map_test.gd
```

The reproduction helper runs exactly the ten named child programs and the
isolated main enemy-intent continuity suite. It uses two concurrent processes
(a proof-only memory limit) and records every underlying runner command.
The enemy harness invokes the unchanged suite directly without starting the
full main body or its scheduler. A headless asset import was required for this
recreated worktree; a warm import generated the new harness's UID sidecar.

Changed files this round: `tests/run_tests.gd` (two pins),
`tools/ptf02/combined_failure_checks.py`, `tools/ptf02/enemy_intent_checks.gd`
and its UID, and this report. `git diff --check` passed.
No `TODO_DESIGN_` placeholders or unresolved ptf-02 failures remain.
