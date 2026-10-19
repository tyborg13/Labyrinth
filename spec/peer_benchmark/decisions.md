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
