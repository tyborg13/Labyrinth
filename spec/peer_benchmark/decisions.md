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

## 2026-10-17 qa-08 review resolution (fecdbf24e)
- The registration audit is a conservative heuristic. These are documented limits, not fixed, because none of the
  patterns occur in tests/ and a fifth round isn't worth it:
  - a never-invoked lambda body counts as reachable;
  - StringName/NodePath literal arguments aren't read;
  - \U escapes aren't decoded.
- The last two fail loudly as orphans, so the fix is to use a plain string.
- Every other item in that review was verified. qa-08 is accepted at eec098b526aaf8f61af80fab786c91d6e06c59a3 (fecdbf24e plus the limits docstring).

## 2026-10-17 mq-04 frozen clay bytes
- The r3 Seer and Thrall clay and part-map PNGs were re-encoded during curation. The original files were never
  committed and curation deleted them, so their bytes can't be restored.
- Pixels are verified identical to the paint-over kits' references, and pixels are what downstream consumes. Accepted;
  staging now preserves bytes from here on.

## 2026-10-17 roster wave 1 batch B
- Storm Capacitor skips the maquette and paint-over. Its body is rotationally symmetric, so the current painting is
  already correct from every angle. It is rigged straight from its current art (base, glass core with arcs, bands,
  cap) in a later rig unit.
- Glacial Mirror is rebuilt from irregular, chipped boulders with modelled relief, never clean cubes (owner: no "toy
  soldier" shapes).

## 2026-10-18 rr-05 accepted at 0ebbc5b07
- Re-review 0ebbc5b07 verified all three round-13 fixes (12/12 mutations caught, full Godot pass).
- Its one remaining item asked for the native capture bundles, which are untracked by design (about 57k files under
  the worktree's `output/rr-05/`). The director ran the native recheck at HEAD 0ebbc5b07 in the rr-05 worktree:
  `native_errors` 0 and pixel gate ok with 0 errors, for both the Shale Bloomer and the Lightning Wisp.
- The owner approved the final Bloomer clip on 2026-10-18.

## 2026-10-18 rr-07 rig hierarchy (pelvis-less figures)
- Seer: root body → torso (root body part) → collar and the head; skirts are torso children pivoting at the belt;
  feet are root children so they stay planted; staff_crystal is always a child of staff_shaft.
- Thrall: root body → torso and both thighs; collar and loincloth are torso children.

## 2026-10-18 det-01 accepted
- The review (2c94e72b4) confirmed both root causes, with 5/5 mutations caught. Its Medium (the staged startup missed
  the arrow connection) is fixed in round 2 with an idempotent connection that both paths run, plus regressions for
  both paths: the removal mutation fails both.
- Accepted by the director on that bounded delta. The Low was integration docs that arrived through the merge.
- 2026-10-18 rr-07 fb2: the native tie band widens from exact ties (1e-6) to the GPU sub-texel half step (1/512
  texel). The near-tie mismatches seen in rotated "before" poses are inside it. Still only two legal candidates and
  held-frame consistency.
- 2026-10-18 rr-07 fb3: an invalid-tie pixel (native matches neither legal candidate) counts as one changed pixel
  under the existing 1 px + 1% allowance instead of failing outright. The rr-05 23-pixel edge-deletion regression
  still fails.

## 2026-10-18 humanoid rig v2 (owner verdict on the Seer)
- Binding for every humanoid maquette rig: `spec/peer_benchmark/humanoid_cutout_rig.md`.
  - Idle: the protagonist's cut-out bob. Three rigid groups (upper body 2 px, the weapon arm lagged or still, the
    lower body still), 0.84 s, no rotation and no deformation.
  - Cut: robes, cloaks and sleeves are one skinned mesh each; the collar is part of the torso; joints are covered,
    with a 3 px tuck.
  - Actions: translation-led. Hands are placed by two-bone targets; held items keep their world angle unless keyed
    (≤ 35°); torso ≤ 4° and head ≤ 6°.
- Supersedes the idle notes in `staged/rr-07` and `staged/rr-08`, which forbade a whole-body bob.
- The rr-06 (Lancer) and rr-08 (Herald, Gloam) runs started before this. They are not killed (owner rule). Their
  results are reviewed for reusable pipeline parts only, and each figure moves to v2 in a later unit.
- Seer v2 motion: `staged/rr-10/motion_tracks.json`, in source pixels. The ward pushes the staff out ahead rather than
  across the body, because the staff is on the body's far side in the front view and would hide behind the torso.

## 2026-10-18 mq-06 scope change (fix round 4)
- Root cause: the Seer fit faked the far foot's screen height by lifting it 0.157 m. The 180° turn itself was exact.
- After three rounds of preserving the front pixel-exactly while re-posing the body (the cloth solver fights it), the
  front is frozen instead (approved painting + delivery; rr-10 uses them). Only the rear is rebuilt, from a body with
  the far leg planted. The small 3D mismatch at the far foot is hidden under the robe in the front view.
- Rear capture is pan-only framing, never rescaled. The rear IoU gate drops to ≥ 0.60 against the old painting
  because the corrected stance legitimately differs; the director repaints the rear anyway.

## 2026-10-18 rr-13 review split
- The Codex review of Seer v2 (`feedback/rr-13_review_4c3f86339.md`) found four Medium and two Low issues.
- **rr-13 fixes now** (feedback 2): the hole-gate locality gap, empty bone evidence passing, surviving limit and
  threshold mutations, and the layout-copy parity.
- **Deferred to rr-11**, the second humanoid, which needs both: foot IK with knee bend, and moving Seer specifics out
  of the generic modules. The Seer wears a robe; its feet ride the hem, so neither finding changes what the Seer shows.
- 2026-10-18 rr-13 final: the 2 px front death 27-30 robe/torso waist pinhole is a director-approved exception (its
  mapped texels are transparent in the approved painting; closing it would change the approved rest silhouette; it is
  in the owner-approved clip). Re-review Low 2 (direct tests for the continuation generator's guards) moves to rr-11,
  which generalizes that module.

## 2026-10-18 knee direction (rr-14 review)
- Knees bend toward the figure's facing: screen-left in the front view (facing the lower-left), screen-right in the
  rear view (facing the upper-right). Straight-at-rest legs must declare it per view in case anatomy; bent legs keep
  their rest side. Recorded in `humanoid_cutout_rig.md` §3.

## 2026-10-18 Thrall gait (rr-11 TODO_DESIGN items)
- The Thrall's legs are almost straight at rest, and each view has one foreshortened leg. Decided: near-straight rest
  knees (within 6°) take the facing policy; per-view `stride`/`trailing` leg roles; the pelvis never above rest, dipping
  3 px after stride landings and under the jab; the knee gate checks peak bend per stride swing. The director revised
  `staged/rr-11/motion_tracks.json` accordingly; the rules are in `humanoid_cutout_rig.md` §3.
- purge-01 merged at 6302747af, then was reset off integration: the SFX sync harness failed deterministically
  (`ambience.tharokh` loop waits after its state change) and the registration audit flagged
  `magic_deck_guard_mutation_test.gd`. Final fix round: feedback 3.

## 2026-10-19 master checkpoint (owner approval)
- Owner, 2026-10-19: "After this batch of changes, let's go ahead and merge into master, just to checkpoint while we keep
  making progress."
- Batch = purge-02 (Purge polish) and pace-02 (enemy actions at 0.8×), the two owner notes in flight. When both are
  merged into integration and the full suites pass at that exact HEAD, publish with `tools/parallel_task.py
  authorize-publish` and `push` (lands on origin/master). The Thrall (rr-15) joins a later checkpoint after owner review,
  unless it has landed by then.
- 2026-10-19 sidecar noise (owner: "handle it permanently"): the director committed the 10,664 missing `.import`/`.uid`
  sidecars of tracked assets (bf68dc2ce) and removed a stale `.uid`; qa-14 adds a guard test and a workflow note. When an
  in-flight worktree syncs integration, first delete its untracked copies of the newly tracked sidecars, then merge and
  run a headless import.
- 2026-10-19 checkpoint PUBLISHED: `origin/master` = 209cbc67c (integration at that commit: Godot PASS, Python 1019 OK;
  `authorize-publish` recorded at 02:31Z). Included pace-02, purge-02/03 (+ a director null-viewport guard, Codex
  SIGNOFF), qa-14 and the sidecar commit. The primary checkout's local master update was skipped (untracked files);
  the owner's call. Follow-up: the optional Purge lifecycle regression suggested by the guard review.

## 2026-10-19 Thrall rear tube aim (rr-15)
- The rear jab and tether looked backward. The rr-15 trace showed the shared tube targets fell inside the arm's minimum
  reach in the rear (43 px against 56.47), so the elbow folded outward. Decided: per-view key overrides
  (`view_keys.<view>`) in motion data. The rear jab contact aims about 90% extended toward the rear facing at shoulder
  height (forward 209 / lift 50). The rear tether hold is forward 206 / lift 63. A new gate keeps every two-bone target
  inside its reachable annulus.

## 2026-10-19 Glacial Mirror before its rig
- The mq-05 Mirror maquette breaks the shoulder rule: front `shoulder_far` (280, 332) sits 24 px below `shoulder_near`
  (722, 308); the rule needs about 66 px above. The 180° turn shows the body's right shoulder ~66 px lower in 3D, so
  the golem is lopsided, the same defect the owner rejected on the Thrall. The mq5 paint-over also dropped the far
  pauldron boulder, so the far arm hangs from a small, low shoulder.
- Fix before rigging: mq-08 levels the shoulders in 3D and reshapes the far pauldron into a shoulder mass like the near
  one; the director repaints both views from the new clays (rounded, chipped boulders with painted value steps and
  worn texture, not flat polygon facets; follow the clay's shoulder masses). Then the rig (humanoid v2, every piece
  rigid: boulders overlap at the joints; both arms are free arms in the idle upper-body group).
- Other maquettes measured against the rule (front, far higher by / rule): Gloam −56 / 48 and Herald 8 / 34 also fail;
  Seer −12 / 35 (owner-approved, robe and collar hide it); Lancer far 103 above. Fix the Gloam and Herald in their own
  v2 conversion units, checking the Herald's torso yaw (its shoulder line is nearly square to the camera).

## 2026-10-19 Glacial Mirror rig (rr-18) design answers
- Gait: the step-to walk world-planted the foreshortened far leg, which can't reach. Every humanoid with a foreshortened
  leg uses the Thrall pattern: the long camera-side leg strides in two half-tile world steps, the other follows the body
  with a small shuffle. The Mirror's is heavier (5 px stomp, 1 px torso jolt on each plant).
- Rigid boulder knees resting up to 10° backward are declared near-straight (`knee_policy.near_straight_deg = 10`), so
  swings bend toward the facing.
- Rig production rest identity is measured against the density-processed rest (board-density rule, sealed by the
  windowed rest step). The authoring cut stays exact against the painting. Same precedent as the Thrall and Capacitor.
- rr-17 review: in a multi-kill each dying creature keeps its own death clock; a long Capacitor death never stretches
  the others. Every chain hop plays its cue once, including under reduced motion and skipped callbacks.
- Seam rule for rigid-piece golems (Glacial Mirror): air opening between separate boulders is in character. A pocket
  passes only when every pixel maps to air in the approved painting or outside every boulder's painted area and tuck. A
  hole through stone or a joint tearing open still fails. It is a case-level policy, not frame exceptions; every other
  figure keeps the strict rule.
- Green gate (all rigs from rr-20 on): it targets chroma-key residue only, G ≥ max(R,B) + 12 AND G ≥ 1.5 × max(R,B).
  Residue texels in the derived presentation are replaced by the nearest non-residue texel of the same piece.
  Declared feature masks are exempt (the Weaver's green eye). Olive and brown paint is legitimate.
- Slag Mortar ownership: the crucible owns only iron greys and molten oranges; skin and leather under it belong to the
  torso or the near upper arm. The bracer belongs to the forearm, and the fist starts at the bracer's lower rim.
- Weaver gait: a hunched rest bends the stance knee, so the stride lift is 7 px and the pelvis sits at rest height at
  each swing apex.

## 2026-10-19 Humanoid walk on the protagonist's model (owner: the shuffle reads as a limp)
- Owner, Mirror: "One leg is kind of shimmying and the other is mostly still like he's limping along." The stride +
  trailing shuffle is retired for every v2 humanoid (supersedes the rr-18 gait answer above).
- 2D reach analysis (director sim, legs and steps measured from the five rigs' layouts; one tile = 138.4 canvas px,
  2.6 to 4 leg lengths). A step-to walk (two half-tile steps per foot) plants a foot up to 0.28 tile ahead of the hips,
  far beyond any 2D leg. A rest-to-rest walk at 5 steps per tile needs 10 to 12 px pelvis drops on the Thrall and Mirror
  front views. At 6 steps the drop is 1.3 to 2.4 px with the hero's projected leg scale, and at most 4.9 px for the
  Mirror's rigid legs capped at 1.14.
- Decision: every humanoid walks on the protagonist's model (`scripts/protagonist_cutout/motion.gd`):
  - 6 steps per tile, rest to rest: an opening half step, four full steps, a closing half step; the near foot leads;
  - 60% stance, world-planted; the hero's Hermite swing and lift;
  - lanes narrowed 70% toward the thigh, changing only in swing;
  - the hero's projected leg scale, 0.78 to 1.22 (skinned) or 1.14 (rigid pieces: the joints space out and the pieces
    stay rigid);
  - an authored per-step settle, then the hero's pelvis fit (at most 6 px);
  - the arm opposite the swinging leg swings forward.
- Gates: planted stances on both legs; the knee peak and apex on every swing; no overreach; rigid air ≤ 3 px per joint.
- Cadence: 6 steps in 0.85 to 0.9 s is about 6.7 steps/s, the hero's own cadence. The Mimic's move lengthens from
  0.7 s to 0.8 s so that its 6 steps don't scurry.
- Format: a `gait` block in `move` (rig spec §4) generates root, feet, pelvis and arm swing; the director keys the
  rest. Shared code is gait-01 (Thrall, Mirror). The Mimic, Weaver and Mortar adopt it in their next round.
- Glacial Mirror repaint for the owner's fixes (mq8b, identity gate PASS): both hands are matching knuckled boulder
  fists, and the loose foot is a heel-and-toe boulder under its ankle; nothing else changed. In the 3/4 front view the
  near arm is the camera-side arm, so `fore_near` and `fist_near` draw above the torso and head (the guard bug).
- Arc Thrall repaint for the owner's fixes (mq7b, identity gate PASS): a broad iron collar low on the shoulders,
  below the jaw (rear: an even band, no upturn), and a ragged hide skirt wrapped around the hips with a rope belt,
  centred, to mid-thigh. Both match the original art's costume placement. The re-cut is rr-24.
- Post-merge oracle fixes for rr-18 (director, a few lines): the pre-battle oracle (38 cutouts / 5 stills), en05
  (the promoted Mirror owns its cutout feedback), the travel-pace protected-duration list (Mirror → staged rr-18),
  and the supplemental program count (125: rr-17 and rr-18).
- Process: never commit to integration while its merge suites run. A director commit moved the branch mid-suite and
  failed one task-queue test (`test_verified_handoff_file_completes_queue_without_flag_bridge`), which passes on a
  stable branch.

## 2026-10-19 afternoon: rig cut rules and unit splits
- **Negative space vs holes** (rig spec §1, every humanoid). An enclosed transparent pocket passes when every pixel
  maps to air in the approved painting. It fails when any pixel maps into paint or tuck.
- **Strict detached provenance** (rr-26, after the rr-20 review's blocking finding). A detached opaque component passes
  only when it is detached in the approved painting and moves rigidly with its owner, at any size or darkness. The old
  "tiny dark outline" exemption no longer applies in the provenance classifier.
- The strict rule found 1–3 px fragments in the approved Seer (move, death) and the Mimic (mirror); rr-26 fixes them.
  The old Thrall cut also had one; it is re-checked on rr-24's new cut.
- **Thrall collar** (rr-24). Wherever the head and the collar overlap, the head draws above it, so no collar pixel
  covers a head pixel. Contact is allowed: the chin rests on the band in death.
- **Mortar crucible masks** are director data (hand-authored polygons plus the rim's silhouette outline). They were
  widened twice to take in rim fragments; all reported fragments are now inside.
- **Fresh sessions after three fix rounds:** rr-25 continues rr-22 (Mortar) and rr-26 continues rr-20 (Mimic), on the
  same branches.
- **Merge order** (keeps integration green under the strict rule): rr-23 Mirror, rr-21 Weaver, rr-24 Thrall, rr-25
  Mortar, then rr-26 after re-running its census on the merged Thrall.
- Proof capture speed (owner agreed): crop production capture frames to the actor's bounds plus a margin and use fast
  PNG compression. The gates check the same pixels. A tooling unit runs after the current rig merges, so no in-flight
  proof is invalidated.

- 2026-10-19 (director): the Thrall's rear Tether keeps its owner-approved motion. The near-side upright hold (A, 65/153) failed the 60.5 px minimum-reach gate on every raise/lower path (rr-27 feedback 1-3), and the gate stays: it guards against the arm crumple the owner flagged. The fin is backlog.
- 2026-10-19 (director): Empower glossary copy is "Pay the extra cost as you play this card to gain its bonus. Charge it with the card's seal." (19 words; the ui-03 line was over the 20-word budget).

## 2026-10-21 master checkpoint (owner approval)
- Owner, 2026-10-21: "Let's finish the warband stuff so that we can merge it all", then, after the Warband difficulty
  data: "Ok, I'll trust the data till I can playtest. Let's ship it and I'll test for myself once it is on master."
- PUBLISHED: `origin/master` = d96eadf4f (integration at that commit: Godot 680 s PASS, Python OK; `authorize-publish`
  recorded). Included everything since 209cbc67c: the rig and painting fixes, Empower and its sounds, map-03 (revision
  7 maps), the special encounters (map placement, the Warband with its six orders, spx-07's fixes, the Umbral Snare
  core). Not included: wbv-01 (marker redesign v2, awaiting review), spx-06 (Snare pressures, in a fix round),
  meas-02 (measurement). The primary checkout's local master was not moved (untracked files; a fast-forward is safe).
- Playtest 11: frozen worktree ../peer-benchmark-playtest-11 at d96eadf4f (imported; start, combat and Warband
  fixtures verified). playtest-10 and playtest-spx removed.

## 2026-10-27 — Hand at rest stays a glance view (director)
- The resting hand renders rules and icon numbers at 13.3 px (cards are 208 px wide; hover/focus is 1.28× at 17 px).
  Checked on the card-01 native capture of a seven-card hand: costs, titles, art, icons with their numbers, and the
  rightmost card's full rule all read. What hides text at rest is the fan overlap (34% at seven cards): the next
  card covers each card's trailing words and title end.
- Decided: no change. The hand at rest is a glance view; hover and focus are the reading views (17 px). Raising the
  rest width to 220 px for a 14 px floor would cover about 17 px more of the board and still leave the overlap. The
  pt13-03 exemptions `hand_1_rest` and `hand_7_rest` stay. Playtest 14 asked the owner and got no answer; revisit
  only if they report it.

## 2026-10-27 — card-02 refresh budget (director)
- The 2 ms budget covers refreshes where no card's text changes, invalidation and hidden-card paths (measured
  0.03–0.75 ms for 60 cards). Rebuilding visible faces whose text really changes (77 ms worst case, 60 unique visible
  cards) is accepted: it happens only on a deliberate action (equipping gear, an upgrade) and costs what the hand
  pays per card.

## 2026-10-27 — Boss rules approved; summons give a Card Play (owner + director)
- Owner approved inbox `boss-rules` ("all feel reasonable; tweak the numbers as needed for balance"). The draft and its
  director decisions (`encounter_redesign/boss_rules_draft.md`) are the spec. Build: bos-01 (engine dials), then
  bos-02 (dragons) and bos-03 (Guardians), each measured before/after; the director tunes numbers from the results.
- Half-Health switch banner: "{SOURCE NAME} GROWS FIERCER" (uppercase, existing banner style). Not "enraged": the
  Umbra-depth `boss_enrage` modifier already owns that idea.
- Owner: "make summoned enemies grant an extra play". Director reading (posted in the thread as the default; the
  owner didn't object): +1 Card Play on the hero's next turn per `summon_minions` move that brings in at least one
  enemy, for every summoner, stacking, no cap. Death spawns, Survive waves and the Guardian auto re-summon (being
  removed) don't count. Rule sentence: "When an enemy summons, you gain +1 Card Play on your next turn."
## 2026-10-27 — Glacial Mirror placement (owner inbox mirror-real-fight)
- Owner: "a smidge down and to the left". Director diagnosis: the intent chip covered the Mirror's lower foot in both
  views (so it read as standing high), and pt13-06 had registered it on the old static painting, not the rig's rest
  frame (live feet 2.4 px front / 6.5 px rear right of centre at 1080p). Fix (pt15-01): chips never cover their owner's
  feet; the Mirror registers on its live soles plus an owner nudge of +5 source px left; no extra "down", because the
  revealed foot answers it. Interim nudge 230731f2e is replaced by pt15-01.
- bos-03 refinement: the Last Lamplighter's Shadowstep moves only its Wick Shades (`who: ["wick_shade"]`), not
  `all_hidden`, for the same reason as Noctyrax: a hidden leader arriving without a forecast breaks "shown a turn
  ahead". Panel: "After each of your turns, hidden Wick Shades Blink 1 tile toward you." Provisional tuning bands for
  the bot: elemental dragons 30–60%, Noctyrax 15–40%, Guardians 35–65% each.

## 2026-10-27 — Enemy action captions rest on the HUD scrim (director, enc-03)
- A longer caption ran over the Slagmaster's leader crest. The caption already draws above the board, but the crest
  showed through its transparent background. Decided: every enemy action caption rests on the existing soft HUD scrim
  (`hud_seat_scrim.gd`): text rect + 48 px sides / 10 px top and bottom, INK_0 at 0.85 under the text, fading over the
  outer 48 px / 6 px. No framed plate, and no overlay moves (design principle 1).
- pt15-01 r1: the chip protects only its owner's **soles** (bottom 6% of the rest silhouette, bounding rect + 4 px),
  as an owner-only obstacle in the existing placement order; the side choice stays pt14-04's. The 20% foot band moved
  154/172 chips (mostly side flips) — far beyond the owner's Mirror note.

## 2026-10-27 — Maquette briefs state volumes, not just poses (director lesson, mq-16/mq-17)
- Codex builds exactly the pose numbers given and fills the rest with the thinnest, flattest geometry: stick limbs,
  slab cloth, disc pauldrons, a straight over-long blade (mq-16 r1, mq-17 r0). Every maquette brief must also state:
  limb diameters and joint sizes as fractions of H, measured on the current art; cloth as draped surfaces with a
  minimum thickness and fold count; armour as shells and lames; held items' length and profile from the art; and a
  held blade or flat item kept in a vertical plane (or another plane that reads in both views) so the true 180° rear
  turn doesn't show it edge-on.

## 2026-10-27 — sum-01 accepted over one review finding (director)
- Codex re-review of 7e8b0c2b8 asked for origin validation: a hand-edited save (origin "authored"/""/garbage) or a
  legacy mid-Guardian save can make an injected Guardian replacement pay one Card Play. Accepted as is: save editing in a
  single-player game isn't a threat model; the legacy case pays at most once; and bos-03 deletes the injected
  replacement (`with_reinforcements`) entirely, at which point bos-03 also removes the origin distinction.
- rr-46 TODO_DESIGN_SEER_SIX_STEP_GAIT: the Hoarfrost Seer keeps its authored four-shuffle glide (a robed figure); the
  six-step rule applies to rigs authored with six steps.

## 2026-10-27 — Paint-over judgments (director)
- Ashen Reaver front paint-over (mq-16 maquette, K=4): all gate metrics pass at art_scale 1.0 (drawn 235 px, 1.09×
  hero; lateral axis 35°). Judge (Claude, rubric): PASS on all nine criteria. New Reaver art uses art_scale 1.0 (paint
  at drawn size), replacing the legacy 1.15. Rear generating from the approved front.
- Storm Cantor front paint-over: FAIL on proportions (rubric 2): spindly beside the hero and Seer. thin_rel 0.27 (body
  alone 0.157; old art 0.36). Cause: mq-17's feedback-1 volumes came from the gaunt old art. Fix: mq-17 r3 chunkier
  volumes, then repaint. The free-standing staff will always fail thin_rel (anything under ~15 px is removed), so its
  approval needs a recorded owner exception with the body-only value.

## 2026-10-27 — card-02 accepted after its three rounds (director)
- Final Codex review of 1f5297d22: correctness clean (35,685 cached-vs-fresh comparisons, 0 mismatches; 23/23
  mutations caught; the hash-collision fix confirmed). One residual: the first illusion trigger projects 41 cards
  needlessly (11.5 ms with 60 unique visible cards, once). Accepted: rare, one-off, no visible change. Possible later
  polish: select only consumed effect outputs (Widow Thread's Expose condition).

## 2026-10-27/28 — Lamplighter, Cantor, rr-46 cadence, summon copy, Gaoler paint (director)
- Last Lamplighter (mq-18): the lantern hangs beside the near leg, not out to the side, so its candle still shows in
  the rear. Front and rear paint-overs pass every art-gate check with no exception (rear thin_rel 0.055, edge light
  0.048; front 0.068 / 0.033; lateral axis 8.9° measured across the shoulders, since the feet measure the stride).
  Posted as inbox `lamplighter-paint`.
- Storm Cantor (mq-17 r3 answers): the bell dome is 0.10 H across, moved out 0.033 H to span 0.36 H; the fork tines
  are 0.02 H at the base and taper.
- rr-46: speed parity accepted (0.183 s per tile, death 1.036 s). The rebuilt enemies' six gait steps per tile stay
  as they are, but are flagged for the owner to judge in the next playtest ("do the legs read as a scurry?").
- Summon glossary copy: "Calls the shown enemy into the fight. When an enemy summons, you gain +1 Card Play on your
  next turn." (19 words). It supersedes tt-01's short copy for `summon_minions`; int-06 updates the registry.
- Gaoler rr-44, judged on the native frames at 3-4× in both views and every clip:
  - **Defects to fix:** the chain detaches from the fist (rear hit 15, front reel 63), and thin slivers sit beside
    the boots in the rear.
  - **Joins:** closed with the approved-paint joint cap.
  - **Accepted as painting:**
    - the rear underlay's striped panel: the gambeson flank under the chain arm, the same quilted grey as his front
      sleeves;
    - the 20 hidden backing regions, frozen as director paint (the worst case of each piece read as cloth or leather
      in shadow);
    - flat regions, as a ratchet (fail on a new region or one more than 2 px larger).
  - A toning edit of the strip was tried and dropped: it cut a seam into the cowl.
- Integration merges: when two units re-pin the same golden seed, the director keeps one side at the merge and the
  repair unit regenerates the combined values with the field-by-field audit (enc-04 method). Seed 421 at the enc-04
  merge kept bos-01's pair, and int-06 regenerates it.

## 2026-10-28 — owner verdicts, tuning, hero facing, model switch (director)
- **Owner art verdicts.** `reaver-paint`, `cantor-paint` and `lamplighter-paint` all NEED CHANGES, with a common
  thread: the maquette poses read as "toy soldiers". Each gets a maquette take two before any repaint:
  - **mq-19, Cantor:** a living stance, a full tattered cloak over the back, a torn tabard. The two staff exceptions
    are approved.
  - **mq-20, Lamplighter:** a stoop; the lamp-house was a director misread of the old art and becomes twin shoulder
    plates with a cross; a bigger lantern on a ring grip; a shredded robe.
  - **mq-21, Reaver:** a real sword grip, pauldrons set to the side, a crested octagonal helm, real legs, a back
    loincloth, a fighter's crouch and heavier arms.
  - Lesson: brief maquette poses toward the old art's energy; neutral "ceremonial" poses read as toys.
- `mirror-real-fight-2`: APPROVED (pt15-01).
- **Guardian tuning (bos-03), from the ladders:**
  - Rimejaw: Pounce 6, HP 34 (43.3%).
  - Last Lamplighter: HP 30, Procession 6, Snuff cap 1, Hook 3, Guardian Shades hit for 1 (44.4%).
  - Storm Cantor: his Peal beat helps the hero (it strikes his own helpers). The final ladder reverts it to 3/Chain 2
    and leans on HP and Broken Rhythm.
- **Dragon tuning (bos-02):**
  - Tharokh: Claw 14, HP 72, Stonewake 6 (58%).
  - Vyraketh: Maw 8, Breath 6, HP 52, 1 Droplet (34%).
  - Vaeloryx: Gale Push 1, Dive 6, HP 50, 1 Shrike (36%).
  - Noctyrax: Void Claw 10, HP 64 (32%).
  - Iskaldra: unchanged (36%).
  - Zekarion: final rungs HP 50, then Overload bolt 3.
  - The director wrote the Grimoire copy for nine dragon entries, and `gale_force` becomes "Strikes everywhere within
    2 tiles of Vaeloryx and Pushes struck actors 1 tile."
- **rr-46/rr-47:** the native ID-depth proof caught a real runtime defect: moving units vanished on the back row. The
  ground position came from the artwork's facing offset. Fixed in rr-47; all 20 native jobs pass. Proof cost cut from
  956 s / 1.8 GB to about 24 s / 30 MB per job by comparing ownership IDs.
- **Hero facing (owner idea):** he keeps the facing of his last step, target or sourced hit; rule beats, hazards,
  ticks and pushes don't turn him; a fight starts facing the nearest enemy. Built as hf-01 behind a `persist|snap`
  switch for an A/B playtest.
- **Model:** for 2026-10-28 the owner switched new Codex runs to `gpt-6-astra` (a banked reset). Astra runs the Git
  preflight itself and stops on the sandbox's read-only metadata, so the preamble and resume notes now say preflight
  and commits are the director's.
- **Model (afternoon):** the owner switched back to sol: "astra has sufficiently burned through openai usage for
  dubious benefit". New runs use the default model. Running astra jobs were left to finish.
- **Hero facing details:** ties go to the unmirrored candidate, never across front and rear. Combat start faces the
  nearest enemy by Manhattan distance, with the lower id on ties. Undo restores the pre-move facing. Only direct enemy
  hits turn him: trap damage never does, even when an enemy sets the trap off. Erupt turns him toward the surfacing
  tile.
- **Cantor take two (art):**
  - The director ratified the as-built cloak, so the geometry is not regenerated. Fold amplitude runs from 0 to
    0.02 H, linear. Standoff is 0.02 + 0.015·t(2−t) H. Width is ×(1 + 0.15·t(2−t)). The written profiles drifted by
    at most 0.005 H, and an approved paint-over sits on this delivery.
  - The front's lateral axis is measured on the feet (39.2°), not the shoulders (5.4°): the 14° lean onto the staff
    flattens the shoulder line by design.
- **Limb lengths never change (restated):** mq-21 lengthened the Reaver's near arm 1.14× through pose
  reconstruction, so mq-23 rebuilds it with fixed-length solving. Angles are exact; positions are soft targets with
  the miss reported.
- **Reaver paint colour:** warm grey-brown gunmetal with bronze rims, matching take one, which the owner liked. Not
  copper (chroma 0.211, gate FAIL) and not cold blue-grey.
- **Lamplighter take three (owner):** no shoulder plates of any kind. The mantle drapes over the shoulders with
  ragged points. Real hands: four clawed fingers and a thumb on the free hand, and a fist through the ring on the
  lantern hand.
- **Zekarion:** accepted at 24% after bos-02's last rungs, because rungs 3–5 were noise and beat → hero rose. The
  cause is the same-phase Skybreak → Overload strike that bos-04 removes. Retune after bos-04's re-measure.
- **A banner belongs to its fight:** the half-Health banner clears whenever a new combat state loads (bos-04).
- **Reaver paint:** the owner approved take two after one fix (the rear left leg reconnected behind the back
  loincloth). The paint is about 25% bulkier than the mq-23 maquette, so the rig registers its joints on the
  painting, not by bounding-box mapping.
- **Reaver rig motion** (`staged/rr-48`):
  - his three intents get their own clips: Raking Flame drags the burning edge along the floor; Hooked Sweep is a wide
    waist-high swing; Executioner's Fall is a shoulder-high chop, after which he stays bent over the blade (exposed);
  - the pauldrons are fused to the torso; there are two loincloth chains;
  - the falchion trails the fist in the walk, slips at death and lies flat;
  - he slumps rather than kneeling.
- **Lamplighter fist:** ratified as built. Containment and wire contact were the director's over-specification. The
  ring visibly exits the fist, and the fingertips close to within 0.014 H.
- **Bosses:** Zekarion (24%) and Lightning Warband T3 (50%) are accepted for playtest 16 (within n=30–50 noise).
- **Proof contracts:** a frame check must match what that frame shows. Guardian forecast frames have no "YOUR TURN"
  band, so their check covers the board, not the band.

## 2026-10-29 — Reaver rig joints (rr-48 round 2, director)
- **Underlay coverage:** a vacated texel where the underlay is transparent is background (air where the falchion, arms
  or hands were). Clearing it is correct, not a finding. The rr-48 round-1 criterion was a director error.
- **Tucks take the director underlay wherever it is opaque.** The underlay shows only through gaps (vacated footprints
  and tuck masks), always beneath every visible piece. For the Reaver this covers the neck, waist, hips, loincloth
  tops and ankles.
- **The remaining bands** (shoulders under the pauldrons, wrists, the grip inside the fist, elbows) close with the
  Gaoler's approved-paint joint cap: no new paint, interior donors only.
- **The falchion** stays attached at the grip until `release_at`. On the floor it pivots only in the keyed direction,
  up to 95°, until it rests on two points.
- **Budgets** are clamped after the paint is in place, never to zero. A remaining tear the live action needs is judged
  on native frames.
- **Reaver native (rr-48 r2), director judgment:**
  - Exposed outline-class texels that are exact director paint (underlay or approved caps) are painting: the armour's
    dark tones in shadow (the Gaoler precedent). The 3×3 dark-slab gate stays blocking.
  - The underlay sits behind the whole body. Each hidden receiver carries its whole underlay domain.
  - Natural negative space is judged against the underlay: what's air there is air behind the arms and loincloth.
  - The walk keeps both arms' full swing (owner rule). The rr-38 clamps elsewhere have a 60% floor.
  - A hole of ≤ 4 px lasting ≤ 3 frames is accepted.
- **One runtime for every rig:** when two rigs build the same feature (elbow policy, held-follow frames), the merged
  production implementation wins and the later rig ports onto it.

## 2026-10-29 — scale, the repaint method, the Opus window (director)
- **Board scale:** the Gaoler's `art_scale` goes from 0.90 to 1.10 (1.10× the hero), at the hero's pixel density
  through the board-density regrid (grid = t / r). No repaint.
  - Guardians stay at 1.15: about 1.2-1.3× the hero, imposing bosses.
  - The other rig-v2 enemies are unchanged (0.92-1.11×; the creatures read in character).
- **Repaint method** (owner `cantor-paint-2`: "these keep recurring"):
  - the maquette sets the pose and perspective only, and its forms must match the original's measured proportions;
  - joints are pointed plate cops or tapered overlaps, never spheres; hands have jointed fingers; chest pieces turn
    with the body; the original's heads, face plates and props are kept;
  - the art-gate preamble says so (65e2bee62), and every paint-over is checked against the owner's
    recurring-defects list before posting.
- **The Cantor's tines:** on the original, the far tine (screen-left in the front view) is the taller one. The mq-26
  brief had the sides backwards; corrected in its round 2.
- **Daytime windowed proof:** a covered Godot window stalls the capture (no PNGs). Merge on proven byte-identity when
  the bytes match a native-passed state; otherwise wait for a visible window.

## 2026-10-30 — Last Light and the Ember Hoarder (director)
- **Last Light tuning** (the first bot pass was toothless: 99/100/97% wins, dawn after 3 turns, 0.5 Snuffs a fight):
  - the night is longer: `time_target_by_depth` 60/66/72 in the data, supplied through the special's objective; the
    parked generic Survive keeps 42/46/50;
  - the Wick Shade's cycle interleaves Snuff (Grasp, Snuff, Drift, Snuff), so it threatens a brazier from its second
    turn.
  - Result: bot wins 97.3/92.7/94.7%, dawn after 4 turns, Health lost 5-7, about 1.2 Snuffs a fight, median 2
    braziers lit at dawn. Accepted for the first playtest: the bot never relights, so the owner's feel decides the rest.
- **Last Light implementation calls accepted:** Snuff acts only in rooms that relight on step, so the Lamplighter and
  Noctyrax stay byte-identical; the special starts at layout revision 7; sight 3 comes from the "deep" Umbra stage.
- **Ember Hoarder:** rule panel "Slip Away"; panel icon = its own map emblem; break line "The brood scatters!"; board
  art = the Ember Tick's articulated rig at the Tick's scale. spx-09's defaults stay (kicker "BATTLEFIELD · N TURNS
  LEFT", dissolve at the end of the hero turn, hoard = the standard room's Embers ×1.0, reward line in the run notice).
  Bot catch rates (6-10%) say little because the bot doesn't chase; tune from the playtest.
- **Deferred, both specials:** a board marker for the Snuff target, and a reward-screen line for specials.
- **One mechanism per job** when parallel units overlap: int-09 keeps one revision gate (`first_layout_revision` in
  the catalog plus the place-level skip), one special-cohort API and one fixture strategy (re-seeded, named seeds).

## 2026-10-31: enemy simplification and cel default (owner approved `thrall-rework-v1`, `enemy-mechanics-audit`, `cel-look-3`)
- **Cel is the default:** characters, props, pillars and walls filtered, floors original. Tests and art gates see source art (`off`); owners and exports see `all`. Tune by data only (`tools/cel_look.json`).
- **Retaliate on enemies is 3,** the hero cards' example amount, not 4: two hits at 4 cost a third of the hero's Health.
- **Recede has no Block:** with Mirror's selection gone the Mimic retreats often, and 4 Block per retreat made melee a stall.
- **Dive's band is path plus one tile either side,** Razor Dive's shape: the Shrike stops beside the hero, so a path-only shape could never hit.
- **Marked gets a new icon;** the four move icons stay as move identities.
- **Lob tooltips keep resolved numbers and phase:** arm damage appears nowhere else in text.
- **Dynamo is not re-tuned:** 86 / 70 / 43% by tier now matches the Warband cohort's 81 / 68.5 / 43.5%.
- **perf-10 dropped:** section CPU fell, frames didn't. Judge by frames.
- **Suites run at normal priority:** background QoS with Codex load took the Godot suite from 14 to 69 min and starved seven wall-clock tests into false failures.
- **Golden and byte comparisons follow intended changes:** review the leaf diff, then re-pin; don't weaken comparisons.

## 2026-10-31 chn-01: enemy Chain forecasting left as is
Codex's re-review of 4b61526dc found two preview gaps when an enemy's Chain action also pushes the hero. No enemy in `data/enemies.json` has a Chain action, so neither can happen in play. Accepted without another round; revisit if an enemy ever gains Chain.

## 2026-10-31 evt-01: event history stays a small synchronous write
Codex's re-review of ee01c9360 asked to move `user://recent_events.json` I/O off the main thread, measured with a contrived 16 MiB file. The real file holds at most 16 ids and is written once per event click, not on a hover or frame path. Accepted as is; all four original findings are closed.

## 2026-10-31 brs-01: a Tick dying in the dark still shows its dissolve
Codex's re-review of ef62549b6 found that a hidden Tick dying from Bleed still draws its death dissolve on a concealed tile. The Burst itself is correctly redacted. Seeing an enemy die in the dark is harmless and tells the player why tiles nearby flared. Accepted without a fourth round; all other findings closed.

## 2026-10-31 brs-02: one missing popup left as is
Codex's re-review of df4cc171c closed both findings. It found that when an enemy takes Burst and Fire damage in one resolution, its bar still ends correctly (50, 46, 44) but the later 2 Fire damage has no popup. Rare and cosmetic, with the Health value correct. Accepted without another round.

## 2026-11-01 OWNER: no tagline on the run-end screen
Owner: "these are not good imo, so let's just nuke it." The quips are gone from defeat, victory and withdraw. The cause line and score move up 42 px to close the gap. Titles (SLAIN, FALLEN, ESCAPED, WITHDRAWN) stay.

## 2026-11-01: shadow rooms are not an outlier; no tuning
meas-04 and meas-05 compared standard shadow rooms with the other elements and showed win rates of 18.5 / 0 / 1.5% by tier against 66-84 / 40-50 / 20-37%. That comparison is confounded. Shadow is only ever the final section (`dragon_boss_library.gd`: `sequence_index >= FINAL_BOSS_SEQUENCE_INDEX` gives the shadow boss), while the other elements average sections 0-4, and enemy damage and HP scale with depth while the bot's deck preset does not. Bot win rate by section, all elements, from meas-04's own records:

| Tier | s0 | s1 | s2 | s3 | s4 | s5 (shadow) |
|---|---|---|---|---|---|---|
| 1 | 97% | 94% | 92% | 54% | 44% | 18% |
| 2 | 94% | 77% | 38% | 9% | 8% | 0% |
| 3 | 78% | 35% | 18% | 9% | 6% | 2% |

Shadow is the end of a curve, not a break in it. A fixed starter-tier deck against final-section enemies says nothing about a player with five sections of rewards. **Decision: no shadow tuning, and the meas-05 dials are not applied.** Open question, no unit yet: whether the steep drop from section 2 to 3 matches a real run; it needs a bot whose deck grows with the run, or the owner's play. The owner's analytics hold 63 fights in 6 runs on the Steam build, none near the final section, so they can't answer it.

## 2026-11-01: the steep difficulty drop doesn't survive a growing deck; no tuning
meas-06 played 25 whole runs with the deck growing (always taking the card-heuristic pick) and Health refilled before each fight, 840 fights. Standard-fight win rate by section: 87 / 77 / 56 / 41 / 50 / 38%, largest step 21 points at section 2 to 3 (zero-based 1 to 2). The fixed-deck tiers dropped 38 to 43 points. The bot's tactics are weak, so these are floors, not expected player rates; the shape is what counts. **Decision: the curve needs no tuning from this.** With Health carrying over, the same bot dies in section 1 about 90% of the time, which says more about the bot than the game; owner analytics stay the source for real run length. **Open:** dragons won 88 / 60 / 52 / 32 / 32 / 60% by section at N=25, so the final dragon may be easier than the two before it. meas-06 round 2 measures it at N=100.

## 2026-11-01: the typed-array literal rewrite is parked; Windows is untested
qa-19 audited 559 shipped scripts for the `AGENTS.md` typed-array rule and rewrote 594 bare-literal sites in 55 files. Its runtime probes (Godot 4.6.1, macOS) found direct literals work, and **no confirmed untyped runtime transfer in shipped code**; the true hazards it measured (untyped transfers, selected ternary branches, `map`, untyped `duplicate`/`filter`/`slice`) have no real hit. A 55-file churn with no known failure would conflict with every open branch and departs from the code's own style. **Decision: merge the on-demand audit (`tools/typed_array_audit.py`, report in `spec/peer_benchmark/qa/typed_array_2026-11/`) and park the rewrite on `codex/qa-19-literals-parked`.** Unrelated to the rewrite: 13 literals in `guardian_combat_rules.gd` were out of its scope. **Open:** nothing has run on Windows, so the rule's claim can't be settled here. A real Windows launch is the test, and if it fails on typed arrays the parked rewrite is ready.

## 2026-11-01: final dragon not clearly the hardest; hold, watch it in play
meas-06 round 2 fought each section's real dragon from the ladder's loadouts at full Health, N=24 per section (the 100 target wasn't reached): 83 / 58 / 50 / 50 / 42 / 63%. Noctyrax (final) sits above sections 3 and 4, but the Wilson intervals overlap. He also costs less Health (median 20 against 24) and takes longer (7 turns against 3 to 4). One caveat widens the gap: the frozen policy doesn't run the half-Health rule change the other five dragons have in play, and Noctyrax has no such change, so the bot's fights understate the other five. **Decision: no tuning yet.** The sample is small, the bot is weak, and no real player has reached him (owner analytics: none near the final section). A final boss that plays easier than the fights before it would be a real flaw, so ask about it in the next playtest that reaches him. If it's confirmed, the dial is his Health or a shorter clock, in existing primitives. Report: `encounter_redesign/measurements/run_curve_2026-11/dragons.md`.


## 2026-11-03: a release branch between integration and master (owner)
The owner wants work to keep flowing into the inbox no matter what is waiting, and only what they approve in the inbox to reach master. Until now the tested push candidate was integration itself, so waiting on a verdict froze every merge.
- **Levels:**
  - unit branches `codex/<id>`;
  - integration `codex/peer-benchmark`: everything that passes director review merges here at once. Playtests pin here. It never freezes;
  - release `codex/release`: master plus only inbox-approved units. Full suites run here;
  - master.
- **Units start from `codex/release`** (`CU new <id> --base codex/release`), so an approved unit carries no unapproved work. A unit that needs someone else's unapproved work stacks on that one branch, and its inbox entry says "needs X approved too".
- **On approval:** merge the unit's own branch (not integration's merge commit) into release. So keep each unit branch until it is on release; remove only the worktree after its integration merge. Conflicts get resolved twice, once per line.
- **Publishing (owner, 2026-11-03: "Approval is enough, batched"):** an inbox APPROVED is permission to publish that item. Full suites run on release and the push goes to master at most once a day, and always when the owner asks for a Steam build. `authorize-publish --user-approval` cites the inbox approvals it carries. Hold suites while the owner plays.
- **Transition:** release starts at 04bceae9b, the candidate that passed both full suites. It carries pol-12, pol-20, pol-45, walk-01, qa-22, hud-01 and qa-23, plus fb-kindle-words, fb-burst-look, fb-tharokh and the Reaver rig, which the owner chose to ship rather than revert. It pushes on the walk-1 verdict; after that, master equals release and the rule applies cleanly. perf-14 and win-01 already started from 04bceae9b.

## 2026-11-03: Windows and Linux builds pass every check a Mac can run (win-01)
win-01 exported all three Steam presets from the release candidate 04bceae9b through the cel export path (each `CEL_PACK_TEST paths=2939 failures=0`). It loaded each exported pack in this Mac's Godot: new run, first fight, a dealt card played, save, fresh-process resume with full state and RNG equal. Zero mis-cased `res://` references (8,408 checked), zero illegal or case-colliding names in the packs (9,955 entries each), zero illegal run-time file names (48 writers), and every save path stays under 260 characters. **Decision: no change.**
- `scripts/battlefield_rules/bot_policy.gd` ships but can't load, because its base `tools/encounter_bot.gd` is excluded from export. Only tools and tests use it, so it's harmless; move it under `tools/` whenever its suites are next touched.
- `TODO_DESIGN_save_path` is decided as no change: `LABYRINTH_USER_DIR_NAME` is a developer and test-runner override, never set on a player's machine.
- The new typed-array site (`sfx_cue_router.gd:55`, a typed const literal) follows the pattern qa-19 measured as safe; it stays with the parked rewrite.
**Still open:** native libraries, GPU and shader cache paths, input, Steam and Deck, audio and real play on Windows and Linux. Only a real launch tests those. Report: `spec/peer_benchmark/qa/win_01_2026-11-03/`.

## 2026-11-03: death timing, the "not now" look, and turn-order portraits (owner)
- **Humanoid deaths (death-1 NEEDS CHANGES):** the fall plays at 0.6x its animated length, and the fade takes 0.8 s. The owner found 0.8x a little long and the 0.45 s fade basically instant. The total stays about the same (Reaver 1.76 s against 1.73 s). On branch `codex/death-01` as death-2.
- **Unplayable cards keep the faded look (pol-02 skipped):** the owner prefers today's see-through fade to the darkened, crisp version. The branch is parked, not deleted. The polish slot doesn't retry the darkened treatment.
- **Turn-order portraits are still, painted head portraits for every enemy** (owner regression report). The rail and the landing strip had swapped in live board renderers for the maquette rigs, showing a bobbing midsection. Every rig already has a painted portrait; the rail uses it. The pre-battle inspection view keeps its live portrait. Portraits older than their board art (Lamplighter, Lightning Wisp) are rebuilt from the current art (por-02).

## 2026-11-03: what reaches the release line without an inbox entry
The release rule (only inbox-approved units) covers everything a player can see, hear or feel. Changes with nothing to show go to release directly once they pass their checks: tests and probes, director and proof tooling, docs and ledgers. Examples: qa-24, which found both controller "failures" were stale probes, not player bugs, and the review inbox's storage button. Anything that changes the game, however small (perf-14's cache bounds, por-02's portraits), still goes through the inbox. The owner can veto this split.

## 2026-11-03: master is one commit per release (owner); output/ is never tracked
The first full push (1,090 commits, 5.4 GB) failed: GitHub caps one push at about 2 GB. About 3.8 GB was proof captures under `output/` that units had committed by mistake (fix-10 alone committed 6,101 native PNGs). The release's real content was 318 MB. **Owner chose "One clean release commit":**
- master gets one commit per release. Its tree is exactly the release commit that passed the full suites, and its parent is the current master. The first is f206d3813 (tree of 47b98da9b minus `output/`, plus the ignore rule), pushed 2026-11-03.
- The day-by-day history stays on `codex/release` and `codex/peer-benchmark`.
- Tool: `spec/peer_benchmark/director_tools/release_squash_push.sh <tested commit> <message file>`. It refuses if `output/` is tracked or the upload would exceed about 1.8 GB.
- `parallel_task.py push` no longer fits this model, because it requires the branch to contain master. Record approval in the message and in this log.
- `/output/` is in `.gitignore` and untracked on the release line (000c49384); files stay on disk. Old captures remain reachable in local history.

## 2026-11-03 evening: owner verdicts and director calls
- **Chronicle wording (owner, ui-5):** the Chronicle uses one consistent word per outcome (defeat: SLAIN). The run-end recap keeps its varied, seeded titles for flavour. ui-05's recap-title Chronicle change was reverted (2d2afeb25).
- **Top bar (director, ui-05):** "LV 1 · EMBERS 0" uses the middle-dot separator the Chronicle and section lines use. The owner approved it.
- **Keyword pop-up width (director, ui-05):** stays 226 px. One-word last lines stay at 22 to 29 of 140 entries at every width from 226 to 256, so width doesn't fix them.
- **Loading screen (director, perf-16):** after the title-menu preload, the loading screen still covers the rest of first-run preparation (about 2.3 s). It isn't cut to its minimum.
- **Hover pointer source (director, hov-01):** hover resolves from the last pointer event the game received (real or pushed) and clears on window exit. Captures never move the OS cursor.
- **Dropped held items (director, rr-57/rr-58):** a hidden fill comes only from the same rig's or item's own paint (an offset or mirror of a same-orientation link, or a shaft continued along its axis) and lives only in release variants. In-hand frames stay pixel-identical.
- **Card strip names (director, ui-08 dropped):** the deck strips already shrink a long name down to 13 px before the ellipsis. Enforcing the 14 px floor would ellipsize 29 names that fit today, and the five reported names (Crimson Draug and others) overflow even at 14 px. Strips keep their current behaviour. A real fix needs a second line or a wider strip, which is a design question for later.
- **Merge scripts:** `spec/peer_benchmark/director_tools/merge_invisible.sh` stops on a merge conflict. A piped grep had hidden qa-28's conflict exit code, and the director resolved that conflict by hand.

## 2026-11-04: invisible performance changes skip the inbox (owner)
Owner: performance changes "proven to have no changes to the experience that a user could see" need only the director's review, not the owner's sign-off. They go straight to integration and release (`merge_invisible.sh`) and ride the next master push. This amends the 2026-11-03 split above, which had sent perf-14's cache bounds through the inbox.
- **Proof of invisible:** state hashes unchanged, the same frames drawn where the proof can check (pixel or draw-command equivalence), focused tests and the Python default group green, and the director's own look at a native capture when rendering is touched.
- **Still to the inbox:** anything a player could perceive (look, timing, feel, the length of a loading screen), or a risky change (saves, rules, platform-specific rendering paths).
- **Record:** one line per merged perf fix in `spec/peer_benchmark/perf_log.md` so the owner can see what got faster.
- **Slots:** never idle unless usage is out or the owner says stop (owner, 2026-11-04). Steam Deck smoothness is the standing perf goal; perf-20 (CPU on a slow-core proxy), perf-21 (GPU cost, measure only) and perf-22 (Vulkan pipeline hitches) start it.

## 2026-11-04: titles that repeat (director)
- Boss and guardian fights: when the objective title names the target, its subline shows only the health ("72/72 HP"); when the boss health bar is on screen, the subline is hidden. Leader objectives that don't name the target keep their subline.
- Board placards don't repeat the room header: the faint "Victory" (qa-37) and the "Relic" placard (qa-39) are gone; "Relic Cache" and "CLAIM YOUR TREASURE" stay.
- Skill tree links route through the gutters with one lane per link (ui-09 candidate A); merged shared runs made "leads to" ambiguous.
- **Area Attack is not a card keyword (owner, txt-2, 2026-11-04):** "The pattern is just an adjective, so to speak, not a verb." On cards an area hit shows Ranged or Melee (the attack it really is); the red tiles show what it hits. Supersedes the txt-02 round-0 call (Area Attack only).
- **Previews pulse (2026-11-04, director, from the owner's fx-3 note):** every forecast value drawn in a real-looking renderer (projected HP/Block/Stoneskin, forecast buff badges, predicted status pills) uses the existing health-bar damage-preview pulse; a forecast the play will deliver keeps pulsing until its effect lands, then turns solid with its landing animation. One preview language, no gap.
- **No shader warmup (2026-11-04, director, perf-22/perf-26 measured):** on Vulkan the pipeline cache persists and the counter includes cache hits; a cold-launch warmup cost 14.4 s of loading to save 17 play lookups and ~17 hitch frames. Not worth it; the Deck's own Steam shader pre-caching covers first-run compiles. The remaining play hitches (map entry, pre-battle, fight start, 78-95 ms) are first-time scene work: perf-25.
- **Lasting-effect cards stay as they are (2026-11-04, director, bal-02):** 2,688 paired bot fights found no card weak in play. Tempest Form and Rite of Tailwinds help more than the heuristic says (they stay productive for 6.5-7.5 turn starts; the scorer assumes 3). The other five can't be told apart from noise. No card numbers change; the scorer is a dev tool and stays until a balance pass needs it.
- **The Chronicle hides the menu's title and profile line while open (2026-11-04, director, ui-12):** they peeked around its frame; the Chronicle has its own heading and lifetime totals. They fade with the Chronicle's crossfade.
- **Arrivals sound like the Umbra (2026-11-05, director, au-01):** an enemy entering mid-fight plays the existing spell.shadow cue once per arrival beat at -4 dB.
- **Move the chips, not the hand (2026-11-05, director, sd-05):** when HUD chips collide with the resting hand on the Deck, relocate the chips (left column under the objective panel); never compress the hand into an unreadable stack.
- **Event Health numbers may cross the frame (2026-11-05, director, ui-12):** pol-17's size steps stay as they are; a large number may rise past the event panel's top edge. A size cap that kept the largest inside the frame made every number tiny, so it was reverted. The popup stays within the panel's sides and above its bottom.
- **The enemy action caption stays at the top (2026-11-05, director, cap-04):** a mockup with the plate above the acting enemy covered its and the hero's health bars on a crowded board. Link caption and actor with an acting-unit highlight instead (to design).
- **Card-summary layout caches are intentional (2026-11-05, director, qa-46):** perf-44's inactive summary layouts (at most four per card, freed when the card is deleted) are not a leak: orphan counts stay flat over 1/5/20 visits. Don't clear them on tree exit: hand cards pass through the card pool on every refresh, which would drop the caches perf-44/46 rely on. Orphan samplers allow-list them (`director_tools/qa46/steady_orphan_sampler.gd.txt`).
- **A board that fits stays centred when zooming (2026-11-05, director, qa-47):** on an axis where the whole board fits, zoom and pan keep it centred (within the overscroll bound), so an edge tile may drift slightly toward centre. The focused or pointer tile is held exactly only on axes where the board overflows. Codex's fix let a fitting board sit anywhere in the spare space; rejected.
- **Pointer hover keeps its early keyword box (2026-11-05, director, ui-16):** on mouse hover the keyword box appears on the 2-frame rest while the card is still finishing its lift (frame 2 of the lift); don't delay it until the lift settles (ui-16 did, +133 ms; dropped). Controller focus already shows its box as the lift settles.
- **A controller can target what a pointer can (2026-11-05, director, qa-54):** controller board navigation includes every tile a pointer click would accept, including Umbra-hidden legal targets; on a hidden tile the cursor shows exactly what pointer hover shows, nothing more.
- **Tooltips show no shortcut under a controller (2026-11-05, director, qa-54):** keyboard/mouse tooltips keep `[I]`, `[M]` etc.; with a controller active they drop the bracket entirely (the prompt bar shows the buttons). No bracketed glyph text.
- **No acting-enemy tile marker (2026-11-05, owner, hud-4):** the crimson ring and fill under the acting enemy read as too busy; shelved. The caption at the top stays the only link between action and actor for now.
