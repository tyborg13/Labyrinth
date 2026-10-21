# spx-05 feedback 2 (director, from the Codex review of 7d5b4e8c6)

The director accepted round 1's native captures (`output/spx-05-2026-10-21/r1/`): chips, sealed doors, the tooltip, the
reward and the legend are right, so don't change any visuals. The review found these defects
(`/private/tmp/labyrinth_codex/review/spx-05-7d5b4e8c6.md`, evidence in `/private/tmp/spx-05-review-evidence/`):

1. **Blocking: sealed thresholds are still traversable.**
   - Illusion placement (`combat_engine.gd:1185`) and future AI routing (`combat_engine.gd:10060`) skip the seal check.
   - After the real turn-two seal, `Mirror Image` then `Changing Winds` places the player on sealed `(7,4)`.
   - A Gaoler at `(7,3)` using Cudgel Press on the player at `(7,5)` enters `(7,4)`.
   - Fix: put the seal block in the one place that decides whether a tile is passable or occupiable, so placement, swaps,
     forced movement, AI planning and resolution all inherit it. Don't patch each call site.
   - Add regressions with these exact stock cards and this intent, failing before and passing after.
2. **Medium: True Bearing moves the hunter entrance.**
   - `combat_engine.gd:964` stores the selected player start as `snare_entry`.
   - Keep the authored entry threshold separately, before True Bearing applies, and spawn hunters from it.
   - Regression: seed 83, lightning room `(2,0)`, select `(1,3)`; the hunter arrives on `(1,4)`.
3. **Medium: True Bearing breaks the ice start distance.**
   - Starting hunters must be at least 2 tiles from the player's final position.
   - Place them after the final start is known, using the same deterministic nearest-free-tile rule.
   - Regression: seed 0, ice room `(3,-2)`, select `(1,3)`.
4. **Low: the 5-tile rule isn't tested at its boundary.** The 5 → 4 mutant survived. Add a four-edge rejection, a
   five-edge acceptance and a short-layout reroll assertion.
5. **Low: no action.** The Stormcaller sentence edit in the range is the director's own data change. It's already on
   the integration branch with identical bytes, so leave it as is.

Proof: focused tests only (the Snare suites, the special-encounter suites, the Warband suites, the illusion and AI
movement tests you touch, and the UI identity lint). No full suites; no windowed runs.
