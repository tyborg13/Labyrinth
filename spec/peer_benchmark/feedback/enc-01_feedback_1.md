# enc-01 feedback 1 (director)
Native captures: air/fire/ice/lightning look right. **earth_encounter.png and shadow_encounter.png show the board with
no units at all — not even the hero** (proof copies: /Users/borgerding/workspace/Labyrinth/output/peer-benchmark-2026-10-12/proof/enc-01/).
Find the root cause before anything else and state it:
- If unit renderer preparation (cutout/static) for `stoneback_mite`, `wick_shade` or `veilbound_acolyte` stalls, fails or
  is skipped outside their guardian/boss contexts, so the board hides all units, that is a game bug: fix it (in the
  renderer preparation path, minimal) and add a regression that a regular room with each biome group renders every unit.
- If it is only capture timing, make the probe wait until every unit renderer is prepared and assert each unit is drawn
  (hero included) before capturing.
Also run every biome group's units once in a regular room in the headless suite and assert their renderer preparation
completes. Re-run the native proof command and list it again. No other changes.
