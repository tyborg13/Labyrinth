# sfx-05 — Empower charge and un-charge sounds (owner-approved)

## Header
- Owner (2026-10-20): picked candidate A for the charge, and asked for "a softer and maybe slightly duller sound for
  toggling it off".
- Director recipes: `spec/peer_benchmark/staged/sfx/recipes_empower.json`.
  - `empower.charge` A: Kindle, a flame catch with a short ember crackle.
  - `empower.uncharge` A: the flame alone, pitched down and lowpassed.
- Measured library index (the `/tmp` copy was lost to temp cleanup):
  `/Users/borgerding/workspace/Labyrinth/output/sfx-lab-index-2026-10-20/{index,takes,features}.jsonl/json`.
  - Sources: `/Users/borgerding/workspace/Labyrinth/output/sfx-sources-2026-10-12`.
  - Rendered designs: `/Users/borgerding/workspace/Labyrinth/output/peer-benchmark-2026-10-12/empower-charge-audition/designed`.
- Base: integration HEAD. Owned:
  - the cue registry (`data/sfx_cues.json`);
  - `spec/peer_benchmark/staged/sfx/{approved_r2.json or a new approved_empower.json, mix_targets.json}`;
  - the built cues under `assets/audio/sfx/` and the SFX manifest;
  - the Empower toggle call site (`scripts/card_empower_controller.gd` `toggle`);
  - tests.

## Change
1. **Build** both cues through the sfx_lab pipeline: design, then index, then build, as `spec/sfx_pipeline.md`
   describes. Licences: A is Sonniss GDC; the un-charge is CC0. Record them as the pipeline does.
   - Mix targets: `empower.charge` −24 LUFS, `empower.uncharge` −30 LUFS. The un-charge is 6 dB under, as the owner
     asked.
   - Category: same as the `card.*` cues.
2. **Wire.**
   - Turning a card's charge ON plays `empower.charge`. Turning it OFF plays `empower.uncharge`. That covers the seal
     click, E, and the controller RS.
   - The charge clearing on play, discard, burn or turn end plays nothing, because that isn't a toggle.
   - A blocked seal (health) plays the existing `card.invalid` on an attempted charge. Keep it if it already does.
   - Onset is 0–20 ms after the input frame (the sfx-04 sync rules). No cue waits for another.
   - Reduced motion doesn't affect sound.
3. **Tests.**
   - A routed-input test: charge, then un-charge, plays exactly those two cues in order.
   - Play/discard/turn-end clears play nothing.
   - Run the sync audit for the new cues.
   - Focused tests only.

## Keep
- Every other cue's audio and level, the Empower visuals and rules.
- Windows typed-array rule.

## Proof
- The director records a windowed clip, with sound, of charge, then un-charge, then charge again. List the command.
