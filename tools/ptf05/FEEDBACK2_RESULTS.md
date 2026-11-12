# ptf-05b feedback 2

Implemented the clicked-tile reason anchor. Changes remain uncommitted. No
windowed/native run, full suite, peer review or publication was performed.
The owner's feedback-1 frame 49, frames 52/82/86 and `stills/out_of_range.png`
were inspected; the reason visibly merged into the intent title and token row.

## Requirements met

1. The reason's text box is horizontally centred on the clicked tile. Its rest
   top is 10 screen pixels below the front vertex of the current floor diamond.
   `reason_tile` is retained from the rejected click; each frame re-projects that
   tile's centre and polygon through the board transform. Pointer movement
   cannot move the notice. Pan and zoom can.
2. Removed `POINTER_REASON_OFFSET` and the pointer/controller placement split.
   `reason_rest_rect()` exposes the unanimated rest box for proof; the approved
   in-rise and out-drift are applied relative to it.
3. Kept the approved contour renderer, sizes, timing, easing, restart behavior,
   Move-only placement/motion, invalid sound dispatch, reason rules, reach tint,
   Maul exemption and all engine behavior. No palette, asset, balance, save or
   analytics change was made this round.

## Files changed this round

- `scripts/target_click_feedback.gd`: tile-front rest rectangle and 10 px gap;
  removes pointer-dependent reason positioning.
- `tools/ptf05/reason_proof.gd`: independent rest-box geometry, pointer-motion,
  production pan/zoom, controller parity and existing motion/semantic checks.
- `tools/ptf05/movie.gd`: reason/intent separation assertions for the two hovered
  foes, rectangle reporting and feedback-2 output path.
- `tools/ptf05/movie.py`: feedback-2 movie output, isolated run id and summary.
- `tools/ptf05/README.md`, `result.md`: current proof command and results.

Earlier feedback-1 implementation files remain uncommitted in this worktree;
these changes preserve them.

## Verification

Logs: `/private/tmp/labyrinth_codex/ptf-05b/feedback2-*`.

| Check | Observed result | Log |
| --- | --- | --- |
| Placement, motion and reason semantics | `PTF05 REASON PROOF: PASS (0 failures)` | `feedback2-reason-final.log` |
| Shortcut suite | `PTF05 FOCUSED shortcut: PASS (0 failures)` | `feedback2-shortcut.log` |
| Targeting audit | `CARD TARGETING AUDIT: 309 cards, 700 upgrades; .../card_targeting_audit.json`; `PTF05 FOCUSED audit: PASS (0 failures)` | `feedback2-audit.log` |
| Tile tooltips | `BOARD TILE TOOLTIPS: PASS checks=217 failures=0` | `feedback2-tooltip.log` |
| Scene clock | `MAIN DOMAIN ASSERTIONS full_scene_clock_program: 1164`; `TEST RESULT: PASS` | `feedback2-clock.log` |
| Scene choices | `MAIN DOMAIN ASSERTIONS full_scene_choices_program: 772`; `TEST RESULT: PASS` | `feedback2-choices.log` |
| Python default | `SELECTED MODULES: 20 of 56`; `Ran 189 tests in 33.813s`; `OK` | `feedback2-python.log` |
| UI identity lint | `Ran 25 tests in 5.835s`; `OK` | `feedback2-ui.log` |
| Existing capture / updated movie parser | Godot banner, no parser errors; exit 0 | `feedback2-capture-parse.log`, `feedback2-movie-parse-final.log` |
| Whitespace | `git diff --check`: no output, exit 0 | tool output |

The placement proof computes the expected bottom corner independently from all
projected polygon vertices. It checks the actual notice rectangle during hold,
a 200 px pointer change, production navigation zoom and an actual allowed board
pan. Targeting normally fits the board and suppresses navigation; the proof
briefly uses normal navigation presentation, then restores it and its transforms.
No combat state is modified for this geometry check.

Headless viewport mouse getters remain OS-backed after injected motion. The
proof host therefore supplies a named pointer value to `_current_mouse_position`
while also dispatching the viewport event. The getter changes by 200 px while
the notice remains fixed; the former pointer-based implementation would fail
this check. This is headless regression proof, not a native cursor claim.

The unchanged reason and Move-only numerical phase checks, reduced motion,
controller input, reach exclusions, state preservation and Maul checks still
pass. No Python test module was added; the resource table needs no new entry.

The additional headless real-scene movie rehearsal is **not passing**: the new
non-intersection assertion rejects its first Out-of-range witness. It reports:

```text
PTF05 REASON / INTENT RECTS Out of range: reason=[P: (1062.0, 1128.382), S: (164.0, 30.0)] intent=[P: (1176.382, 1003.637), S: (232.0, 135.9999)]
PTF05 REAL RUN MOVIE: FAIL: Tile-anchored reason avoids the hovered intent popup: Out of range
```

Logs: `feedback2-movie-validate.log` and `feedback2-movie-validate-final.log`;
exit 1. Emitting the missing dummy-renderer post-draw signal did not change
those rectangles, so that experimental harness change was removed. The reported
coordinates differ from the owner’s windowed feedback-1 captures and extend
below the viewport. The source of that geometry difference is unverified here.
The windowed movie retains the nonempty-rectangle and non-intersection assertions
for both foes; no alternate placement or relaxed assertion was introduced.
Actual windowed separation is pending the owner-run capture.

Commands used:

```sh
python3 tools/godot_task_runner.py --task-id ptf-05b --stream -- godot --headless --path . --script tools/ptf05/reason_proof.gd
python3 tools/godot_task_runner.py --task-id ptf-05b --stream -- godot --headless --path . --script tools/ptf05/focused.gd -- shortcut
python3 tools/godot_task_runner.py --task-id ptf-05b --stream -- godot --headless --path . --script tools/ptf05/focused.gd -- audit
python3 tools/godot_task_runner.py --task-id ptf-05b --stream -- godot --headless --path . --script tests/board_tile_tooltip_test.gd
python3 tools/godot_task_runner.py --task-id ptf-05b --stream -- godot --headless --path . --script tests/suites/full_scene_clock_program.gd
python3 tools/godot_task_runner.py --task-id ptf-05b --stream -- godot --headless --path . --script tests/suites/full_scene_choices_program.gd
python3 tools/godot_task_runner.py --task-id ptf-05b --stream -- godot --headless --path . --check-only --script tools/ptf05/capture.gd
python3 tools/godot_task_runner.py --task-id ptf-05b --stream -- godot --headless --path . --check-only --script tools/ptf05/movie.gd
python3 tools/run_python_suite.py --shards 4 --changed-since HEAD --output-dir /private/tmp/labyrinth_codex/ptf-05b/feedback2-python-default
python3 tests/test_ui_identity_lint.py
python3 tools/ptf05/movie.py --validate
```

## Proof for the design owner

Exact windowed command (not run here):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/ptf-05b && LABYRINTH_CEL_LOOK=all python3 tools/ptf05/movie.py --capture
```

This prepares and verifies the same real `inspection_fixture.py --scenario combat`
save, with the same cards, foes, crate and continuous pointer sequence as feedback
1. It uses the visual probe runner, existing cel-look variants, 1920x1080,
100% UI scale, `--write-movie .../frames/movie.png` and `--fixed-fps 30`.
The existing four-still proof contract is retained.

New output root: `/private/tmp/labyrinth_codex/ptf-05b/feedback2-movie/`.
The reviewed feedback-1 directory is untouched.

Expected owner-generated artifacts:

- `frames/movie*.png`: continuous PNG movie frames.
- `stills/out_of_range.png`, `stills/line_of_sight.png`, `stills/dark.png`,
  `stills/move_only.png`.
- `capture-manifest.json`.
- `fixture.json`, `fixture.log`: verified combat fixture certificate and log.

At each of the first two mid-hold captures, the movie resolves the hovered foe's
actor key, obtains its nonempty `enemy_intent_visual_global_rect`, reports both
rectangles, and asserts no intersection with the reason rest rectangle. Empty
intent bounds fail the check rather than allowing a vacuous pass.

## TODO_DESIGN placeholders

None. The 10 px gap and all retained presentation values come from the owner.

## Chosen defaults

Only the proof's named 200 px pointer displacement and headless pointer-getter
injection are new. The pan proof uses the board's own maximum zoom and allowed
pan bounds. Previous movie fixture, timing and timeout constants are unchanged;
only the isolated run/output names now use `feedback2-movie`.

## Open issues / environment

Windowed recapture and owner inspection remain pending. No new images or movie
are claimed. macOS certificate, existing tooltip `bramble` glossary and existing
HUD anchor warnings remain. Python passes but cannot update its optional timing
cache outside the sandbox. No pre-existing assertions were rewritten.
