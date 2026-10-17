# mq-04 feedback 2 — direction change: maquette quality first, paint-over afterwards

## Director decision (reverses the brief's "approved art stays")
The owner's standing requirement is that every enemy be painted from a maquette, because mixing maquette-based and
original-art enemies keeps the style inconsistent. So wave 1 follows the Frostglass Lancer path:
- maquette, then front/rear paint-over (the approved art-02 paintings are the identity reference only), then rig.
- The fit-to-art gate therefore becomes proportion guidance: IoU ≥ 0.70 front, ≥ 0.65 rear. The new painting follows
  the maquette.
- The quality bar rises to the Lancer r3 maquette:
  `spec/art_identity/maquettes/frostglass_lancer/spec_r3.json`, with the mq-03 delivery renders under
  `/private/tmp/labyrinth_codex/mq-03/round5/lancer_r3/`. That means real anatomy, cloth-simulated hood, cloak and
  robe, plate shapes, and crystals.

## What's wrong now (from `batch_validation/clay_contact_sheet.png`)
These are primitive "toy soldier" shapes, which the owner has rejected before:
- **Hoarfrost Seer.** The hood is a cone, the collar and body are stacked cylinders, the robe is a straight cone with
  a sawtooth hem, and the sleeves are rigid cylinders.
  - Needed: a cloth-simulated hood that drapes over the head and onto the shoulders (as the Lancer's hood does), with
    the face recess in shadow.
  - A cloth robe falling from shoulders and belt with real folds and a ragged hem that breaks on the feet.
  - Cloth sleeves with wide drooping cuffs, a rope belt, and a gnarled staff with the crystal from the crystal
    builder.
- **Gloam Stalker.** The hood is a cone, the drapes are flat panels, and the sleeves are cylinders.
  - Needed: a hunched hooded cloak (cloth) whose tattered drapes hang from the shoulders and back.
  - Long thin arms on the base anatomy, and the two claws as sculpted curved crescent blades with a thick root and
    tapering tips.
- **Gale Herald.** The banners are flat paddles, the hood is a cone, and the arms and torso are boxy.
  - Needed: banners as tattered cloth strips hanging from a shoulder yoke and swept by a wind force (per-view cloth
    pose as decided).
  - A masked hood with a crest, layered armour pieces as real plate shapes, and the horn as a lathed, flared brass
    horn.
- **Arc Thrall.** The base anatomy reads well. Fix the rest:
  - the loincloth is a flat plate: make it cloth;
  - the club is a straight tube: make it a tapered, gnarled pipe-club with bands, with the lightning cracks as
    features later;
  - the collar ring is a thin tube: make it a heavy iron collar ring with thickness and a chain stub.
- **Cloth collisions.** They must pass. If the cloth solver fails, fix the collision setup (collision margins,
  pinning, self-collision, pre-roll frames, collision objects on the base mesh) rather than replacing cloth with rigid
  primitives. Rigid primitives are not acceptable for cloth items.

## Order and scope for this round
1. **Hoarfrost Seer** (the robed and hooded archetype) and **Arc Thrall** (the bare-anatomy archetype) first, to the
   Lancer bar.
2. Stop and hand back clay renders, front and rear at 1024, for both, plus a side-by-side with the Lancer r3 clay
   renders at the same scale. I review them before you spend time on Gloam and Herald.
3. Keep determinism, ownership and the mutation gates. Report the IoU against the new gates.

The builder may grow generic, tested helpers (cloth presets for hood, robe, sleeve and banner strip; crescent blade;
lathe; gnarled club). Bridge rules are unchanged: jobs are started within 120 s and may run up to 900 s.
