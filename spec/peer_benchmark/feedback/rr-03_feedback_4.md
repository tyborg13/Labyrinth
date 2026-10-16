# rr-03 — round 4 (Codex peer review of 0c5faf162: CHANGES REQUESTED)

Context: after your round 3 the director changed the death keys (r3: collapse — wings splay to -85°, head 48°, roll 38°,
lift -14 px, settle at 0.7–0.8) and re-ran prepare-motion / repair_ownership rebuild / repair_fills / motion samples /
native_v04 proofs, then committed everything as 0c5faf162 (incl. the promoted `assets/units/gust_shrike_cutout/`).
The protected source is unchanged since; do not edit it. Full review: /private/tmp/labyrinth_codex/review/rr-03-0c5faf162.md

Fix all five findings:
1. `tests/gust_shrike_cutout_test.gd:90` still asserts the old 70°/10 px death. Read expected values from the
   protected source (or the compiled data) instead of hard-coding them, so a director data edit never strands a test.
2. Register the rig's 48 production PNGs with the board pixel-density registry per spec (rest records, prescribed
   processing), and make `tests/test_board_pixel_density.py` roster extraction include conditionally registered cutout
   families so an unregistered rig fails.
3. Regenerate the production shadow cache for `res://assets/units/gust_shrike_cutout/front/rest.png`, reconcile
   `tests/en05_integration_sync_test.gd`, preserve unrelated entries.
4. Motion gates must verify signed per-view motion: at every authored key time (and at interval midpoints) the sampled
   channel value and sign must match the projected director value within the existing tolerances, and every authored key
   must be present. Both reviewer mutations (drop the idle tail hold key at t=0.4; negate the tail projection sign) must
   fail the CPU gate — add them as regression tests.
5. Production capture coverage: for each action clip (move, dive, talon_rake, hover, hit, death) capture at least 6 frames
   spanning phase 0→1, including its preparation, its contact/apex frame (dive contact, talon rake 0.5, move landing,
   death terminal) and recovery; require visible pose change between consecutive captured frames of a clip. A global
   frame count must not substitute. Idle may stay as is.
Do not commit. Headless proof as before; list the windowed sequence again as native_v05 (no promotion unless art bytes change).
