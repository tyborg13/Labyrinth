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
- Owner 2026-10-13: "Let's try the maquette... The other enemies are approved." → art-03 integrates 11; shrike via Blender maquette pilot.
- Owner 2026-10-13: canon cut approved (hero + approved art-02 + grave surgeon + props); roster upgrade phased, regulars first.

## 2026-10-13 — maquette verdict
- Owner: the maquette shrike "looks better... the wings make perfect sense now". Pose note: the front is too level with
  the rump up in the air; prefer a perched stance — upright on two legs, tail down toward the ground (like the rear).
  "I think we probably want to make that our baseline that we work from and we might need to do the same kind of thing
  for other bird and bird-like characters who have goofed up wings in their rear views."
- Director: shrike re-posed perched (body nose-up ~32°, legs under the centre of mass, tail angled down); maquette is
  the baseline route for anatomy image generation cannot infer; rocs' rears move to the front of wave 2.

## 2026-10-13 — perched shrike + gaoler maquette pilot (owner)
- Gust shrike (perched mq2): "The shrike looks good. I'm not *certain* that I'm sold on the wings straight up, but it
  looks good enough to go with for now." → integrate (art-04); the wing pose stays an open question (half-raised /
  mantling is the alternative to try when birds are revisited).
- Chainbound gaoler (maquette pilot): "he looks quite boxy now, probably a bit too much so. Otherwise, he's definitely
  looking better than before. More consistent with our intended style and his proportions and angle make sense." →
  angle, proportions and style approved; revise the maquette to soften the boxiness (tapered rounded helm, sloped
  rounded shoulders, hunch/weight shift, flared coat, rounded boots), repaint front then rear.

## 2026-10-15 — rounded gaoler (owner)
- "It looks decent enough for now. We may tweak later, but let's go ahead and rig it." → owner-approved 2026-10-15:
  front `spec/art_identity/jobs/chainbound_gaoler/mq3_front_v3`, rear `mq3_rear_v2` (sheet `sheet_pair_mq3_v2.png`).
  rr-02 (maquette → cutout) proceeds on this pair; later tweaks re-run the same pipeline.
- Owner 2026-10-15: "His chain doesn't actually link up." → scoped chain-only edits of both views
  (`maquettes/chainbound_gaoler/chain_fix_{front,rear}.md`: alternating face-on rings and edge-on links passing through
  each other; top link around the fist, bottom link through the hook's eye). rr-02 phase 1 continues on the current pair;
  phase 2 reruns `tools/maquette_cutout.py` on the chain-fixed pair (only the `chain` part changes).

## 2026-10-15 — Fatigue amplification (owner)
- Q: "Fatigue damage is currently amplified by Expose, Chilled and Frozen (combat_engine.gd:7773). Is that intended?"
  Owner: "No, definitely not. Good catch" → fix-03 (Fatigue never amplified; other non-attack sources audited, unchanged).

## 2026-10-15 — static enemy idle (owner)
- "The animations are doing a weird rippling thing I rejected from codex a few times now. They need their various cutout
  parts to bob or sway independently like you'd see from a typical idle animation."
- "the bird is just kind of bouncing up and down but not in a realistic way as if it were actually jumping."
- Director: anim-01/anim-02 (row-weighted mesh warp + whole-body bob) shelved; idle comes from rigid cutout parts.

## 2026-10-15 — playtest 8 (owner)
- Briar Weaver: after Thornwall it got no further turn and showed no intent (tooltip or board threat). → fix-04.
- Lightning trap: the electricity sound is "multiple seconds long ... outrageously long" (surface.electric_01 is 9.1 s,
  status.shock_01 3.6 s). → sfx-04 round 7: one-shot cue length caps.

## 2026-10-16 — playtest 9 (owner): "this build feels really good ... we're really starting to get somewhere"
- Asked for scripted demo clips instead of hunting cases in play (sounds, pixel FX) → demo-01.
- Outstanding improvements list (verbatim intent):
  1. Map: better, more interesting branching; take inspiration from Slay the Spire (partially fixed, needs more).
  2. Some attack previews (AoE?) show enemies or destroyed terrain as already gone instead of marked to be
     killed/destroyed — very confusing (probably not fixed).
  3. More starting build diversity so the game is fun immediately (idea: carry one equipment piece to the next run;
     brainstorm together).
  4. Immolation needs innate value beyond detonation, e.g. small damage per tile hit (felt weak without setup).
  5. Move-and-block cards need an intuitive way to not move (may be fixed).
  6. Next-section button → automatic, with a cool transition animation from one map to the next.
  7. Pre-battle objective text became wordy; make it concise and straightforward (it was better before).
  8. Play enemy idle animations on the pre-battle screen (like the hero in the equipment menu).
  9. 6 magic-slot limit: maybe drop it entirely; strict limit trivializes deckbuilding and re-equipping spells after
     each fight is major friction (collaborate on design).
## 2026-10-16 — maquette art verdicts (owner)
- Frostglass Lancer: "too boxy, seems to be a recurring issue with these maquettes. We need to sculpt them a bit ... to
  get more realistic and aesthetic proportions like the source art." Likes the consistent style: "if we can improve
  the output a bit, we should redo all of the enemies in this style so that they can be consistent."
  Director diagnosis (source vs maquette vs paint-over): barrel ellipsoid torso, oversized round pauldrons, legs ~30%
  of height (source ~45%), cloak a flat rear plate (source: ragged cloak flaring wide at the hem), so the paint-over
  inherited a squat golem silhouette. → mq-02 (proportion fit to source silhouette + sculpted primitives).
- Shale Bloomer: approved — "quite good ... similar but in the more low res, painterly style".
- Lightning Wisp: not loved — "the bolts just kinda sticking out in every direction ... might look better if the
  lightning is interwoven throughout the cloud." → wisp maquette r4 + new paint-over.
## 2026-10-16 — demo clips (owner): "These look and sound GREAT."
- Pixel FX reel (12 spells), hit-sound sync clips (normal + fastest), lightning trap (0.35 s) approved by eye/ear →
  vfx-01 and sfx-04 owner-verified.
- 2026-10-16: Lightning Wisp r4 (lightning woven through the cloud, jobs mq4_front/mq4_rear): owner "New wisp looks
  great." Approved → cutout rig queue with the Shale Bloomer.
- 2026-10-16: Gust Shrike real-time 60 fps video (idle, hop, dive, talon rake, hover, hit, death): owner "Looks very
  good." Cutout motion approach approved → rig Shale Bloomer and Lightning Wisp the same way; then the roster.
- 2026-10-16: last two demo reels (full hit sounds incl. Crawler bite; lightning trap + Briar Weaver after Thornwall):
  owner "look good" → fix-04 (Weaver) owner-verified on video.
