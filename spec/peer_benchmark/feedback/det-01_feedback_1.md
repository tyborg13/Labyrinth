# det-01 feedback 1: staged startup path (review 2c94e72b4)

1. **Medium: the staged startup skips the arrow fix.**
   - In `run_scene.gd`, the `board_view.item_rect_changed` connection sits after the staged-startup early return, so a
     run started from the main menu (the staged path) never gets it. The reviewer reproduced `CONNECTED=false` and a
     4 px endpoint error.
   - Register the connection idempotently in startup code that both paths run, guarded with `is_connected`.
   - Extend the regression to cover both the direct and the staged startup path. Each must fail with the connection
     removed.
2. **The Low (STATUS.md scope) is not yours.** Those edits came from merging integration into your branch. Ignore it.

Proof:
- both startup-path regressions, plus the mutation;
- the focused programs 20× under load;
- the full Godot suite through the parallel runner, plus the Python suite.
