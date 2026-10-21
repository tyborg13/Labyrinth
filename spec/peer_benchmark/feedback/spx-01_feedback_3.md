# spx-01 feedback 3 (integration: the measurement suite after spx-02 and spx-03)

Your unit merged into integration (011dd1467) after spx-02 (revision-6 maps with special nodes) and spx-03 (standard
fights always Defeat All in revision 6; Warband rooms). The director fast-forwarded your branch to that commit. The
full Godot suite now fails only in `encounter_measurement_test`:

```text
ENCOUNTER GOLDEN: FAIL (3 seeds; maps, rooms, combat, saves)
FAIL: small sweep includes every current objective
ENCOUNTER SMALL SWEEP: FAIL (36 rooms)
ENCOUNTER BOT DODGE/DEFENSE: FAIL
ENCOUNTER BOT DETERMINISM: FAIL (3 objectives, repeated seeded rooms)
```

These are expectations written for revision-5 generation. Update the tooling, not the game:

1. **Goldens:** they guard "measurement changes nothing", not the map itself. Pin the golden check to the revision-5
   generator path, which is still supported for saves, so it keeps proving the tools add no side effects. Alternatively,
   regenerate revision-6 goldens with a note that the change came from spx-02 and spx-03. Choose one and say why.
2. **Sweep and baseline:** in revision 6, standard rooms are always Defeat All, and Defeat the Leader appears through
   Warband rooms. Sweep and bot should cover standard Defeat All and the Warband (by biome and tier), using spx-03's
   generation path. Keep the revision-5 objective cohorts available behind a flag for comparison. Re-run the 200-run
   baseline per cohort: rev-6 Defeat All and the Warband at tiers 1–3.
3. Make the dodge/defense and determinism tests independent of which objectives the current revision rolls.
4. Run focused tests, then the full Godot suite once at the end to prove integration is green. This is the last round
   for this unit in this session.
