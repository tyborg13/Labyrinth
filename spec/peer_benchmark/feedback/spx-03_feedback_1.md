# spx-03 feedback 1 (director: native captures judged; one placement fix)

The windowed probe passed (8 captures). The banner, the +1 intents, the LEADER tag, the title in the objective and
turn order, the keep-distance step and "The warband breaks!" all read as designed. One placement problem, found in
the console:

1. **High: the escort can start on top of you.**
   - `warband air 2 83`: the player is at (4,7) and the Stormcaller at (2,5), Manhattan 4, so it meets the brief. But
     the escort within 3 of it lands 1–2 tiles from the player: a Shrike at (3,6) and the Gaoler at (2,7). Passing
     turn 1 costs 10 HP. `warband fire 1 7` puts an Ash Hound at (4,5), 2 from the player.
   - The brief's rule allowed this; that's my error. New rules, all in Manhattan distance (the card-range metric):
     - the captain starts **5–7** tiles from the entry, not 4–6;
     - **every** escort starts at least **3** tiles from the entry, and outside the existing entry halo every spawn
       respects;
     - the screen (escort[0]) still stands on a shortest path between the entry and the captain, at least 3 from the
       entry;
     - the other escorts start within 3 of the captain;
     - the captain is never the closest enemy.
   - Keep the 20 seeded rerolls and the deterministic fallback. If a room is too small for every rule, the fallback
     relaxes "within 3 of the captain" first, never the 3-tile distance from the entry.
   - Re-assert all six variants × three tiers × 200 seeds. Report the share of rooms where passing turn 1 costs more
     than 6 HP, using the existing preview numbers.
2. **`TODO_DESIGN_WARBAND_BREAK_BEAT_SECONDS`, decided:** keep 0.4 s, the existing two-tile cadence.
3. **Sidecars:** the four staged emblem `.png.import` files come with spx-02. Ignore that suite failure here.
4. Focused tests only. The director reruns the windowed probe.
