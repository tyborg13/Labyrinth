# ptf-09 targeted-tile highlight

Current implementation and owner commands: **[result.md](result.md)** (feedback 2).
It supersedes the original and feedback-1 layer requirements: the border is now
an ordinary floor decal, 3 px lifted, between action-floor and scene-tile layers.

- `highlight_proof.gd`: hover/tone/click/controller checks plus painter-slot
  lifecycle and no-per-frame-slot-work assertions.
- `flicker_check.gd`: ten-frame crate presentation and movie-clock stability.
  `--release` uses scratch release scripts; `--legacy-sampling` intentionally
  fails the clock checks using the supplied old PNG timestamps.
- `prepare_reference.py`: extracts release RunScene/Board scripts read-only and
  records the original capture timing evidence.
- `real_fixture.gd`: resumes an inspection_fixture.py-certified real combat save.
- `capture.gd`: six real-game stills, or a 120-frame movie sweep with `--clip`.
  `--check-only` checks setup/logic headlessly and writes no images.
- `movie_capture.sh`: native MovieWriter wrapper, fixed 30 fps, 1920×1080.
- `finalize_movie.py`: copies the final 120 movie PNGs, excluding setup frames,
  preserving pixels, 30 fps and four seconds of game time.
- `focused_checks.gd`: affected hover/input/shortcut/targeting/intent domains.
- `performance*.gd` / `performance_report.py`: retained earlier paired evidence.
  Feedback 2 performs no new hover/frame A/B.

Historical evidence: [RESULTS.md](RESULTS.md), [FEEDBACK1_RESULTS.md](FEEDBACK1_RESULTS.md).
The old test-board and wall-clock sweep commands are superseded; use result.md.

## Headless verification

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/ptf-09 && python3 tools/godot_task_runner.py --task-id ptf-09 --stream -- godot --headless --path . --script tools/ptf09/highlight_proof.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/ptf-09 && python3 tools/ptf09/prepare_reference.py
cd /Users/borgerding/workspace/Labyrinth.worktrees/ptf-09 && python3 tools/godot_task_runner.py --task-id ptf-09 --stream -- godot --headless --path . --script tools/ptf09/flicker_check.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/ptf-09 && python3 tools/godot_task_runner.py --task-id ptf-09 --stream -- godot --headless --path . --script tools/ptf09/flicker_check.gd -- --release
cd /Users/borgerding/workspace/Labyrinth.worktrees/ptf-09 && python3 tools/godot_task_runner.py --task-id ptf-09 --stream -- godot --headless --path . --script tools/ptf09/focused_checks.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/ptf-09 && python3 tools/godot_task_runner.py --task-id ptf-09 --stream -- godot --headless --path . --script tests/board_tile_tooltip_test.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/ptf-09 && python3 tools/run_python_suite.py --shards 4 --changed-since c9121c833 --output-dir /private/tmp/labyrinth_codex/ptf-09/feedback2/python-default-owner
cd /Users/borgerding/workspace/Labyrinth.worktrees/ptf-09 && python3 tests/test_ui_identity_lint.py
```

All work is intentionally uncommitted. No worker-native capture, peer review or
publication is authorized. The owner runs the exact native commands in result.md.
