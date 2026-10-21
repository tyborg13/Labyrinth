# spx-02 feedback 2 (Codex peer review of 5b59fff34: CHANGES REQUESTED)

Fix all six with the reviewer's fixes, and add a regression or mutation check for each:

1. **Medium:** `section_map_graph.gd:98` calls `Specials.place()` inside `assert`, so release builds skip placement.
   Run it as its own statement, then assert the result. Add a test that fails if placement is skipped.
2. **Medium:** `run_engine.gd:2762`. A deferred card replaces the first Common without respecting that slot's
   filter: seed 1's first Warband loses a Lightning offer to `guiding_flare`.
   - Put an off-element deferral in the general slot, then re-apply the Rare floor.
   - Add a `finish_combat` integration test.
3. **Medium:** `run_engine.gd:2750` `var weighted: Array[String] = []` breaks the Windows typed-array rule in
   AGENTS.md. Use an uninitialized typed declaration or a typed helper, and check the rest of your diff for the same
   pattern.
4. **Medium:** the Snare exit test uses production `_eligible()` as its oracle. Count outgoing edges independently,
   and add a negative fixture where a one-exit node must never become a Snare.
5. **Medium:** the pity-reset assertion starts at zero misses. Start with a positive miss count, and verify the reset
   through both entry paths.
6. **Low:** the legend order is asserted against production `LEGEND_ORDER`. Assert an independent literal of the
   approved order: Standard combat, Warband, Umbral Snare, Ember Hoarder, Last Light, Guardian combat, Event,
   Scavenger, Graftwright, Relic, Ember Hearth, Boss, Unknown room.

Focused tests only. No visual change is expected, so no windowed rerun unless something visible changes.
