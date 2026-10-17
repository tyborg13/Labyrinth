# map-02 feedback 2 — peer review CHANGES on 95b6dad2f

Review: `spec/peer_benchmark/feedback/map-02_review_95b6dad2f.md`.
1. **Bounded structural retries (Medium).** Replace `while true` at `section_map_graph.gd:194` with a capped proposal
   loop. On exhaustion, hand control to the outer 50-attempt / logged-fallback path. Add the reviewer's
   forced-structural-rejection regression: it must finish quickly and log exactly one fallback.
2. **Visual proof (Medium).** The director's nine captures from windowed run 2 are now in
   `output/map-02/director_run2/`, and the director judged them: varied, readable branching, no crowding at the boss,
   approved. Record that verdict and the paths in `tests/map_02_results.md`. Nothing else is needed.
3. **Public dispatch (Low).** Add regressions that load recorded revision 3 and 4 states through the public
   `initialize()` dispatch, so that "ignore recorded revision" fails the committed suite.
4. Also kill the two survivors the reviewer noted where cheap:
   - the focused contract should catch removed jitter clamps (add a small seed set that exercises them);
   - the probe's defer/ready wait should be asserted rather than masked by frame waits.

Re-run the map suites and the full Godot and Python suites. The full Godot suite is getting a parallel runner in qa-07,
so report the time either way.
