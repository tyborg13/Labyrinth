# flow-01 feedback 4 — delta review CHANGES on 63c1f11ba

Review: `spec/peer_benchmark/feedback/flow-01_review_63c1f11ba.md`.

1. **Finding 1 (map generator freeze) isn't yours.** It's in map-02's revision 5 solver, which is merged on
   integration. A separate unit (fix-05) owns it. Don't touch `section_map_graph.gd`. The `main_menu_resume_test`
   timeout in the reviewer's run is likely the same freeze. I'll re-run once fix-05 lands.
2. **Legacy reward placeholders are visible (Medium). Decision:**
   - When an old save has no reward summary, the re-shown dragon reward screen shows only what is known: the
     dragon's name line, the relic and its text if recorded, and CONTINUE.
   - Omit the Ember payout and Moltshard lines entirely. Never show a placeholder or `TODO_DESIGN` string to
     players.
   - Remove both `TODO_DESIGN_LEGACY_REWARD_*` constants.
   - Assert the visible labels independently: no label text contains `TODO_DESIGN`, and the omitted rows are absent.
3. **Typed arrays (Medium), scoped.**
   - The project's established practice is typed declarations with literal initializers (`var x: Array[T] = []` or
     `= [a, b]`): about 1,200 on master. Leave those.
   - Fix the Windows hazard forms in the files you own:
     - conditional expressions whose branches include an untyped array literal (`[x] if c else typed`);
     - assignment of a bare literal to an already declared typed variable (`typed_var = [x]`).
   - Use typed helpers or typed temporaries populated via `append`/`assign`.
   - Report what you changed.
4. Re-run the transition suites, the probe headless semantics, and the Python suite.
