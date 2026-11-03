# Playtest 18 owner feedback (2026-10-31), NEEDS CHANGES

Generalize: if feedback on one enemy or encounter likely applies elsewhere, research and fix it everywhere.

| Owner's point | Cause found | Where it goes |
|---|---|---|
| Events: few, same 3-4 repeat | 27 total, only 11 legal in the first section | catalog v2 (45, 30 legal), evt-01 rotation |
| Events: too many probability outcomes | 8 of 27 had dice | catalog v2, evt-01 removes `random` |
| Events: rewards not shown, nothing tactile | Lines said "random", no hover or beats | evt-01 preview, evt-02 |
| Pre-battle "kindle" unexplained | Row printed `Kindle +2`; caption said `Melee` | brs-01 |
| "Objective - Ember Hoarder" | `objective_title` was a name; Last Light had the same fault | brs-01 |
| Burst draws a hand-drawn grid | `draw_resolution` tile rings | brs-01 |
| Dashed line conveys nothing | `draw_ring` dashes | brs-01 |
| Storm Salvo weak, retire Flurry? | Spends all Card Plays for small repeats | flu-01 (retired from content, engine dormant) |
| Ticks and Grubs move in fits and starts | Root eases to a stop every tile; 0.7-0.9 s per tile | mv-01 |
| Grubs float | Painting touches the ground only at the front legs | director capture, then a unit |
| Tharokh lost his face | Filter merged low-contrast head (Noctyrax, Zekarion too) | done, `tools/cel_look.json` |
| Chain 2 off Tharokh missed an adjacent grub | Distance measured from the anchor tile (to be proved) | chn-01 |
| Rubble and Ice shows only Ice, one merged tooltip | Ice sheet over rubble; joined string | srf-01 |
| "The dark was never empty" | Too cute | done, plus three lines in the same voice |
