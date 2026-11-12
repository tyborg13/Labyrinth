# ptf-05b implementation and proof

All changes are uncommitted. No windowed/native run, review, Git metadata write,
queue edit, or publication was performed. Output root:
`/private/tmp/labyrinth_codex/ptf-05b/`.

## Requirements

1. Restored the exact RunScene/board integration hunks from `8a246be34` that
   were absent in the supplied working files. No ptf-03 body targeting was added:
   production `_tile_at_point` still resolves floor polygons. Replaced missing
   ptf-03 proof imports with `proof_base.gd` and the focused invocation runner
   `focused.gd`. Original shortcut/targeting suite assertions are unchanged.
2. Capture points use the intended floor's centre. Every capture asserts the
   production hit-test result before delivering motion, the RunScene hover after
   settling, and the final hover immediately before saving. The headless reason
   proof independently delivers real viewport motion for all eleven capture
   cases and checks both floor hit-testing and the resulting hover.
3. Ran all requested focused programs, Python default group, UI identity lint,
   and the capture parser. The clock failure is recorded below; no assertion was
   rewritten. No full suite was run (Python runner unit tests print mocked
   full-suite invocation commands; those are test fixtures).

## Observed checks

| Check | Exact result | Log under output root |
| --- | --- | --- |
| Reason proof including eleven floor hovers | `PTF05 REASON PROOF: PASS (0 failures)`; exit 0 | `reason-proof-final.log` |
| Focused shortcuts | `PTF05 FOCUSED shortcut: PASS (0 failures)`; exit 0 | `shortcut-final.log` |
| Focused targeting | `CARD TARGETING AUDIT: 309 cards, 700 upgrades; .../card_targeting_audit.json`; `PTF05 FOCUSED audit: PASS (0 failures)`; exit 0 | `audit-final.log` |
| Capture parser | Godot 4.6.1 banner, no parser errors; exit 0 | `capture-parse.log` |
| Tile tooltip | `BOARD TILE TOOLTIPS: PASS checks=217 failures=0`; exit 0 | `tooltip.log` |
| Scene choices | `MAIN DOMAIN ASSERTIONS full_scene_choices_program: 772`; `TEST RESULT: PASS`; exit 0 | `choices.log` |
| Scene clock | `MAIN DOMAIN ASSERTIONS full_scene_clock_program: 1164`; `TEST RESULT: FAIL (2 failure(s))`; exit 1 | `clock.log` |
| Python default | `SELECTED MODULES: 20 of 56`; `Ran 189 tests in 37.097s`; `OK`; exit 0 | `python.log`, `python-default/summary.json` |
| UI identity lint | `Ran 25 tests in 6.121s`; `OK`; exit 0 | `ui-final.log` |
| Python isolation audit | `ISOLATION AUDIT: 56 modules; /private/tmp/labyrinth_codex/ptf-05b/python-audit/isolation-audit.md`; exit 0 | `python-audit.log` |

Commands (from this worktree):

```sh
python3 tools/godot_task_runner.py --task-id ptf-05b --stream -- godot --headless --path . --script tools/ptf05/reason_proof.gd
python3 tools/godot_task_runner.py --task-id ptf-05b --stream -- godot --headless --path . --script tools/ptf05/focused.gd -- shortcut
python3 tools/godot_task_runner.py --task-id ptf-05b --stream -- godot --headless --path . --script tools/ptf05/focused.gd -- audit
python3 tools/godot_task_runner.py --task-id ptf-05b --stream -- godot --headless --path . --check-only --script tools/ptf05/capture.gd
python3 tools/godot_task_runner.py --task-id ptf-05b --stream -- godot --headless --path . --script tests/board_tile_tooltip_test.gd
python3 tools/godot_task_runner.py --task-id ptf-05b --stream -- godot --headless --path . --script tests/suites/full_scene_clock_program.gd
python3 tools/godot_task_runner.py --task-id ptf-05b --stream -- godot --headless --path . --script tests/suites/full_scene_choices_program.gd
python3 tools/run_python_suite.py --shards 4 --changed-since HEAD --output-dir /private/tmp/labyrinth_codex/ptf-05b/python-default
python3 tests/test_ui_identity_lint.py
python3 tools/run_python_suite.py --shards 4 --audit-only --output-dir /private/tmp/labyrinth_codex/ptf-05b/python-audit
```

No new Python modules were added; the shared resource table needs no entry.
The initial reason proof stopped at missing `_click_feedback` before integration
was restored; it was terminated and replaced by the passing runs above.

## Proof for the design owner

Run exactly this windowed command (not run in this sandbox), with the same eleven
captures as ptf-05, at 1920x1080 and 100% UI scale:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/ptf-05b && LABYRINTH_CEL_LOOK=all python3 tools/visual_probe_runner.py --task-id ptf-05b --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --proof-contract tools/ptf05/capture_contract.json --result-manifest /private/tmp/labyrinth_codex/ptf-05b/capture-manifest.json tools/ptf05/capture.gd
```

Expected capture directory (not generated here):
`/private/tmp/labyrinth_codex/ptf-05b/captures/`.
Names: `out_of_range.png`, `line_of_sight.png`, `dark.png`, `too_far.png`,
`blocked.png`, `invalid.png`, `surface.png`, `move_only.png`, `strike.png`,
`reach.png`, `maul_floor_strike.png`. The existing eleven-image contract is unchanged.
No inspection-fixture command was requested; fixture preparation belongs to the owner.

## TODO_DESIGN placeholders

None. Production visual values, wording, tuning, assets, and timing are unchanged.

## Chosen defaults

Proof-only floor-centre sampling replaces exposed-corner sampling. The local base
retains the 1920x1080 viewport, eight settling frames, and enemy tile `(4,4)` for
its shortcut fixture; these are named constants. New script UID sidecars identify
only the two proof helpers. All existing fixture values are retained.
Task-local output paths now use `ptf-05b`.

## Open issues and environment

The clock program fails twice at `Umbra keeps the still Unknown Presence texture`
in the unmodified `turn_order_lifetime_suite.gd` assertions. See baseline comparison
below. It is not reported as passing.

The tooltip program warns `Missing glossary definition: bramble`. Choices emits
existing choice-overlay minimum-size warnings. Godot emits the macOS certificate
warning. Python passes but cannot write its optional timing cache outside this
sandbox: `Cannot update untracked timing cache /Users/borgerding/workspace/Labyrinth/.git/labyrinth-test-timings/python-suite.json: [Errno 1] Operation not permitted`.
Fresh real-renderer captures and owner inspection remain outstanding.

Baseline comparison: temporarily reversed only the exact ptf-05 production patch,
ran the same clock command, and restored both files byte-for-byte in a `finally`
block. `clock-baseline.log` reports `MAIN DOMAIN ASSERTIONS full_scene_clock_program: 1164`
and `TEST RESULT: FAIL (2 failure(s))`, with the identical two Unknown Presence
texture assertions; exit 1. Thus this failure is present without ptf-05 integration.
No baseline assertions, portrait assets, or portrait presentation code were changed.

Final production-hunk reverse dry-run: `Exact ptf-05 production hunks present: True`.
Focused trailing-whitespace scan found no issues. `git diff --check` completed
with no output and exit 0. No ptf-03 imports or body-target helper references
remain in the executable ptf-05 proof scripts.
