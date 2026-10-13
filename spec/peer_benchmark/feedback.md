- 2026-10-12 OWNER (biome preview): the blue cloth bow tied around the air (Vaeloryx) pillar "doesn't really match the
  feel of the rest of the game" and reads as unclear. → Regenerating the pillar as plain wind-worn limestone, no cloth or
  ornaments. Owner clarified: not a rule against decorative details — this particular bow just didn't fit.
- 2026-10-12 OWNER (SFX audition, in progress): block.break — none convey a block breaking (needs a designed
  shield-crack layer); stoneskin.gain — all candidates sound weird/out of place → reuse the block.gain pick (director:
  pitched ~0.85 for weight); shot.crossbow — none fit.

## 2026-10-12 — SFX audition v1 (owner, via the audition page db; 58 of 82 cues so far)
- Picks recorded in `output/peer-benchmark-2026-10-12/sfx/owner_picks_v1.json` (snapshot of the page db).
- No candidate fit → round 2 (layered/sliced designs): block.break ("none convey that the block is being broken"),
  push.slide ("too specific — rocks/heavy objects sliding"), trap.trigger ("sound like locks being opened, not an
  elemental floor trap"), radiance.light ("C closest, none quite"), illusion.break ("maybe a subset of D, but it's ~20 s").
- Owner-directed reuse: stoneskin.gain → the Block sound (director: pitched ×0.85); shot.crossbow → the bow sound
  (×0.92); spell.fire → hit.arcane take C ("works better than any of these").
- status.expose: owner unsure what it should sound like → director decision: no dedicated sound (one signal per concept).

## 2026-10-12 — SFX audition round 2 (owner)
- Picked layered designs: block.break B (iron give-way), push.slide A (breathy fabric whoosh + scuff), trap.trigger A
  (stone plate clunk + arcane rune zap), radiance.light B (centred glow swell, no glint), illusion.break A (1 s cut of
  the processed-glass swell). Built and committed ed2e07f04. All cues except ambience now have owner-picked sounds.
- Takeaway: layered designs beat single library takes for abstract game concepts (break, trigger, push).

## 2026-10-12 — Threats at rest v2 (owner)
- Pills over heads rejected; order number beside the health bar; attack chip at the feet with a "can hit you now"
  danger state (red + pulse); ground compass emblem removed; area zones must show their source.
- Chips must match the game's visuals (not default boxes) → HUD resource-chip language; offset slightly from the base.
- Chips always stay at the feet — relocating them to the health bar is confusing (far from their anchor).

## 2026-10-13 — art-02 re-art review
- Owner: "The last pass of the enemies is looking much better except the rear view of the bird. Imagegen seems
  completely unable to figure out the wings (that's a problem that exists with our other birds too)."
- Director: judge rubric gains criterion 9 (structure legibility); bird rears to be built from a 3D maquette
  (front + rear rendered from one posed proxy at the board camera) instead of text-only generation.
