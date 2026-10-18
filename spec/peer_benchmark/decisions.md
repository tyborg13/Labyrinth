# Peer-benchmark decisions log (binding for this program)

- 2026-10-12 OWNER: program scope = everything (visual, audio, mechanics, content, map, events, cards, enemies, level gen);
  bold changes allowed; prior Codex-era approvals not binding; experiment lives on `codex/peer-benchmark`.
- 2026-10-12 OWNER: blanket permission to download CC0 or otherwise free-for-commercial-use assets that fit and meet
  the bar. Rule: record source URL, licence text/terms and sha256 per asset in a provenance file; never NC/ND/unclear;
  no account creation or logins.
- 2026-10-12 OWNER: use orchestrate-codex (Claude decides taste, Codex implements); keep the owner in the loop with
  screenshots/clips; inspection fixtures only for feel-critical work.
- 2026-10-12 CLAUDE: Events are data-driven (data/events.json), 27 authored events (15 shared, 2 per dragon element, 2
  shadow-only in section VI), illustrated full-screen view per mockup output/peer-benchmark-2026-10-12/mockups/
  event_choices.png. Exact effect lines, costs red / gains gold / banes violet / odds neutral; locked choices stay
  visible with a reason (StS grammar). Omens = timed blessings/banes (11), our analogue of StS curses-for-power.
- 2026-10-12 CLAUDE: Event art style = pixel-painted dark fantasy matching key art + card art; 1536x1024 3:2, edges dark.
  Approved pilots: hanged_knight, frozen_champion, bloodletters_basin (spec/peer_benchmark/staged/event_art/approved/).
- 2026-10-12 CLAUDE: Map revision 4 = StS rules adapted: 4 lanes, 5 non-crossing walks, fixed rows (step 1 fights,
  mid treasure row, Hearth row before boss), mystery "?" rooms (event 70/combat 20/treasure 5/scavenger 5), several
  optional Guardians (≤1 per route), full visibility in sections I–V, section VI keeps fog (heart of the Umbra), Scout
  reveals mystery contents.
- 2026-10-12 CLAUDE: Feel: modest hit-stop (StS has none; ITB-style crunch) + damage-scaled shake + enemy-phase pacing
  budget (4-enemy round ≤ 6 s) + Combat speed setting. Next feel round candidates from StS research: HP-bar damage
  ghost (1.2 s hold), damage numbers that pop large and settle, round-robin SFX variants.
- Backlog from StS research: score tally + run history + compendium/stats (meta screen); Ascension-style 20-step
  difficulty ladder; daily seeded run with modifiers; event v2 (opt-in fights, push-your-luck, cross-event callbacks,
  harsher variants at high difficulty); tiered intent art by damage.

## 2026-10-12 — Wave-1 peer review outcomes
- Hero Expose works as displayed (director): master put Expose on the hero (Bile Bloomer Shard Mark 2, Noctyrax Void
  Claw 1) and showed it, but never consumed it. ev-01 made it consume on the next hit; we keep that (keyword text says
  so), add it to previews, score both enemies, and tell the owner it is a rules change versus master.
- Pause/menu must reach through an open event (Esc/Start).
- Debt (not now): combat_pacing reaches ~12 run_scene privates by string; EventRules/OmenRules call engine privates.
  Schedule a refactor unit once the parallel waves settle.
- Sound: round-2 designs are layered recipes (sfx-02 renderer), director-authored.

## 2026-10-12 — visual identity gate, art-02 fronts batch 1
- Independent judge (fresh subagent, rubric spec/art_identity/judge_rubric.md): 5/10 PASS (hoarfrost_seer, gale_herald,
  arc_thrall, storm_capacitor, gloam_stalker); FAIL briar_weaver (veined leaves, olive edge fringe), slag_mortar (head
  hidden under kiln), glacial_mirror (warm terracotta, reads as earth golem), gust_shrike (clone of roc_fledgling —
  both kit peers were that bird), hollow_mimic (bronze camo, not black glass).
- Fixes: process unmixes key blends in the edge ring (olive fringe); preamble gains "References are for camera, scale
  and hand only — never copy a silhouette"; shrike re-generated from a new silhouette subject (front_v2); the other
  four iterated as colour/detail/head edits of the same job.
- Lesson: duplicate peers bias copying; when an anatomy has one canon member, the subject must spell out a distinct
  silhouette.

## 2026-10-15 — sfx-04 loudness exceptions (director)
- Under the restored peak caps (impacts ≤ −3 dBFS, all ≤ −1 dBTP), two re-trimmed cues fall below the −1.0 LU window:
  `hit.blade.light_01` −2.131 LU and `hurt.hero_01` −1.255 LU. Accepted: both are light/secondary impacts where a slightly
  softer hit reads correctly; revisit only if a listening pass flags them.

## 2026-10-15 — ux-04 text decisions (director)
- Keyword/term tokens render in `UiPalette.GOLD_BRIGHT`, same font/weight, no underline, everywhere (one named constant).
- Graftwright donor result: "<Item> destroyed" ("consumed" stays reserved for the item Consume keyword).

## 2026-10-16 — owner decisions
- Self-hits from Meteorfall / Detonate stay amplified by the hero's Expose / Chilled / Frozen (owner: "Yes, I think so").
  Only Fatigue is excluded (fix-03). No change needed.
- Starting diversity: a run-start boon choice (pick 1 of 3), offered by the emaciated man at the beginning of a run;
  the heirloom (one equipment piece kept from the previous run) is one possible option, never automatic.
- Spell/magic slot limit: dropped entirely. Spells go straight into the deck (no equipping after fights); deck
  dilution is the cost, so card removal must be available.
- 2026-10-17 Opening boons list approved by the owner (review inbox item boons-list) exactly as proposed → boon-01.
- 2026-10-17 Roster plan posted to the review inbox (item roster-plan, awaiting the owner): waves 1–5 (static 11 →
  frequent regulars → other regulars/helpers → guardians → dragons), per enemy: Codex maquette via the bridge,
  director review, front/rear paint-over, rig, 60 fps clip to the inbox in batches of ~4.
- 2026-10-17 Frostglass Lancer r4 front painting approved by the owner (3/4 board facing). The rear r4 is held for one
  fix: it painted ~8% shorter than the front (hood tip 17 canvas px lower) with the cloak dragging on the ground. The
  repaint matches the front height (hood tip y 84, soles y 980 in the 1024 frame) and has a mid-calf hem with the
  boots visible. A front/rear height mismatch pops when a rig turns.
- 2026-10-17 rr-05 feature masks (director data, staged/rr-05/features): Bloomer crown gem → core (both views);
  amber nodules → trunk (front 3, rear 2, explicit occlusion otherwise); Wisp eye → core (rear occluded). Masks are the
  gem/eye body + 1 px rim (eye 2 px), holes filled.
- 2026-10-17 boon-01 decisions: Armory = random **rare** piece (no uncommon equipment tier exists; one step above the
  starters, as intended); Vitality +6 max and +6 current HP; resume label `CHOOSING AN HEIRLOOM`; secondary back
  label `Back`. Offer screen uses the post-combat reward idiom (three 300x400 cards with column tags, a `Take nothing`
  pill styled like SKIP & RECOVER, NPC dialogue box at the bottom); spell picks reuse the reward banner and card row.
- 2026-10-17 mq-03 cloak ownership: the cloth cloak splits per view by depth around the torso centre plane
  (far → cape_far, near/tie → cape_near), so cutout rigs keep two cape parts.
- 2026-10-17 OWNER approved the roster plan, ordered by need (inbox roster-plan): new enemies first, then the ones
  least matching the style and/or with a wrong pose, then decide on the good ones (Stone Warden, the cultist =
  Dust/Veilbound Acolyte: lowest). Director order (10-13 legacy audit severity + view failures):
  1) 11 new static: Ember Tick, Hoarfrost Seer, Gale Herald, Arc Thrall, Gloam Stalker, Burrow Grub, Storm Capacitor,
     Hollow Mimic, Briar Weaver, Slag Mortar, Glacial Mirror;
  2) High + wrong pose first: Chainbound Gaoler (re-pose only), Ashen Reaver, Storm Cantor, Last Lamplighter,
     Gallows Roc, Rimejaw;
  3) dragons (all High; Noctyrax wrong view), started alongside 4 because wing maquettes take longest;
  4) Medium + wrong pose: Wick Shade, Ash Hound, Roc Fledgling, Stoneback Mite, Cinder Ooze, Bell Tender;
  5) Medium, style only: Bone Harrier, Rime Whelp, Craghide;
  owner decides later (likely keep): Stone Warden, Dust + Veilbound Acolyte, Grave Surgeon, Cinder Droplet,
  Tunnel Crawler, Rime Spitter.
- 2026-10-17 CORRECTION (mq-03 cloak): the depth split put the whole cloak in one part per view (it hangs behind the
  torso in front, in front of it in rear). The cloak now splits by body side in body space: faces on the
  shoulder_near side of the sagittal plane are cape_near, the rest cape_far (ties near), the same in both views, like
  the limb labels (hand_far = spear hand in both views). Feedback 5 also requires deterministic cloth-cache replay hashes.
- 2026-10-17 Roster wave 1 (the 11 new enemies) keeps their owner-approved art-02 paintings: they are already in the
  3/4 board facing and the house hand. Maquettes are fitted to that art to give the rigs parts and joints. They are
  repainted only if a fit or pose fails. Batch A = the four humanoids (mq-04); director part lists are in the brief.
- 2026-10-17 Gale Herald banners: both approved paintings trail the banners screen-right, which reads as one consistent
  wind direction on screen. The maquette gets a per-view cloth pose for the banners only; the body, joints and other
  parts stay one model turned 180°. The rule applies to any figure whose approved views share a wind direction.
- 2026-10-17 Cutout seams: parts may bleed edge-texel support under their neighbours (margin = max sampled joint
  separation + 1 px, inside the rest silhouette union, never visible at rest, never across features), so no pose shows
  background between parts. The no-new-hole gate stays strict.
- 2026-10-17 flow-01 section-entry save failure: the transition reverses to the cleared boss room with the dragon
  reward screen and the existing notice "Could not save. Your rewards are still here; try Continue again."; CONTINUE
  retries. The title card gets a 50% dark band, an accent-gold 24 px label and the reward-banner text shadow.
- 2026-10-17 REVERSAL: roster wave 1 is NOT rigged from the approved art-02 paintings. Owner (on the Lancer): mixing
  maquette-based and original-art enemies keeps the style inconsistent, so every enemy gets maquette → paint-over
  (approved art as the identity reference) → rig. The fit gate relaxes to IoU ≥ 0.70 front / ≥ 0.65 rear (proportion
  guidance). The maquette quality bar is the Lancer r3: cloth hood, robe and cloak, real anatomy and plates, no
  primitive cones or cylinders for cloth. mq-04 r1 delivered primitive shapes (rejected); r2 does Seer + Thrall first,
  then a director clay review.
- 2026-10-17 Cutout rigs get a static silhouette backing: the rest silhouette in the painting's darkest interior tone,
  drawn under every part and attached to the root body bone. Covered at rest; gaps opened by moving parts read as
  shadowed depth instead of background tears. Visible backing ≤ 3% of the body in any pose. Generic for all maquette
  rigs.
- 2026-10-17 REVISED (rr-05): the full-silhouette backing is rejected (it showed as black blobs where petals swing).
  Cutout seams use per-joint seam underlays instead: a thin band along each joint, painted from the parent, drawn
  beneath all parts and attached to the parent. The gate is no background inside the rest silhouette (eroded 1 px).
  Natural negative space outside the silhouette is allowed; underlay protrusion is limited to ≤ 2 px.
- 2026-10-17 Typed-array rule as applied: typed declarations with literal initializers (`var x: Array[T] = []` or
  `= [a, b]`) are established practice (~1,200 on master) and allowed. The Windows hazard forms that must be fixed
  are conditional branches producing untyped literals, and bare-literal assignment to an already declared typed
  variable.
- 2026-10-17 Legacy saves without a recorded dragon reward summary: the re-shown reward screen omits the unknown
  Ember/Moltshard lines. No placeholder text ever reaches players.
- 2026-10-17 rr-05 acceptance (final): blocking = no detached pieces, feature integrity, zero shimmer, rest identity,
  native agreement. Seam tear, protrusion and negative-space measures are report-only (some poses can't satisfy both
  constraints). The director judges the native clip by eye.
- 2026-10-17 AMENDED typed-array rule (reviewers read AGENTS.md strictly): new code declares empty typed arrays
  without a literal (`var x: Array[T]`) and builds non-empty ones with typed helpers or append/assign. Existing
  declarations with literal initializers on master stay untouched (no mass rewrite). Reviews flag new violations only.

## 2026-10-17 rr-05 final-proof review
- Native check: an exact texel tie (snapped `u` or `v` within 1e-6 of an integer) may resolve to either neighbour, because
  the Metal sampler's tie direction isn't reproducible on the CPU. Every other pixel keeps the 1 px + 1% rule, and held
  shimmer stays 0. No percentage guard: whole scanlines tie, and non-tie pixels still catch broken transforms. Tie counts are reported.
- Hidden support must never read as dark slabs.
  - New blocking gate: in every posed frame, exposed hidden or seam material may not contain an outline-class component
    with a full 3×3 block.
  - Support fills take interior (non-outline) donors.
  - Hidden-only parts are limited to their painted fill plus the joint margin.
  - The rear trunk socket may be recoloured where it's exposed.
  - Cause: the 7 px dilation filled from the outline in `continuity.underlays()`.

## 2026-10-17 bug-01 review resolution (5b12d3630)
- Scene-prop changes (rare) invalidate exactly, by comparing the effective alpha through the draw path's tint for every
  tinted rectangle, moss included.
- Actor movement (every interpolation frame) stays conservative on purpose. It queues a tile when a moving actor's
  overlap with any tinted rectangle changes, even if a stationary actor already fixes the alpha.
- An occasional extra tile redraw is cheaper than recomputing every candidate's full tint on every frame, and it can't
  produce a stale frame.
- So review finding M1 on 5b12d3630 (redundant moss redraw while a warden walks past a hero-obstructed pillar) is
  accepted as by design. Every other check in that review passed, and bug-01 is signed off at
  5b12d3630e7d488ab541132e63de5e9e1ca25034.
- 2026-10-17 rr-05 fb12: the dark-slab gate blocks derived (pipeline-generated) texels only. Exposures of approved
  painted fills are reported, not blocked: the Wisp's original tail shadow (29,18,26) is approved paint.
