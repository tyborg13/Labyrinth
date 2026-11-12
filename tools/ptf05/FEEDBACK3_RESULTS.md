# ptf-05b feedback 3 — remove the Move-only notice

Implemented on `cf7b1bac6`; everything is uncommitted. No windowed/native run,
full suite, review, commit, push or publication was performed.

## Requirements

1. Removed `MoveOnlyTag`, its label, every notice `MOVE_*` constant and `move_*`
   state field, its entry/hold/exit updates, `move_in_frame()`, `move_only()` and
   the RunScene preview assignments. No dormant notice or call site remains.
   Valid movement floors retain the board's existing blue tint. The new proof
   checks that, with no active rejected-click reason, hovering a valid floor
   shows no notice for Low Sweep, Bloody Lunge and Sidestep Slash.
2. Rejected-click reasons, contour style, wording, animation, tile anchor,
   click-time popup drop and attack reach are unchanged from `cf7b1bac6`.
   A source comparison verifies unchanged bodies for `show_reason()`,
   `reason_frame()`, `reason_rest_rect()`, `reason()`, `reach_tiles()` and the
   remaining reason update path. RunScene changes only delete the three notice
   setup lines; its reach tint and combat shortcut logic are untouched.
   The notice-only shortcut suppression predicate was deleted with `move_only()`.
   Tectonic Maul's actual floor-strike plan remains and is checked separately.
3. The movie removes the entire Low Sweep segment, its timing state, floor-chain
   search and still. It preserves the four reason beats: Out of range, No line
   of sight, Can't see there, and the two quick Out-of-range clicks showing
   restart. The output/run id now uses `feedback3-movie`. The movie contract
   requires the three reason stills. The existing hand is retained, including
   unselected Low Sweep, so the reason beats' hand layout does not change.

## Files changed

- `scripts/target_click_feedback.gd`: notice and notice-only predicate removed.
- `scripts/run_scene.gd`: removed notice assignments from preview presentation.
- `tools/ptf05/reason_proof.gd`: removed notice-motion assertions; added quiet
  valid-floor hover checks and retained real Maul strike coverage.
- `tools/ptf05/fixture.gd`: removed notice reset fields; renamed the hover case
  to `floor_hover`.
- `tools/ptf05/capture.gd`, `capture_contract.json`: quiet `floor_hover.png`
  replaces the removed notice capture; no dangling field accesses remain.
- `tools/ptf05/movie.gd`, `movie.py`, `movie_contract.json`: four reason beats,
  three reason stills, feedback-3 outputs, no Low Sweep segment.
- `tools/ptf05/README.md`, `result.md`: current behavior, evidence and commands.

## Observed verification

Logs are under `/private/tmp/labyrinth_codex/ptf-05b/`. All final checks below exited 0.

| Check | Exact result | Log |
| --- | --- | --- |
| Reason proof | `PTF05 REASON PROOF: PASS (0 failures)` | `feedback3-reason-final.log` |
| Quiet valid floor hover | `PASS: hamstring_shot valid floor hover shows no notice`; same PASS for `bloody_lunge`, `sidestep_slash`, `tectonic_maul` | `feedback3-reason-final.log` |
| Shortcut suite | `PTF05 FOCUSED shortcut: PASS (0 failures)` | `feedback3-shortcut.log` |
| Targeting audit | `CARD TARGETING AUDIT: 309 cards, 700 upgrades; .../card_targeting_audit.json`; `PTF05 FOCUSED audit: PASS (0 failures)` | `feedback3-audit.log` |
| Tile tooltips | `BOARD TILE TOOLTIPS: PASS checks=217 failures=0` | `feedback3-tooltip.log` |
| Scene clock | `MAIN DOMAIN ASSERTIONS full_scene_clock_program: 1164`; `TEST RESULT: PASS` | `feedback3-clock.log` |
| Scene choices | `MAIN DOMAIN ASSERTIONS full_scene_choices_program: 772`; `TEST RESULT: PASS` | `feedback3-choices.log` |
| Capture and movie parsers | Godot banner, no parser errors; exit 0 | `feedback3-capture-parse.log`, `feedback3-movie-parse.log` |
| Python default group | `SELECTED MODULES: 20 of 56`; `Ran 189 tests in 33.692s`; `OK` | `feedback3-python.log` |
| UI identity lint | `Ran 25 tests in 5.377s`; `OK` | `feedback3-ui.log` |
| Movie headless rehearsal | `PTF05 REAL RUN MOVIE: PASS (continuous pointer sequence; three reason holds and quick restart)` | `feedback3-movie-validate.log` |
| Production preservation | `CF7 REASON / POPUP DROP / MOTION / REACH PRESERVATION: PASS` | tool output |
| Python movie parser | `MOVIE PYTHON PARSER: PASS` | tool output |
| Whitespace | `git diff --check`: no output; exit 0 | tool output |

The movie rehearsal reports nonintersecting reason/intent rectangles:

```text
PTF05 REASON / INTENT RECTS Out of range: reason=[P: (1062.0, 1147.636), S: (164.0, 30.0)] intent=[P: (1176.382, 1003.637), S: (232.0, 135.9999)]
PTF05 REASON / INTENT RECTS No line of sight: reason=[P: (860.0, 1036.382), S: (200.0, 30.0)] intent=[P: (992.3823, 1094.609), S: (232.0001, 136.0)]
```

These are headless layout checks, not new real-renderer appearance proof.
The approved popup drop in the base commit is preserved and both checks pass.

The initial new hover check reused the board's cached hover between fixture
installs. Clearing that cache before injecting each motion fixed delivery for
all four cards. No pre-existing failure assertions were weakened or rewritten.
No new Python module was added, so no resource-table entry is needed.

Commands run from this worktree:

```sh
python3 tools/godot_task_runner.py --task-id ptf-05b --stream -- godot --headless --path . --script tools/ptf05/reason_proof.gd
python3 tools/godot_task_runner.py --task-id ptf-05b --stream -- godot --headless --path . --script tools/ptf05/focused.gd -- shortcut
python3 tools/godot_task_runner.py --task-id ptf-05b --stream -- godot --headless --path . --script tools/ptf05/focused.gd -- audit
python3 tools/godot_task_runner.py --task-id ptf-05b --stream -- godot --headless --path . --script tests/board_tile_tooltip_test.gd
python3 tools/godot_task_runner.py --task-id ptf-05b --stream -- godot --headless --path . --script tests/suites/full_scene_clock_program.gd
python3 tools/godot_task_runner.py --task-id ptf-05b --stream -- godot --headless --path . --script tests/suites/full_scene_choices_program.gd
python3 tools/godot_task_runner.py --task-id ptf-05b --stream -- godot --headless --path . --check-only --script tools/ptf05/capture.gd
python3 tools/godot_task_runner.py --task-id ptf-05b --stream -- godot --headless --path . --check-only --script tools/ptf05/movie.gd
python3 tools/run_python_suite.py --shards 4 --changed-since HEAD --output-dir /private/tmp/labyrinth_codex/ptf-05b/feedback3-python-default
python3 tests/test_ui_identity_lint.py
python3 tools/ptf05/movie.py --validate
```

## Proof for the design owner

Exact windowed capture command (not run here):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/ptf-05b && LABYRINTH_CEL_LOOK=all python3 tools/ptf05/movie.py --capture
```

It prepares and verifies a real `inspection_fixture.py --scenario combat` save,
uses the existing cel look at 1920x1080 and 100% UI scale, then captures PNG movie
frames using `--write-movie` and `--fixed-fps 30` through the visual probe runner.
The two popup-separation assertions and rectangle reporting are retained.

Output root: `/private/tmp/labyrinth_codex/ptf-05b/feedback3-movie/`:

- `frames/movie*.png`
- `stills/out_of_range.png`, `stills/line_of_sight.png`, `stills/dark.png`
- `fixture.json`, `fixture.log`, `capture-manifest.json`

Previous feedback-1/2 movies remain untouched. No Move-only still is required or
written. Owner-run capture and inspection remain pending.

## TODO_DESIGN placeholders

None.

## Chosen defaults

No new values. Proof fixtures, pointer timing and capture timeout are inherited;
only the proof case name and task-local output/run names change. Production
presentation values are retained exactly; removed notice values are deleted.

## Open issues / environment

No production issue is known. Windowed proof remains owner-run. Godot emits its
existing macOS certificate and HUD anchor warnings; the tooltip check warns
about the existing missing `bramble` glossary entry. Python passes but cannot
write its optional timing cache outside the sandbox. No full suites were run.
