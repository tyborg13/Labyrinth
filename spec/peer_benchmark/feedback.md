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
- 2026-10-16 Lancer: source repaint "looks really good" but owner rejects a mixed pipeline (style inconsistency):
  keep the maquette approach for ALL enemies and refine it — wisp, shrike, bloomer show the consistent look; avoid a
  "toy soldier" look. Asked for: armour shaped like real plate pieces (not ovals), the scarf/mantle wrapping around
  (not wings sticking out in front), a diamond chest gem, an icicle spearhead that follows the shaft. → mq-03.
- 2026-10-16 pre-battle objective: owner questioned "Defeat the marked leader. The rest flee." under "Defeat the
  Leader" — redundant. Decision: pre-battle shows only the heading `OBJECTIVE · <TITLE>` for every objective; the
  one-line rule text moves to the heading's hover tooltip (pb-01 fix round).
- 2026-10-17 Shale Bloomer motion (inbox): "generally good ... right direction ... details not the design". Issues: idle
  still has the shimmer effect (owner keeps asking to avoid it); distracting wrong breakages from the cutout, esp. the top
  gem breaking in half in several animations. → rr-05.
- 2026-10-17 Lancer r3 painting (inbox): "directionally correct" but the loin cloth needs another stab, and he is more
  straight-on than before — all characters must be in the correct 45° isometric 3/4 view. → mq-03 round 3.
- 2026-10-17 Lightning Wisp motion (inbox): approved. (rr-05 applies the stepped pixel-snapped idle to it too.)
- 2026-10-17 Lancer r4 painting (3/4 view, split loin cloth) from the Blender-native maquette: owner "Middle looks great" → approved target look; next rear view, processing, rig, roster plan.
- 2026-10-17 roster-plan APPROVED with a reorder: "order it by need. Start with the new enemies, then ... the ones least
  matching our style and/or having an incorrect pose and then decide whether to redo even the enemies that look pretty
  good already ... stone warden is already pretty good ... the cultist is solid too ... lowest priority."
- 2026-10-17 section-transition NEEDS CHANGES (owner): "After introducing the next section, you're briefly switching
  back to the board before going to the new map section. We should cut that. Otherwise, looks good." → flow-01
  feedback 3: the title card cross-fades straight into the section map (same painting); the board stays hidden until
  the map closes.
- 2026-10-17 section-transition APPROVED (owner) on the updated clip (title card → section map, no board flash). No
  sound sting added. flow-01 is accepted and waits for owner publication approval with the rest of integration.
- 2026-10-18 bloomer-motion APPROVED (owner) on the rr-05 final clip: whole gem, stepped idle, joint fixes. The Wisp
  reference clip shipped alongside.
- 2026-10-18 seer-rig NEEDS CHANGES (owner): "rear view is wrong orientation entirely, idle is still more of a rippling
  effect rather than an independently cut out bob like our protag (all of our humanoids should generally bob like
  this), some of the animations are cutting up nonsensically, it's like you're not even rigging him like we have been
  in the past, or maybe not cutting him into small enough parts."
  - Director diagnosis:
    - The mq-04 Seer rear maquette is a left-right mirror, not a 180° turn. The other figures' rears are right.
    - The rr-07 idle was the director's own rotation sum ("no whole-body bob"); the rr-08 Herald/Gloam idle data had
      the same flaw.
    - The rig used rigid per-label sprites with supports, where the protagonist and Acolyte use skinned sleeves,
      robes and capes.
  - → humanoid rig v2 (`spec/peer_benchmark/humanoid_cutout_rig.md`): mq-06 (rear turn fix), the director's rear
    repaint, then rr-10 (Seer v2). Thrall, Herald, Gloam and Lancer follow.
- 2026-10-18 thrall-rig NEEDS CHANGES (owner): "Right arm doesn't seem to connect high enough to match the left. Walk
  is unnatural with no knee bend. Idle is more of a ripple than a bob. Attack (I assume) swings the gun arm backwards
  so it makes no sense. Rear view shows the inside of the gun thing where it should be going into the arm. Front view
  just paints the hand over it, which makes no sense. Generally, these cutouts are not reaching our standard."
  - Director diagnosis:
    - The mq5 paint-over broke the original concept. The approved old Thrall's near forearm is sheathed in a capped
      iron tube with no hand. The mq5 front paints a hand over the tube, and the mq5 rear shows an open pipe end.
    - The tether/jab raised the near arm by rotation, and the sign carried it backward. Translation-led hand targets
      remove that class of error.
    - The rr-07 move had no leg solve.
    - The far claw arm reads as growing from mid-chest.
  - → Thrall repaint r2 (both views: a capped tube sheathing the forearm, the arm entering at the elbow, no hand, both
    shoulders at the real shoulder). Spec additions: knee-bend walking and shoulder attachment. Then the Thrall v2 rig
    after rr-10.
- 2026-10-18 grub-rig APPROVED (owner): "Excellent work, this is perfect." Burrow Grub maquette painting (stubby legs
  kept) and its rr-12 rig (two-group idle, inchworm crawl, gnaw, burrow into the mound, erupt) are accepted.
- 2026-10-18 tick-rig APPROVED (owner), with no notes. The Ember Tick painting (standing legs kept, near-black shell,
  ember cracks) and its rr-12 rig are accepted. Both are on integration (rr-12 merged 9fdb6462f).
- 2026-10-18 seer-rig-v2 APPROVED (owner), with no notes. Hoarfrost Seer v2 is accepted: the true 180° rear (mq-06
  repaint), the protagonist bob idle, the skinned robe and sleeves, and translation-led actions (rr-10 + rr-13 on humanoid
  rig v2). The rr-13 review round closes 2–6 px seam pinholes with hidden fills only (rest identity unchanged). This
  confirms the humanoid rig v2 spec as the standard for the Thrall, Herald, Gloam, Lancer and Glacial Mirror.
- 2026-10-18 playtest-10 NEEDS CHANGES (owner, one run): "the new purge interface is well below our visual standards.
  Looks like something that sol would design, not you. Text not fitting within buttons, huge amounts of dead space,
  just really far below the rest of our experience. Also, the enemies moving quickly is nice, I like that, but non
  movement actions may be too sped up, sometimes all the enemies turns play and I can't really keep up with what they
  are all doing. Spells going straight into the deck is definitely better imo." Follow-up: "This was in the shop btw,
  never ran across the fire in that run."
  - → Purge overlay (`scripts/magic_purge_overlay.gd`, shared by the Scavenger and the Campfire; built by deck-01
    without a director mockup): director redesign with a 1920x1080 mockup on real assets, then an implementation unit
    and real-renderer inspection before the inbox.
  - → Enemy phase: keep movement speed (approved); slow attacks/casts to readable speed with a beat between enemies
    (`scripts/combat_pacing.gd`, feel-01 budget). Clip of a busy enemy round to the inbox.
  - → Spells straight into the deck: approved, keep.
- 2026-10-19 purge-redesign NEEDS CHANGES (owner, minor): "sooo much better. I think the "x2" for multiple copies
  should be more pronounced. The "purge a spell" header maybe a bit bigger. Otherwise, looking very good." → purge-02
  (medallion badge, shared with the pile viewer; 24 px header).
- 2026-10-19 enemy-pacing NEEDS CHANGES (owner): "This is better but still a bit fast. Are the attack animations and
  number pop ups still sped up? It may be worth slowing those down a little rather than keeping them sped up and just
  holding after." Answer: at Normal they already play at authored speed; feel-01 cut the gaps. → pace-02: enemy
  actions at 0.80× presentation speed; movement, lead and settle unchanged.

## 2026-10-19 owner verdicts (inbox)
- capacitor-rig: APPROVED.
- mirror-rig: NEEDS CHANGES. Owner, verbatim: "Mostly good, but needs some tweaking. There's a bit too much asymmetry
  between his arms for my liking, especially with one having a hand and the other just being a boulder. His right
  foot in the front view and left foot in the rear view look off. I'm not sure if its a drawing order issue or
  something else, but they don't seem properly positioned and connected to the ankle boulder. Lastly, on the guard
  from the front view, his arm goes behind him instead of in front of him. That's *definitely* a drawing order bug.
  Let's see if we can fix his walk a bit too. One leg is kind of shimmying and the other is mostly still like he's
  limping along."
  - Fixes: repaint both fists and the two odd feet (image revisions); draw the near fore/fist in front of the torso;
    the walk on the protagonist's model, 6 alternating steps per tile (gait-01; the 4-step plan was unreachable in
    2D); fresh unit rr-23 re-cuts from the mq8b repaint.
- thrall-rig-v2: NEEDS CHANGES. Owner, verbatim: "This is generally better. The loin cloth is not positioned correctly
  though and the collar positioning is suspicious in both views. It is over his mouth seemingly from the front and on
  the rear it has a slight upturn around the corner of the neck that doesn't make sense I don't think from this
  perspective."
  - Diagnosis (against the original art): the paint-over has a thin ring high on the neck (it crosses the mouth in front
    and curls up in the rear) and a flat panel off one hip (rear flap past the hip). The original has a heavy collar low
    on the shoulders and a ragged skirt wrapped evenly around the hips.
  - Fixes: repaint the collar (broad iron collar low on the shoulders, behind the jaw) and the loincloth (torn hide
    skirt wrapped round, rope belt, centred, mid-thigh) in both views; the gait-01 walk; then a Thrall re-cut unit.
- purge-polish: APPROVED (already on master, 209cbc67c).
- enemy-pacing-2: APPROVED for now. Owner: "I may slow this down a bit more later, but I'd like to feel it over a more
  extended play session first." The lever is the 0.80× enemy action speed.
- mirror-rig-v2: APPROVED for now. Owner, verbatim: "This is better and good enough for now. Not totally sold on the
  feet or hands but we can revisit those later when we don't have bigger fish to fry." Revisit item: the Mirror's feet
  and fists (backlog).
- Owner request (2026-10-19): redesign Empower. Verbatim: "Right now, it's a tiny button off to the side, it's not very
  aesthetic, it's hard to find, you have to select it with the board targeting arrow. I don't have a prescriptive
  answer, but it needs to be redesigned to look and feel much better." Director design: brief ui-03 (the card is the
  control).

- empower-redesign: APPROVED (direction, 2026-10-19 21:12). ui-03 builds it; a real-renderer clip goes to the inbox next.
- thrall-rig-v3: APPROVED (2026-10-20 00:59; low iron collar, wrapped skirt, two-legged walk). Merged 962950183.
  Follow-up already queued: re-key the rear Tether so the tube rises over the near shoulder (director data,
  staged/rr-11 view_keys.rear), folded into the record refresh after rr-26.
- empower-built: APPROVED (2026-10-20 10:57). Seal, ember glow and tooltip stay as built (ui-03 + int-03 targeting fixes, merged). Next: three charge sounds for an owner audition.
- empower-sound: APPROVED A (Kindle) (2026-10-20 13:48). Owner: "A, and yeah, let's play a softer and maybe slightly duller sound for toggling it off." Un-charge recipe authored (recipes_empower.json empower.uncharge).
- weaver-rig: APPROVED (2026-10-20 13:54).
- mimic-rig: NEEDS CHANGES (2026-10-20 13:54). Verbatim: "The hair is very wrong. The original is spiky anime-ish like our protag, the new is a weird peacock feather fan in the back. Also, the arms don't sway realistically during the walk animation, there's one animation where a hand in the front view gets drawn behind the body when it should be in front."
- mortar-rig: NEEDS CHANGES (2026-10-20 13:57). Verbatim: "Generally he's looking pretty decent, but the loin cloth is very wrongly positioned. Doesn't match the perspective at all, like it's not even on him. And there's some noticeably wrong tearing and stretching during animations around his face and arms. We need to clean all that up."
- enc-warband + enc-breakout: REDIRECTED (2026-10-20, by voice in the work thread, not the inbox). Owner: "I think these
  should just be unique encounters similar to our guardians, but not restricted to a certain path like the guardians
  are. So like have the leader always be a specific enemy. Have the one where you have to escape have a specific sort
  of composition of enemies ... maybe there's like a mini boss ... Like have a little bit of flavor attached to each of
  these, and then they can have their own icon on the map, so you know what you're getting into." Rewards: "maybe you
  get guaranteed higher rarity or more choices or more embers ... I'm not super prescriptive on that." Repeats: "do we
  make it so you can keep hitting these special encounters in every section? I think we would need to." Standard
  combat "is always just defeat all the enemies." Then "Yes, please" to rewriting the proposal as four types with
  per-section variants, rewards, map-icon mockups and placement rules. Posted as inbox item enc-specials; both old
  items closed with a pointer.
- Director decision, 2026-10-20 (Mortar, from rr-30's native captures): a single-painting cutout with arms this heavy
  cannot lift 12–50 px or cross the body without tearing at the shoulders. The Mortar's actions are carried by body,
  stance and crucible: hands ≤ 4 px from rest, head ≤ 3° from the torso, torso pitch ≤ 14°. Brace no longer crosses the
  bracers before the face; scatter no longer reaches into the crucible. Rig gates must run on rendered frames.
- mimic-rig-v2: APPROVED (2026-10-21 03:00). "Good enough for now." Merged 007f685c0. Revisit list: the faint 1 px chest
  seam during actions (with the Mirror's feet and fists).
- enc-specials: APPROVED (2026-10-21 03:01). Owner: "For now, let's just reuse enemies for ember hoarder, maybe we'll put
  a dedicated thiefy dude in the future." Director decisions on approval: the Hoarder is an Ember Tick gorged on stolen
  embers (no new art; a spark trail and an "Ember Hoarder" nameplate; its burst scatters the hoard); the Cinder Crown
  gang becomes 2 Ash Hounds + a Cinder Ooze (no Ticks); captains are NOT scaled (board pixel density) but marked by the
  Command banner and a titled nameplate. Build order: enc-01 measurement, enc-02 framework + Warband pilot, then Snare
  and Last Light, then Hoarder.
- Director decision, 2026-10-21 (spx-01): the measurement bot's policy v2 (tier-1 Defeat All 64% wins, median 15 HP
  lost, against the owner's logged 28/32 wins and 1.5 HP) is accepted as a relative benchmark only, for comparing a
  special encounter with a standard fight under the same bot. Absolute encounter bands come from owner playtests.

- Director decisions, 2026-10-21 (spx-05 feedback 1, Umbral Snare): a sealed door's texture is modulated by the Umbra
  token at 60% brightness (option D of `output/spx-05-2026-10-21/seal_tint_options.png`) and shows no destination
  medallion. The Seals chip uses the Wind chip's HUD plate, centred 6 px above the door's medallion. The Sealbinder's
  Seal intent reads "Seals its door in N turns. Kill it to keep the door open. When you escape, each open door pays 6
  Embers." The map legend follows spx-02's rule (one row while gaps shrink 40 → 12 px, else a centred second row),
  gated as a rule rather than a fixed count. A card-assisted escape on turn 1 is allowed; the 5-tile minimum only stops
  free movement.
- Director decisions, 2026-10-21 (spx-06 design, Snare pressures): every pressure that changes the board resolves at
  the end of the player's turn (after the escape check), so its marked preview is exactly what happens; seals keep the
  end of the enemy round. Rubble picks the first tile ≥ 2 steps along the hero's cheapest way out; fire burns distance
  rings from the entry fixed at fight start; the headwind is a persistent room-sourced wind toward the entry wall
  (Sealbinders anchored, chip "Headwind"); ice covers each sealing door's approach tile at fight start; a telegraphed
  Arc Thrall beam is live during the player's turn (entering it costs its damage and Shock). Shadow reinterprets "the
  Umbra closes one ring of the room" as the hero's Umbra vision shrinking by 1 every two turns (minimum 1), with doors,
  thresholds, chips and Sealbinders always visible: it reuses the existing darkness, where closing tiles would need
  new art. Tell the owner when the Snare is shown built.
- Integration fix, 2026-10-21: the revision-6 bot baseline was re-measured (d617cf371) after spx-04's orders and the
  director's resume-validation fix changed the bot file's hash; the density manifest dropped the 20 Mortar textures
  rr-30 retired to `excluded_paths` (8df5ff702). Lesson: a focused check that runs per entry can skip a whole-registry
  rule; a unit that edits a shared registry must run its full check.
- mortar-rig-v2: APPROVED (2026-10-21 13:53). Merged 7b7553afb (rr-30 + rr-31, squashed). Revisit list: the single-pixel
  joint specks in some action frames (with the Mimic's chest seam and the Mirror's feet and fists).
- Owner, 2026-10-21 (map): the branching ask from playtest 9 "got lost". Today's map is "too much like a few straight
  lines with a couple of branches here and there. It doesn't feel like Slay the Spire or Inscryption." On Inscryption:
  "far more beautiful. I don't want a full redesign to copy it, but if we can give ours a little more pizazz while we're
  already touching it, I wouldn't complain." Director measurement (revision 5/6, 200 seeds × 6 sections): 17% of rooms
  fork, 1.19 exits per room, 3 choices per route (worst route 1), longest no-choice run 5 (up to 8). Proposal (mockup in
  the inbox item `map-branching`; prototype `staged/map-03/map_proto.py`): 7 lanes, exits weighted 1:32 / 2:58 / 3:10,
  merges at 45%, every route ≥ 3 choices and no run without a choice > 2 rooms (forced Relic and Ember Hearth rows
  excluded) → 45% forks, 1.47 exits, 5 choices per route. Pizazz: inked dotted trails that wind a little, glowing next
  choices, a solid ember walked trail, faded cut-off rooms, ground shadows, and the lantern travelling the trail.
- map-branching: NEEDS CHANGES (2026-10-21 14:22). "Far too dense visually. I like the amount of choice you've added"
  — shrink icons or scroll like StS; the mockup's connections read as "clusters of zig zagged straight lines ... a step
  back". Director decisions: keep the choice density; the map scrolls horizontally (today's node size, 240 px columns,
  ~7 columns visible, opens on the player, wheel/drag/stick, recentres after each choice, edge fades, a slim scroll
  track, painting parallax 0.3); trails keep today's sideways S-curves (control reach 0.52 × dx) drawn as inked dots.
  Revised mockup posted as `map-branching-v2`.
- map-branching-v2: APPROVED (2026-10-21 14:31). "Looks good, can you implement this one yourself instead of enlisting
  codex and make sure that it looks really good and hits our standard?" Director: map-03 is implemented by Claude in its
  own task worktree (generator revision 7, horizontal scrolling, inked S-curve trails, walked/reachable/bypassed trail
  states, the lantern's walk), judged natively against the mockup; Codex does the code review only.
- warband-built: NEEDS CHANGES (2026-10-21 14:57), playtest build fd9adb42c (before the orders). "This is a bit of a mess
  atm tbh. We're getting massive frame drops, the introduced UI effects are crude shapes, not polished to the level we
  want imo, the direction of the wind keeps changing every time I move with no discernable reason. I do like the idea
  here, but it needs some work before it's playable enough for me to know if its even fun." Also: the warband should
  not start grouped on one side; spread it "so that 1. the player has the ability to take them out 1 by 1 or slip past
  some to get to the leader 2. they don't spend the first couple of turns just bumbling over each other". Director
  plan (Warband rework): profile and fix the frame drops first; the wind direction locks when announced and only
  re-aims on the Stormcaller's own turn; the director redesigns the Warband markers (command zone, captain mark, +1)
  with a mockup in the inbox before building; followers spawn spread in small groups at varied distances with gaps to
  the captain. Then a new playable build.

## 2026-10-22 owner note: Petrify card text
"It adds a keyword for it that has its own icon that explains the effect, but then it also explains the effect in words... we have to choose one or the other, not both." Director decision: keep Petrify as a keyword (it is a real status the relic spreads and the turn order shows); card face = Petrify icon + range 3; the 5 Block becomes part of the keyword on every source. Unit fix-07.

## 2026-10-22 owner note: Skybolt power
"Is the power level of skybreak [Skybolt] not obscene, even for a legendary? ... an infinite range shock seems pretty bonkers. We may need to give it a drawback if we want it to have that kind of upside. Let's throw evaluating that into our queue." Queued as bal-01 (director evaluation, options to the inbox).

## 2026-10-23 warband-markers-v2: NEEDS CHANGES
"The ghosts work, I think, but we need some clearer indicator of the wind effect and direction, as well as its source
... the particle effect wind gusts that we have for decoration don't flow in the same direction as the actual
mechanical indicator gusts ... maybe we just disable them for now and bring them back later." Director decisions
(wind-01, director-implemented, Codex reviews only):
- Air rooms' decorative gusts off behind one flag (`AIR_DECORATIVE_GUSTS_ENABLED`): the drifting ambient wisps (one
  random left/right drift per room) and the gust-curl floor overlays (randomly flipped). Restore later, reworked to
  follow the wind.
- The wind is drawn as paired streams (main + shorter companion, the wind icon's motif) with the Dive flight's width
  profile, entering at the upwind board edge and leaving at the downwind edge; called-but-not-blown wind at 0.4 alpha
  vs 0.62.
- The push shows a wave of streams crossing the board with the slide.
- Source: the Gale Herald/Stormcaller gets the wind sigil badge ("Calls the wind. Defeat it and the wind stops.") and a
  three-arm whirl at its feet. Streams do not start at the source: its wind often blows toward it.
- The chip names the source ("The Stormcaller's wind · until it falls", "<Name>'s wind · N rounds", "Headwind · toward
  the entry") and docks above the objective (or the play meter); it was anchored to the hidden turn-order panel.
- The Snare headwind blows toward the entry, so it enters from the far side (the reply said "the entrance"; corrected
  in the mockup item). Mockup posted as inbox `wind-v3`.

## 2026-10-23 element rules: owner direction, two corrections, APPROVED (revision 3)
- Owner direction: "each element have a core mechanic that is reused but remixed across every special encounter... not
  have a bunch of new keywords, custom rules, etc." Wind is the exemplar.
- Correction 1: revision 1 named primitives ("Fire ground is a primitive, not a rule"). Revision 2 turned each element
  into a beat like the Gust.
- Correction 2: no one-off rules ("anti-design"). Specifically: drop "Ice and stone don't catch" (placing ground
  replaces ground); rename Hard Frost to Frostbite and the Strike to Lightning Storm; reach via Chain, never "touching";
  Eclipse makes no sense (the hero is always lit; it restated the Umbra). Each rule gets an in-game name, icon and one
  sentence shown above the objective.
- APPROVED revision 3 (2026-10-23 20:56): "Let's try this as described and we can iterate once I see and feel it in
  person." The six beats (Gust, Wildfire, Frostbite, Lightning Storm, Upheaval, Shadowstep), fights varying only by
  dials, the Break meter and the "wielder immune" rule dropped, and ordinary enemies on the same pieces.
  Pages: `encounter_redesign/element_rules_v{1,2,3}.html` (v3 approved).

## 2026-10-27 gaoler-rig: NEEDS CHANGES (rr-42 Gaoler on rig v2)
- Owner: "His arms don't move naturally while he walks, one wiggles the other is still." Director-confirmed: the
  `move` gait swings only `hand_near` (3 px); the chain arm is held still and only the chain sways 3°.
- "The way he's holding the chain is super unnatural, like someone holding a lantern out in front of them, not like
  you'd hold a chain that you are going to swing." The pose is in the approved mq3 paintings (far arm raised and
  outstretched at shoulder height); a rotated cutout can't lower it without tearing ([[cutout-joint-budget]]), so the
  chain arm is repainted in both views: hanging low at his side, fist at the hip, a short slack loop in the fist, the
  hook at shin height.
- "I feel like the hook should point the other way." In both views the hook's point curls back toward his body; the
  repaint mirrors it so the point curls away from his body (the way he faces).
- "The non chain arm bends the wrong way during attack and hit, like he's got no bones." Director-confirmed in the
  review clip (press wind-up): the near arm is almost straight at rest, so the two-bone solve's bend side is ambiguous
  and the forearm folds backward (hyperextension) whenever the fist nears the shoulder. Fix: a declared elbow bend side
  per arm and view, plus a gate that fails on any frame where an elbow bends backward, run over every rig.
- "Death animation is perfect, love dropping the chain, no notes." Keep its choreography; only the drop height changes
  with the lowered fist.
- Reply posted and the thread resolved. Work: director repaint (image edit, staged/rr-44) → still posted to the inbox
  for a quick look → rr-44 rig unit.

## 2026-10-27 inbox verdicts (playtest-13 fixes)
- APPROVED: heirloom-screen-built, pt13-boss-preview, pt13-torches, pt13-dial-graftwright.
- lancer-rig-v2 APPROVED. "There's some perspective issues where parts of the spear handle show through that
  shouldn't in both front and rear view." This is logged as low priority in `backlog_art.md` #1.
- pt13-badges NEEDS CHANGES: "flip to either bottom right or bottom left depending on what is going to cover less".
  Built in pt14-01: rest-silhouette coverage, the hero weighted ×2, a 15% margin.
- pt13-mirror NEEDS CHANGES, on the evidence: "These pictures are completely busted. The overlay tiles aren't lining
  up with the actual floor tiles. There's also stuff overrunning. Our evidence needs to be as game-like as possible."
  - The probe forced a proof-only camera and packed four Mirrors around the hero.
  - New standing rule: owner evidence comes from real game flow.
  - pt14-02 builds `tests/real_fight_capture_probe.gd` and root-causes the probe's offset. The Mirror evidence will be
    redone from real fights.
- New inbox item `gaoler-pose`: the repainted chain arm still, posted for a look before rigging.

## 2026-10-27 prop-lighting-spike (lit-01): SHELVED
- Owner (chat): "It's so subtle I can barely see it. Maybe we just stick with our custom shadows and lighting for
  now."
- The game keeps its custom CombatArtTreatment lighting and contact shadows. lit-01 stays unmerged on
  `codex/lit-01` (49ef9f92a) for reference: the Sprite Fusion normal-map port, prop shading and torch-cast prop
  shadows, all behind `LABYRINTH_PROP_LIGHTING`. Don't propose normal maps on enemies unless the owner raises it
  again.

## 2026-10-27 playtest 15: the fire Warband (the Slagmaster)
- "The enemy composition mix felt pretty reasonable."
- The Slagmaster "spent way too many turns just running away and blocking instead of tossing slag". Diagnosis: Lob needs
  range 3–6, Brace also moves away 2, and the captain's keep_distance adds more retreat. Fix in **enc-03**: Lob range
  2–6 at weight 4; Brace (block only) and Scatter only when the hero is adjacent.
- The intent "/4 ... range 3 to 6" isn't clear. Fix in **enc-03**: the lob icon plus centre damage, a plain callout
  sentence, and landing tiles marked from the aiming turn.
- A foot drawn under the floor (draw order), slow movement against the other enemies, and a slow death. Fix in
  **rr-46**: rig-v2 move and death timing match the older enemies at every combat speed; draw-order sweep and check.
- Owner: "Directionally, I think it's largely right ... we need to keep making this really, really high level."
- 2026-11-05 00:21 txt-4 APPROVED ("Area Attack is gone everywhere"): codex/txt-02 cc188142d merging into release.

## 2026-11-05 settings-1: APPROVED (inbox)
- Owner: "[settings-1] APPROVED — Settings in plain words, styled sliders, and Edge smoothing: the likely cause of the Deck stutter". Merges ui-10 (Settings copy, reset confirmation), gfx-01 (Edge smoothing High/Low/Off; Steam Deck default Off, desktop High) and ui-13 (skinned sliders, modal Settings over the main menu, Sell without MAGIC). Deck stutter still to be confirmed by the owner on hardware.

## 2026-11-05 purge-1: APPROVED (inbox)
- Owner: "[purge-1] APPROVED — Purge keeps its spells inside the frame; Sell's page arrows read". Merges ui-11.

## 2026-11-05 sd-4: NEEDS CHANGES (inbox)
- Owner: "In the 7 card hand I don't see what got fixed, but I do see the card play widget over top of the hand in both before and after. That seems like an issue to fix." The overlap is sd-05's fix (chips under the objective panel); sd-4's 7-card change was only title fitting, and its shots came from the controller sweep fixture (not real game). Action: sd-08 builds real-fight before/after captures of sd-04 + sd-05 together at Deck size; repost as one item.
- Owner in chat (same day): "I hadn't seen sd 5 when I reviewed sd 4. I agree it addresses the problem." Then chose "Merge both now": sd-4 + sd-5 APPROVED; sd-08's real-fight captures still go to the inbox for a final look.

## 2026-11-05 inbox verdicts (page, 12:38-12:57)
- APPROVED: fx-4 ("Much better!"), hud-2b (clip of landed hud-02), fx-6, fx-7, ui-12, au-1, ui-14, sd-7, ui-15, qa-51.
- hud-3: "No changes needed, but I do want to see this in motion. Frame by frame stills doesn't give me a great feel of how it looks in action." -> real-game true-speed clip.
- hud-4 (acting-enemy tile marker): "Not a fan of this change. It's too busy imo. Let's shelve it." -> shelved, not merged (branch codex/hud-04 kept).

## 2026-11-05 master push
- Released as one squashed commit 4c1547f19 on master (tree of release f0af5a0be): everything approved since the 2026-11-04 push. Full Godot 140/140 and Python green at f0af5a0be; qa-56 hunt clean.

## 2026-11-05 inbox verdicts (page, 17:51-17:54; relayed by the wishlist session, confirmed in the saved state)
- APPROVED: qa-54 (controller targets what a mouse can), hud-3b (hud-03 in motion: approves hud-03), ui-18 (boss named once, Deferred Choice panel), au-2 (returned Card Play cue, event hover ticks), sd-4-5-real (FYI).
- NEEDS CHANGES: fx-8 (guardian arrival): "I like this in theory but I think it only works if they have an animation where they make some sort of threatening motion accompanying it, like we do with the dragon roar." -> guard-02.

## 2026-11-05 owner (chat): Steam build bugs
- "In the current steam build, the turn order widget is missing. Also, there's a weird lag during the events for popping up the previewed results." Then: "could the turn order issue be an export problem since it shows when run directly but not through steam?" -> qa-59. The dev Mac's Steam install is the 2026-11-03 push (f206d3813), played 18:34-18:40 UTC at 1920x1205; event telemetry 7 frames > 50 ms per minute (max 142).
- 2026-11-05 21:08-21:10 APPROVED (page): ui-17, guard-2 (no answer on the camera-push question; none added), txt-5.


## 2026-11-07 owner (chat): Steam Deck demo playtest
- Board too small, hard to read and a little fuzzy on the Deck. Pull it down and make it bigger; let the hand cover part of it, since the hand hides while a card is selected and X hides it any time. Applies to the full game too -> ux-10.
- B opens the menu, which "drives me insane". B should hide the hand and back out, and never open the menu; only Start opens it -> ui-27.
- Remove the controller glyph bar at the top; put each glyph on its control (Y on Pass, X at the hand's corner) -> ui-28.
- Map navigation with the stick should go to the nearest room in the pointed direction, jumping between paths -> ui-27.
- Performance "a little chuggy at moments, but it's actually not too bad", improved since their last Deck session.
