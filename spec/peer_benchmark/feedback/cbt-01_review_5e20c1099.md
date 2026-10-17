Reviewed HEAD `5e20c10990015de9d89a47f79aaaa844f4ab8775`.

1. **Medium — Keyboard targeting loses its visible cursor.** [movement_target_keyboard.gd:19](scripts/movement_target_keyboard.gd:19) uses controller focus, but [run_scene.gd:2086](scripts/run_scene.gd:2086) clears that focus every physics frame in keyboard mode. Reproduction: navigate onto the hero during Guarded Step, then await a physics frame. Logical cursor remains `(4,3)`; rendered focus and hover become `(-1,-1)`. Enter still commits Stay. Preserve keyboard focus and its targeting arrow across frames; add a regression that waits before confirming. [Reproduction log](/tmp/cbt-01-review-experiment.log).

2. **Medium — Required renderer proof remains missing.** [cbt_01_handoff.md:155](tests/cbt_01_handoff.md:155) explicitly records absent screenshots. Supply fresh 1920×1080, 100% captures of Stay hover and Immolation’s no-Fire preview, plus the independent UI identity review, after fixing keyboard focus.

3. **Low — Successive-Stay analytics lacks regression coverage.** [cbt_01_suite.gd:40](tests/suites/cbt_01_suite.gd:40) checks a fresh sequence equals `1`. Mutating the resolver to reset it to `1` on every Stay **survived** the focused suite, silently losing subsequent `stayed` events. Add two successive card plays and assert both analytics payloads, including replay from a serialized snapshot.

Mutation results: **9 caught, 1 survived**. Caught mutations covered pure-movement eligibility, movement fallthrough, Hotfoot rewards, Immobilized bypass, omitted analytics, changed target order, disabled keyboard input, movement animations, and the wrong Empower action index.

Focused tests, enclosed integration, headless probe semantics, UI identity lint, and glossary budget checks passed. Separate experiments verified successive-Stay analytics, serialized replay, and exact undo/replay of a subsequent free walk.

Immolation’s original Detonate is unchanged; action order and Empower index are correct; heuristic score is **3.00**. No new Windows typed-array violation, misplaced production tuning, obsolete Skip Step caller, or unrelated runtime scope expansion found. The extracted helpers appropriately limit `run_scene.gd` growth.

Full suites were not rerun. All mutations and temporary checkout files were removed; the checkout is clean.

CHANGES REQUESTED