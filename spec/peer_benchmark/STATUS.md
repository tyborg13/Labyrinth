# Peer-benchmark program — STATUS

Goal (owner, 2026-10-12): raise every facet of Escape the Umbra to the bar of Slay the Spire and
Into the Breach — visual cohesion/identity/fidelity, playability, mechanics, board + UI animation,
sound, content completeness (room types, events, map branching), card/enemy design, level gen.
Experimental: owner may cherry-pick or revert. Bold changes allowed; prior Codex-era approvals are
not binding. Claude directs (all taste), Codex implements (orchestrate-codex skill).

## 2026-11-03 morning: verdicts in; release waits on the Reaver
- **Owner verdicts:** walk-1 APPROVED; lamplighter-rig-3 APPROVED (walk-02 landed 3ac2128b6); cantor-rig-3 APPROVED (walk-03 landed 87da01f1c); reaver-rig-2 NEEDS CHANGES, blocking (the owner first clicked approve by mistake): his slashes must start high and come down. His walk was already fixed by walk-01 (owner saw it in walk-1).
- **Release:** `codex/release` = integration at the Cantor merge plus docs. Full suites PASS at 3ac2128b6; they rerun after rr-57 merges. The push waits only on rr-57 and its `reaver-rig-3` verdict, unless the owner says to push without it.
- **Running (Codex):** rr-57 (Reaver attack wind-ups, base codex/release), perf-14 (late-run tree growth).
- **Next for rr-57:** run its native `rr48_proof.sh` stages, paint any hidden-fill masks it reports, then a reel (every animation, front and back, game speed) as `reaver-rig-3`.

## 2026-11-03: release branch; integration unfrozen
- **Owner:** work always continues into the inbox; only inbox-approved items reach master. New level `codex/release` (master + approved units only; full suites there), decisions 2026-11-03. Units now start from `codex/release`; keep unit branches until they are on release.
- **Publishing:** an inbox APPROVED is permission to publish (owner: "Approval is enough, batched"); push release to master at most once a day and on every Steam-build ask.
- **Release now:** `codex/release` = 04bceae9b (full Godot + Python PASS). Pushes on the walk-1 verdict: make a worktree for `codex/release`, adopt it with `parallel_task.py`, then `authorize-publish` + `push --fetch` from there.
- **Running (Codex, base 04bceae9b):** perf-14 (late-run tree growth: find and fix leaks, measure frame cost), win-01 (Windows/Linux export, pack smoke, static audit; fixes only mis-cased refs and illegal run-time names). Briefs in `.codex/tasks/briefs/`.
- **Not launched:** test speed (the Godot pass is already 5-way parallel and CPU-bound), a second hunt (qa-23 covered four wins and the final dragon), guard-02 (needs designed challenge motion first).

## 2026-11-02 late night: four Codex slots refilled; master push gated
- **Owner:** fill the four Codex slots; put all approved changes on master for a fresh Steam build, but **fix the known broken walks first, then push**.
- **Full suites at 65b9d0d43:** Python full (`--all-groups`) OK. Godot FAIL (18 failures in 13 programs; log `/private/tmp/labyrinth_codex/qa-22/base_full_godot.log`). Master is still d96eadf4f (2026-10-21); integration is 1,031 commits ahead.
- **Running (Codex, base 65b9d0d43):** walk-01 (rear projection + 3 steps per tile at 0.30 s per tile, all humanoid_v2 walkers), qa-22 (Godot suite to green), hud-01 (turn-start Pass blink), qa-23 (whole-run hunt).
- **Push plan:** merge walk-01 and qa-22 (+ hud-01/qa-23 if ready), director native reel check of the walks, post the walk entry, full Godot + Python at the exact HEAD, then `parallel_task.py authorize-publish` + `push` to origin/master. fb-kindle-words, fb-burst-look, fb-tharokh and the Reaver rig ship with it (owner chose to fix the walks rather than revert).
- **walk-01 landed** 3f40388b3, posted `walk-1` (the push waits on its verdict). Steps per tile by leg reach at 12 steps/s: 4 Reaver/Gaoler/Lancer/Mortar, 5 Weaver, 6 Thrall/Herald/Mirror/Gloam, Seer 4 shuffles at 0.333 s. Reel `output/walk-01/reel/humanoid_walks_after_2x.mp4`.
- **Port after walk-01:** the same projection and gait rule to rr-52 (Lamplighter) and rr-56 (Cantor), and add both to `AUTHORED_HUMANOID_TILE_TYPES` in `playback_timing.gd` (an opt-in list).
- **Landed:** qa-22 b32528ebe, hud-01 460d92b86. **Running:** qa-23, walk-02 (Lamplighter), walk-03 (Cantor), death-01 (branch until the owner sees it). Next slot: design the guardians' opening (six guardians: Reaver, Rimejaw, Cantor, Gallows Roc, Craghide, Lamplighter).
- **Release candidate:** qa-23 landed (90a7ab654). Integration now carries pol-12, pol-20, pol-45, walk-01, qa-22, hud-01 and qa-23 on top of 65b9d0d43. Full Godot + Python run at this HEAD; the push needs the owner's walk-1 verdict. No commits to integration between the suites and the push.
- **Follow-up (perf, not urgent):** tree nodes grow 3-5x from section 0 to 5 in whole runs (1548 to 5380-7985; zero orphans, cached views). Measure whether late-run frame time suffers.
- **guard-01 parked** (not posted): reusing each guardian's attack wind-up (0.9 x contact) as the opening reads as a slight crouch at board scale; the swap from the opening's front view to the idle facing pops; Gallows Roc and Last Lamplighter start hidden in Umbra. Learned: an opening needs motion designed for it, as roar-01's was. Branch `codex/guard-01`, captures `output/guard-01/`.
- Lamplighter and Cantor now live on `codex/walk-02` and `codex/walk-03` (rig + walk fix + integration merge), posted as lamplighter-rig-3 and cantor-rig-3 (rig-2 entries closed). Merge those branches, not rr-52/rr-56, on approval. death-01 posted as death-1 (branch only).
- The rr-52/rr-56 worktrees are removed; their uncommitted rest rebakes were committed first (d924af0bf, d5c39432a).
- **Decided:** Hall of Mirrors' summary row says "each adjacent tile" (qa-22 r1; "adjacent" is the card pool's word).

## 2026-11-02 night: lamplighter-rig-2 needs changes (walk)
- **Owner:** the walk reads far too fast, and some moves zig-zag across tiles.
- **Zig-zag (bug):** the compiled `projection.rear.forward` is (0.894, +0.447) in the Reaver (on integration), Lamplighter (rr-52) and Cantor (rr-56); Lancer, Seer and Thrall have (0.894, -0.447). Rear moves head down-screen and snap about 60 px up each tile (`Motion.root_offset`). `recompile.py` copies the old projection, so the bad value came from the first compile.
- **Speed:** every humanoid_v2 enemy walk is authored at 0.85-0.9 s per tile (six steps), and `combat_pacing.walk_frame_seconds` caps enemy tiles at about 0.18 s, so the legs run about 4.6x fast. Owner gets side-by-side options (keep the enemy pace with fewer, longer steps vs. a slower walk for humanoids); joint budgets limit long strides.
- Codex slots have been empty since roar-01 landed; the owner's pause covered only the polish slot.

## 2026-11-02 evening: polish slot paused
- **Later:**
  - roar-01 landed (ef911994b, owner APPROVED).
  - pol-42 and pol-43 merged; pol-46 rejected (hover pop-ups may cover controls).
  - fb-objectives approved; it was already on integration.
  - pol-45 r2 running (owner-requested rework).
  - pol-43's deal test was too short for the slide; `pol-43-fix` (test only) merged at 18cbf1d0c. Hand-flow and feel suites are green on integration.
  - Also merged: pol-41 and pol-36. pol-45-r2 approved and merged (0aff5aa19).
  - Rig reels posted as `lamplighter-rig-2`, `cantor-rig-2` and `reaver-rig-2`; the old rig entries are closed as superseded. Tools: `output/rig-reels/tools/`.
  - The reels show that the walk plays about 4.5x faster than authored (enemy moves are capped at about 0.18 s per tile) and that death's dissolve hides the slump. Both are game behaviour, flagged to the owner.
- **Owner:** pause the polish slot's new picks; keep merging approvals; restart only when asked. pol-47 (camp menu) finishes and is posted.
- **Merged (owner APPROVED):** pol-34, pol-37, pol-38, pol-39, pol-40 (the hand's motion set). Open branches all merge-tree clean on integration: pol-41, 42, 43, 45, 46, 36, roar-01.

## 2026-11-02 evening: roar-1 posted
- **roar-01** posted as inbox `roar-1` (branch `codex/roar-01` 34dabfc46, worktree kept until the verdict).
  - Round 1 moved the clip to game time, fixed the tail and pelvis attachments, and clamped per dragon.
  - Native seam check: 0 attachment or single-part failures, every dragon within its approved-clip baseline. The gate reports FAIL only for CPU calibration under-counting one Iskaldra frame (tooling).
  - Codex SIGNOFF; its Low finding is fixed.
- **Polish:** pol-41, 42 and 43 posted; pol-44 director-merged (probe-only path; players never saw the streak); pol-45 running.
- **Next:** handle verdicts; on roar-1 approval, merge (`merge_unit.sh`) and consider the guardians' opening.

## 2026-11-02 afternoon: roar-01 running, playtest 22 pinning
- **Running (Codex):** roar-01 (brief `.codex/tasks/briefs/roar-01.md`).
  - All six dragons are cutouts, so this is a procedural `roar` clip, not new art.
  - The dragon faces the screen (`front`, mirrored toward the hero) for the opening.
  - Timing: a 0.40 s gather, a snap to the peak on the cue, a held tremble, and recovery. The opening grows from 1.4 to 1.9 s.
  - Director runs the native contact sheets and fight-opening clips.
- **Running (polish):** pol-41 (the old card's keyword box leaves with it).
- **Posted, awaiting owner:** pol-34, 36 to 40, plus the older pol-02, 12 and 20. Merge order: pol-38, then 39, then 40.
- **Playtest 22 posted** (inbox `playtest-22`; playtest 21 closed as superseded). Pinned at e6b09e8c2 in `peer-benchmark-playtest-22`; playtest-19 removed. Import, cel_look build, Python default group green (178 tests), 4 fixtures verified (start, warband, tharokh, moth library). Keep the playtest-21 worktree until the owner moves to 22.
- **Next:**
  - review roar-01's frames natively;
  - then the guardians' opening (Spotted) if the owner likes the roar.

## 2026-11-02 midday: polish verdicts merged
- **Merged (owner APPROVED):** perf-13 (hand sweep over-33 45% to 0%), pol-09, 10, 11, 14 to 19, 21, 22, 24 to 29, and pol-16 round 2 (Scavenger's Nook and fixed names for rooms without a fight).
- **Awaiting owner:** pol-02, 12, 13, 20, 30 (Volt Surge 4 damage), 31 (Character Deck column matches the preview); `cantor-rig-1`, `lamplighter-rig-1`, playtest 21.
- **Running (polish):** pol-23 round 2 (thinner, centred "?" plus an Umbra pool under unknown rooms), pol-32 (self-picked).
- **Queued for a Codex slot (owner follow-up on pol-27):** dragon fights open with the dragon turned toward the screen, plus a real roar animation timed to the opening roar. Needs a design pass over the six dragons' rigs first.
- **Next:** cel_look build and a playtest 22 pin once these merges settle; fill Codex slots with gameplay work.

## 2026-11-02 early: playtest 21 posted
Pinned worktree `peer-benchmark-playtest-21` at 8593be76e, 5 launches verified, inbox `playtest-21` (playtest 20 closed as superseded).
- **Merged since playtest 20:** pol-03 to pol-08 (owner APPROVED), mq-26, perf-11 and perf-12 (native hover over-33 20% to 2%), qa-16/18/20 (run hunt; stale enemy index fixed, which had shown wrong threat tiles; freed-object cast; null texture; shared-tile click), qa-17 (keyboard map entry), qa-19 (typed-array audit only; rewrite parked), qa-21 (golden re-pin), gate-01 (as-shipped sheet row), meas-06 (difficulty tools; decisions recorded).
- **Awaiting owner:** pol-02, pol-09 to pol-18; `cantor-rig-1` (rr-56 on its branch; strict gates still flag about 1,900 lines, mostly torn cloth; judged by eye); `lamplighter-rig-1` (rr-52 on its branch); playtest 21.
- **Running:** perf-13 (hand sweep: board preview waits for a 2-frame rest), polish item 19.
- **Next:** perf-13 native soak; merge approved polish with `pol_approved.sh` (pol-12 needs its pin refreshed at merge); Cantor and Lamplighter merges on approval (shadow cache and registry conflicts: combine by id, rerun shadow refresh, refresh pins).

## 2026-11-01 night: all five slots busy
- **Running (Codex):** meas-06 (whole-run bot with a growing deck: does the section 2 to 3 drop survive?), qa-16 (one-off crash and softlock hunt through whole runs in the real scene), rr-56 (Storm Cantor rig; director motion and underlays staged), perf-12 (one hover refresh per frame, base perf-11). Polish item 9 running.
- **perf-11 native soak (quiet machine, all focused):** clean hover 18.3 → 17.7 ms median, over-33 20% → 11%, worst unchanged; other phases unchanged; strip pixels equal (320 comparisons). Target (5%, 16.7) not met; every remaining over-33 frame is a card's first hover. Committed 51e083cde, Codex review running, merges on signoff. perf-12 goes after the rest.
- **On integration:** pol-05 to pol-08 (owner APPROVED), mq-26 (Cantor maquette and paintings, per-unit test retired).
- **Next:** handle reports as they land; native soak for perf-12 on a quiet machine; pin playtest 21 once perf-11 and the approved polish are in (`cel_look.py build --if-stale` first). Lamplighter waits on `lamplighter-rig-1`.

## 2026-11-01 night: playtest 20 posted
Pinned worktree `peer-benchmark-playtest-20` at 6af426af9, 8 launches verified, inbox `playtest-20`. Next: rr-52 proof (production passed; depth and clip running), polish item 8, perf-11 native soak on a quiet machine.

## 2026-11-01 evening: merges and queue
- **On integration:** pol-01 (Hearth), evt-03 (event rewards stand out, awaiting verdict `fb-events-pop`), rr-54 (Lancer spear, `fb-lancer-spear`), rr-53 (Reaver rig, `reaver-rig-1`), mq-27 and rr-55 (Grub repaint, `grub-rig-1`), meas-04 (shadow rooms measured). Python default green at 7a8ff4674. **Before pinning the next playtest: `python3 tools/cel_look.py build --if-stale`** (status differs after the merges) and verify launches.
- **On branches awaiting owner:** pol-02 (dimmed cards), pol-03 (crate bars). Merge with `director_tools/merge_pol.sh` on approval.
- **Running:** rr-52 r1 (Lamplighter at art_scale 1.03, CPU surface work), meas-05 (shadow dial sweep), polish item 4.
- **Held:** perf-11 hover fix on its branch, uncommitted; needs a native soak on a quiet machine, then merge. Cantor rig after mq-26 merge (director motion first).
- **Shadow rooms: closed, no tuning** (decisions 2026-11-01): the gap was the final section's depth scaling against a fixed bot deck, not the element. Pin playtest 20 next.

## 2026-11-01: 5th slot, permanent polish (owner)
Claude-only (Codex only for image generation), always running: picks its own polish items, each goes to the inbox as `pol-NN` for approve, reject or rework, then it picks the next. Standing brief `spec/peer_benchmark/polish/README.md`, record `polish/LEDGER.md`. Doesn't count against the 4 Codex slots. After a resume, check that a polish agent is running; if not, start one.

## 2026-11-01: event gallery posted; all four slots busy
- **Inbox v221:** `fb-events-variety` (all 45 as stills), `fb-events-no-dice` (the 8 rewritten, old roll in captions), `fb-events-preview` (all 76 reward hovers). Owner asked for stills instead of launches.
- **Running (Codex):** mq-27 r1 (Grub maquette v2, shorter thicker legs; front paint r1 showed the body held up on legs); perf-11 (hover spike); meas-04 (shadow rooms: hard, or the bot in the dark?); rr-53 (Reaver: integration sync, underlay clipped to painting alpha).
- **Next:** repaint Grub front and rear on the new clay, darker, then post it beside the hero; native soak for perf-11; windowed proof for rr-53, merge, then rr-52 and the Cantor rig.

## 2026-10-31: test cut done (owner APPROVED test-cut-list)
Merged 695404aa5. Measured full pass, green with no retries: 9 min 11 s (Godot 502 s, Python 178 tests 27.5 s), down from about 40 min. 1,234 test files retired; art pins in one manifest test; `tests/README.md` has the pass and the on-demand groups. Integration is ahead of pinned playtest 19 (ffd3950d5) by brs-02 round 1 and the cut.

## 2026-10-31: playtest 19 posted as separate entries (owner asked for one per point)
Pinned worktree `peer-benchmark-playtest-19` at ffd3950d5. Inbox items `fb-*`, one per playtest-18 point, each with its own launch command. Full suites last clean at c6a3dbd19 (Godot 837 s, Python 2,491 OK); since then the turn-order guard and brs-02, with the Python default and tools groups clean.
- **Owner on tests:** biggest concern. New gates in memory `test-time-budget`: no full suites before playtests or merges; full pass only before master or Steam. Briefs add no new guards except rules, saves, progression and real-bug regressions.
- **Running:** brs-02 r1 (Health flicker when wind pushes a Tick onto Fire, stale cache across fights); test-03 (cut list for owner approval, read-only).
- **Next:** merge brs-02 r1 into the next build; post test-03's list to the inbox; perf-11 hover stutter; Shadow room difficulty.

## 2026-10-31: playtest 18 feedback round (owner NEEDS CHANGES)
Owner feedback is in `spec/peer_benchmark/feedback/pt18_feedback.md`. The next build is playtest 19.
- **Done on integration:** defeat lines removed, gentler cel settings and head touch-ups for Tharokh, Noctyrax and Zekarion (`tools/cel_look.json`), event catalog v2 staged (`staged/ev-03`).
- **Running or queued (Codex):** mv-01 smooth rig walking; chn-01 Chain from footprints; brs-01 Burst readability, feathered glows, objective copy; srf-01 stacked surfaces and tooltips; flu-01 retire Flurry; evt-01 event rules (no dice, preview, rotation). Image jobs evart-a and evart-b: 18 new paintings.
- **Next:** evt-02 (event screen hover previews and tactile beats, after evt-01); Grub grounding (director capture first); roster row audit decisions from brs-01; playtest 19 with `--all-groups` before the build.
- **Still open:** hover stutter (perf-11), Shadow room difficulty, playtest 16 Guardian and dragon questions.

## Layout
- Integration branch: `codex/peer-benchmark` at `../Labyrinth.worktrees/peer-benchmark` (base master 816f5e68a).
  Units branch from it (`CU new <id> --base codex/peer-benchmark`) and merge back after review.
  Nothing is pushed or landed on master without explicit owner approval.
- Capture worktree (detached, local only): `../Labyrinth.worktrees/peer-benchmark-capture`
  = integration + trailer tooling 006c2ccec (unlanded branch), for clips via tools/trailer_director.
- Media for the owner: `Labyrinth/output/peer-benchmark-2026-10-12/` (primary checkout, untracked).
- Research: `Labyrinth/output/benchmark-research-2026-10-12/` (StS, ITB, Umbra inventory).

## Milestone
M2 — identity-gated roster upgrade (wave 1a/1b) + polish units; history below in dated updates.

## In flight (2026-10-19; humanoid rig v2 + roster wave 1)
- 2026-10-31 06:30:
  - **Integration:** fb3f239bb. Godot full suite PASS (844 s, no retries); Python `--all-groups` 2488 OK, 66 skipped.
  - **Playtest 18 posted** (inbox v208): worktree `peer-benchmark-playtest-18`, detached at fb3f239bb, 13 verified launches. Awaiting the owner. Playtest 16's Guardian and dragon questions stay open.
  - **Merged since playtest 16:** Last Light and the Hoarder (int-09), test-01 and test-02 (test economy), perf-08 and perf-09, cel-01 and cel-03 (cel is the default and ships), thr-01 (Tether gone; no enemy paths at rest), sta-01 (Veiled gone; Dive from shared pieces), mrk-01 (Marked), mim-01 (Echo, enemy Retaliate), int-10 and int-11.
  - **Dropped:** perf-10 (branch kept unmerged): no frame benefit in the clean soak, and it carried save-threading risk.
  - **Clean soak (`soak_clean_2026-10-31.txt`):** enemy turn 0.4% over 33 ms, p95 16.5 ms; card play 0.2%; hover unchanged at 18-20% over 33 ms, p95 about 42 ms. Cel on and off are the same.
  - **Next:** perf-11 for the hover spike (one long frame on each target change, not yet confirmed); find out whether shadow rooms are too hard or the bot is poor in the dark (bot wins near zero in standard Mimic and Stalker rooms at tiers 2-3, before and after these units); rr-48 proof, rr-52, mq-26 and Cantor rig; recapture store media in the cel look before launch; clear `/private/tmp/labyrinth-godot-home` (62 GB) when nothing runs.
  - **Raw notes:** `notes_2026-10-30.md`.
- 2026-10-30 09:45:
  - **Merged:** rr-51, the Gaoler drawn at 1.10× the hero (78bf06f3c; Opus review SIGNOFF 3c593bfad plus director
    fixes c559c4b27).
  - **Playtest 16 posted** (inbox v196): worktree `peer-benchmark-playtest-16`, detached at 78bf06f3c, 16 verified
    launches (start persist/snap, six Guardians, six dragons, Warband, Snare). Python suite green; Godot green apart
    from sub-suites starved of the 900 s program budget under load, which all pass run one by one.
  - **Owner verdicts:** `cantor-paint-3` APPROVED (thinness exception at the original's level); `last-light-v2` and
    `ember-hoarder-v2` APPROVED. Gameplay comes first; repaints and rigs are background work.
  - **Owner, 2026-10-29 ~17:00: back to Codex** for newly launched units, fix rounds and reviews. The Opus window
    closed early; spx-08/09 finished on their Opus subagents.
  - **Built:** spx-08 Last Light (e6ede220d, director tuning 2e0cea945) and spx-09 Ember Hoarder (f3e3315bf). Bot
    numbers are in their measurement reports; see decisions 2026-10-30.
  - **Running: int-09 (Codex)** merges spx-09 onto spx-08 (28e738838): one revision gate, one cohort API, re-seeded
    fixtures, the director's Hoarder decisions, ledger re-pins, re-measurement, both full suites.
  - **Next:** review int-09; windowed `last_light_probe` / `hoarder_probe` plus fixture launches (not while the owner
    plays); merge into integration on a quiet machine; playtest 17 with both specials.
  - **Background:** rr-48 windowed proof plus a small unit clipping its underlay to the painting alpha; rr-52 after
    rr-48; mq-26 merge, then the Cantor rig; a Gaoler real-fight clip at 1.10 for the inbox.
- 2026-10-29 13:30:
  - **Merged since 08:45:**
    - int-08: the integration failures that were already red, fixed with exact audits; fresh rr-46 native depth
      archive 20/20 (d84e791fb);
    - the demo_clips clock fix (85a114897);
    - rr-50: the Gaoler submission guard follow-ups (f4c938f36). Merged on byte-identity, because its daytime
      windowed native run stalled on a covered window;
    - the art gate preamble: forms follow the original art (65e2bee62);
    - staged/rr-52: the Lamplighter rig's motion and underlays (0a6c2f476).
  - **Owner verdicts:**
    - `gaoler-rig-2` NEEDS CHANGES: "looks really small relative to the protagonist". He drew at 0.90×. → rr-51
      (Opus subagent): `art_scale` 1.10 at hero density. The Guardians keep 1.15.
    - `lamplighter-paint-3` APPROVED. → rr-52 rig (staged), launching after rr-48.
    - `cantor-paint-2` NEEDS CHANGES: ribcage face-on, cursed hands, lost face plate, ball tines, wrong arm, sphere
      joints, "recurring". → the method changes (preamble plus the pre-post checklist in owner memory), and mq-26
      (Opus) rebuilds the maquette from the original's measured proportions. Round 2 is fixing the tines, rib droop,
      bell, far pauldron and rear hood.
  - **Owner override until 2026-10-30 08:00:** new implementation and review tasks run on Opus 5.5 subagents; image
    generation stays on Codex; Codex runs already in flight finish on Codex.
  - **rr-48 r3 (final, Codex):** in its final full-suite run.
  - **Open:** windowed captures stall in the daytime when the Godot window is covered. Asked the owner.
- 2026-10-29 08:45:
  - **Merged: the Gaoler production rig.**
    - rr-44 + rr-49 via int-07, `6135c6ec6`. Owner fixes: low chain, both arms swing, held-follow, elbow policy, joint
      caps.
    - Deterministic exact-source submission costs 1.9 ms per pose (was 23.5).
    - Native ALL GATES 0 errors, sheets and production PASS at 7fcee1697.
    - int-07 re-pinned rr-46 preservation exactly (80 deltas; 664 other-rig submissions identical). Codex SIGNOFF
      2b57e4cb7.
    - Worktrees rr-44, rr-49 and int-07 removed.
  - **Integration was already red before this merge** (hidden, because no quiet full suite ran after b17/b18).
    int-08 (running) fixes it:
    - stale rr-46/rr-47/pt14-04 pins;
    - six orphan staged/rr-48 `.import` sidecars (the director's c919c2255);
    - Godot `hero_facing_test`'s Frostbite fixture against bos-04's fresh-ground rule.
  - **Reaver rr-48 r3 (final, running):** finishes the in-progress sync merge (one shared runtime, the Gaoler's
    implementation wins), then `rr-48_feedback_3`:
    - CPU ⊇ native;
    - exact director paint accepted as painting;
    - the full underlay domain behind the body;
    - the near-arm walk swing restored;
    - clamps with a 60% floor;
    - full suites.
  - **rr-50 (running):** the rr-49 re-review follow-ups (fast-path timing guard, dead hash, LRU 16 / ≤ 4 MiB).
  - **Next:**
    - a Gaoler real-fight clip to the owner;
    - the fresh rr-46 native depth archive after int-08;
    - quiet full suites, then playtest 16.
- 2026-10-29 03:40:
  - **Merged since 20:40:** mq-25 + mq-24, Lamplighter take three with its paint (fc37fffd4; sidecars c919c2255).
    Full suites still pending on a quiet machine before playtest 16.
  - **Gaoler (rr-49):** final round committed 2bd5ea39a. Director native proof at that HEAD: `RR44 ALL GATES: PASS
    (0 errors; native=True)`, sheets PASS (16 frames), production 88 + 64 cases with 0 errors. The joint Codex review
    of rr-44 + rr-49 is running, then merge, remove the rr-44/rr-49 worktrees, and post a Gaoler motion clip.
  - **Reaver (rr-48):** r1 committed 7b4198b20 (underlays wired exactly, idle, root-relative held-follow, floor oracle).
    Joint tears come from missing hidden paint at the seams, not motion size. r2 is running on `rr-48_feedback_2`: tucks
    from the underlay; shoulder, wrist, grip and elbow joint caps; grip attachment; slivers; then budgets. r3 is final.
  - **Inbox waiting on the owner:** cantor-paint-2, lamplighter-paint-3, playtest-15.
  - **Bridge:** still lists mq-24 and mq-25 (removed). Restart without them when the bridge is next needed.
- 2026-10-28 20:40:
  - **Merged into integration since 16:50:**
    - mq-22 + mq-19, the Cantor take two with its paint (ff690e605);
    - rr-46 + rr-47, back-row depth;
    - mq-23 + mq-21, the Reaver take two and its paint, including the owner's leg fix (7f560c4b2);
    - bos-04, fresh ground never fuels a beat (conduction too), with the banner scoped to its fight.

    The focused checks pass on integration. **Full suites are still pending** on a quiet machine before playtest 16.
  - **Owner verdicts:**
    - Reaver `reaver-paint-3` **APPROVED**, so his rig is next: rr-48, running, with the director's motion in
      `staged/rr-48`.
    - Lamplighter take two: NEEDS CHANGES. Take three's paint is posted (`lamplighter-paint-3`, waiting on the owner).
      mq-25 is ratifying the as-built fist and accepting the delivery.
    - Cantor take two is still waiting (`cantor-paint-2`).
  - **Gaoler:** rr-44's final round passes on CPU but fails 52 native gates (single texels, the idle hold, the released
    chain). rr-49 is running and must make the CPU sweep reproduce each one, then fix it.
  - **Tuning:** after bos-04, Vyraketh is 46% and Zekarion 24%. Zekarion is accepted for the playtest (noise-level;
    beats are now about 1 HP per fight). Lightning Warband T3 is 50%.
  - **Bridge:** mq-24, mq-25, rr-48, rr-49.
  - **Disk:** 207 GB free.
- 2026-10-28 16:50:
  - **Merged into integration:**
    - mq-20, Lamplighter take two (5cbcdfec4);
    - bos-02, dragons on the rules (666eb44fe; bos-03 conflicts unioned, including a three-way JSON merge of the 25
      rule instances);
    - hf-01, hero facing (persist|snap; pt14-04 conflict unioned).

    Focused tests pass on integration after each merge. **Full suites not yet re-run:** run both on a quiet machine
    before playtest 16.
  - **Model:** back on sol (owner, after the astra trial). `projects/Labyrinth.json` has no "model" key.
  - **Art:**
    - **Cantor take two:** paint front and rear approved by the director and posted (inbox `cantor-paint-2`,
      v180). The as-built cloak profiles are ratified. mq-22 hardens the proof (no regeneration).
    - **Reaver:** mq-21's model has the right look, but the near arm is 1.14× and the legs are 1.02× (limb lengths
      never change), so mq-23 is rebuilding it. The paint colour is settled: v3, warm gunmetal, saved as
      `mq21_front/look_reference_v3.png` in the mq-21 worktree. Repaint on mq-23's geometry.
    - **Lamplighter:** owner `lamplighter-paint-2` NEEDS CHANGES: "drop the shoulders (still boxes), hands a mess".
      → mq-24: no plates, mantle over the shoulders, real clawed hand, fist through the ring.
  - **Rules:** bos-04 is running. Fresh ground never fuels a beat before your turn (Cantor, Zekarion, Iskaldra). It
    also pins the rule matrices, clears the half-Health banner on fight load, makes the probes exit 0, and
    re-measures. Zekarion is 24% (below band), to be retuned after bos-04.
  - **rr-47 r2:** the diagonal-midpoint depth host. rr-46 and rr-47 then merge together.
  - **rr-44:** final round still running.
  - **Bridge:** mq-19, mq-21, mq-23, mq-24, rr-44.
  - **Inbox waiting on the owner:** cantor-paint-2, playtest-15.
- 2026-10-28 13:15:
  - **int-06 merged** (978a3e3c1). Batch b17 is effectively green. Python fails 1 test that passes alone. Godot
    failures are 900 s budget timeouts under load, so re-run the full Godot suite on a quiet machine before the next
    playtest.
  - **Owner verdicts:** the Reaver, Cantor and Lamplighter repaints NEED CHANGES ("toy soldier" poses plus specific
    fixes) → maquette takes two mq-21, mq-19 and mq-20, then repaint. `mirror-real-fight-2` APPROVED.
  - **Tuning:** bos-03 final round running (Rimejaw and Lamplighter decided; Cantor's last ladder). bos-02 final
    round queued (five dragons in band; Zekarion's last rungs).
  - **rr-47:** fixes the rr-46 vanishing-unit defect, with native 20/20 PASS. r1 (verifier) queued, then a review and
    the merge of rr-46 + rr-47.
  - **hf-01:** hero persistent facing, A/B switch, running.
  - **Model:** `gpt-6-astra` for new runs today (owner). Revert `projects/Labyrinth.json` "model" afterwards. The sol
    backup is in the session scratchpad.
  - **Inbox waiting on the owner:** playtest-15.
- 2026-10-28 00:30:
  - **Merged into integration** (b16 batch):
    - card-02, sum-01, card-01 and rr-45;
    - pt15-01 and bos-01 (registry conflict unioned);
    - mq-16, mq-17 (suite-resources conflict unioned) and mq-18;
    - then enc-03 + enc-04 (four conflicts resolved by the director; post-merge override fix a420283fa).
  - **Batch suites at 76699466b: RED.** Godot 7, Python 8 failures and 8 errors, all from cross-unit interactions.
    **int-06** is running to repair them at the cause, with the logs at `/private/tmp/labyrinth_codex/int-06/`.
  - **Running:** bos-02 (dragons) and bos-03 (Guardians), r0 on 76699466b; rr-44 r2 (final; director paint decisions in
    `briefs/rr-44_feedback_2.md`); int-06.
  - **rr-46** r2 committed f4eb556b0. The director's native fire-Slag case is running, then the matrix and a
    re-review.
  - **Inbox, waiting on the owner:** reaver-paint, cantor-paint (staff exceptions), lamplighter-paint (posted
    2026-10-27 22:57), mirror-real-fight-2, playtest-15. After the art approvals: rig the Reaver, Cantor and
    Lamplighter.
  - **Disk:** 252 GB free; merged worktrees removed.
- 2026-10-27 21:20:
  - **Inbox `reaver-paint` posted:** Ashen Reaver front + rear paint-over (front first try; rear after one edit for
    true-rear details). Gate metrics all pass at art_scale 1.0 (235/228 px drawn; 1.09× hero). Job files are in the
    mq-16 worktree under `spec/art_identity/jobs/ashen_reaver/` — **commit that path only after mq-16's current
    round ends** (Codex is working in that worktree).
  - **bos-01** in its last round (r3): the encounter-measurement golden fails only on bos-01 (passes on
    integration); diagnose and fix, then full suites.
  - Storm Cantor paint-over waits for mq-17 r3 (chunkier volumes) after its proof round.
- 2026-10-27 20:40:
  - **Maquettes:** mq-16 Reaver (r2: falchion and pauldrons fixed) and mq-17 Cantor (r1: volumes) committed and in Codex
    review. Front paint-overs launched as image jobs (`img-ashen-reaver-front`, `img-storm-cantor-front`; jobs under
    each worktree's `spec/art_identity/jobs/<id>/mq_front/`). Next: process → review sheet → judge → rear from the
    approved front → owner inbox. mq-18 (Last Lamplighter maquette) running; Blender bridge restarted for rr-44 and
    mq-16..18.
  - **bos-01** in fix round 2 (switch moves to the committed-transition point). bos-02/03 wait for its merge.
  - **sum-01** accepted (7e8b0c2b8) over one save-tamper finding; merge after the windowed proof.
  - **card-02** last round (r3) running; **card-01**, **enc-03**, **pt15-01**, **rr-45**, **rr-46** wait on director
    windowed runs, which queue behind the rr-45 proof's long CPU "sheets" stage holding the lock.
  - **rr-44** (Gaoler) needs director paint/clear judgment after its native proof.
- 2026-10-27 19:40:
  - **Owner approved `boss-rules`** and asked that summons grant an extra play. bos-01 (engine dials) and sum-01
    (summon → +1 Card Play next turn) are briefed and queued; bos-02 (dragons) and bos-03 (Guardians) follow bos-01.
  - **Mirror (`mirror-real-fight`, NEEDS CHANGES):** real causes found (chip over the lower foot; registration on the
    old painting). pt15-01 briefed and queued; thread replied, left open until the new capture is posted.
  - card-02 r1 committed 91520eb4b and in Codex re-review; card-01 r1 queued (review findings).
  - Queue after the 4 running units (mq-16, rr-44, rr-45, rr-46): enc-03 r2 → pt15-01 + mq-17 → card-01 r1 → bos-01 →
    sum-01. Machine load ~15-19 on 15 cores, so no forced fifth slot.
- 2026-10-27 18:30:
  - **card-01** committed 102995e00. The director's windowed before/after is OK: Worldbreak and Cloudstep Loop wrap
    their trailing icon and value onto a second centred line, and nothing is clipped in the deck view or the hovered
    hand. The Codex review is running.
  - **card-02** is in fix round 1. The Codex review of 27aae27c8 asked for changes, and `briefs/card-02_feedback_1.md`
    already covers its four findings.
  - Running: card-02 (r1), enc-03 (r1, scaled copy), rr-44 (r1), rr-45. Queued: rr-46, then the mq-16 resume.
  - The hand-cards-at-rest item is closed with no change (decisions.md, 2026-10-27: the hand at rest is a glance view).
- 2026-10-27 19:05:
  - **enc-03 r1** windowed proof PASS: the badge reads "Lob Slag" + 7, danger tiles show from aiming, and the copy is
    exact. Round 2 is queued (`briefs/enc-03_feedback_2.md`): the leader medallion draws over the callout's end, and
    the barrage's two crosses get "in each centre … around them" copy.
  - **rr-46** and the **mq-16** resume started (5 running for a moment: two queued launches took one freed slot).
  - **mq-17** (Storm Cantor maquette) is briefed with exact pose values and queued behind enc-03 r2. The Blender
    bridge was restarted for rr-44, mq-16 and mq-17 (tracked job).
- 2026-10-27 17:50:
  - **Inbox:** `boss-rules` posted for approval (the draft and director decisions are in
    `encounter_redesign/boss_rules_draft.md`). `mirror-real-fight` posted: the real-fight Mirror evidence from the
    fix-18 native captures (1600x900).
  - Owner played the fire Warband → **enc-03** is running and **rr-46** is queued.
  - **card-02:** windowed proof PASS (Shrapnel Bomb identical in hand, deck, campfire and Scavenger); the Codex review
    is running.
  - **mq-16:** round 0 stopped on 7 TODO_DESIGN pose values. Exact values are in `briefs/mq-16_feedback_1.md`; the
    resume is queued. The Blender bridge was restarted for rr-44 and mq-16.
  - Running: rr-44, card-01, rr-45, enc-03.
- 2026-10-27 16:40:
  - **Integration 64c6a6d26 is green**: Godot passes and Python passes (2,111 tests). It includes pt14-04 (badge side)
    and fix-18 (the Continue offset). **Playtest 15** is posted (inbox `playtest-15`): a detached worktree `../Labyrinth.worktrees/peer-benchmark-playtest-15` at 362221d20. The start, six Warbands (one per element) and air/fire Snares are verified. Playtest 14 is superseded; the owner's shell still sits in playtest-13.
  - Owner: the element rules "feel pretty good". They approved redesigning the dragon and guardian fights on the same
    pieces. A draft is in progress (`encounter_redesign/boss_rules_draft.md`, subagent); the director reviews it, then
    posts to the inbox.
  - Running: rr-44, card-01, card-02, rr-45. Queued: mq-16 (Ashen Reaver maquette; restart the Blender bridge with
    the mq-16 worktree when it starts).
  - Next for the director: the hand-cards-at-rest mockup (13 px → legible), and the Mirror evidence from real fights
    (the pt14-03 probe, now that fix-18 is in).
- 2026-10-27 15:55:
  - **fix-18** is in fix round 1 (`briefs/fix-18_feedback_1.md`).
    - The review confirms the root cause.
    - Remaining: draw-time allocations, a travel-anchoring test gap, and the frame-size contract (director decision:
      the window's logical size, ≥1600x900, in fix-18's probe copy only).
    - Native after-captures already show every rig-v2 actor on its tile after Continue and through a resize
      (`/private/tmp/fix18-native/`).
  - **rr-44** is in fix round 1 (`briefs/rr-44_feedback_1.md`): native ground truth (2,683 native errors, mostly front
    death), the press elbow seam, a weak press wind-up, the production binding, `held_follow` in the body frame, and
    the maquette `native_probe` FAIL. The Blender bridge is running (tracked job).
  - **lit-01** was shelved by the owner (too subtle).
- 2026-10-27 15:10:
  - **pt14-04 merged** (ffa95b479, Codex SIGNOFF 5e5e03638) without suites. The full suites run once, after fix-18
    merges.
  - **lit-01** is committed on its branch (49ef9f92a; not merged; default off). Native A/B is posted as inbox
    `prop-lighting-spike`, waiting on the owner. The effect is modest at full screen and clear on pillars beside
    torches. The shadow rebuild costs 30–50 ms per layout change, so it must move off-frame before it ships.
  - **rr-44 round 0** is done but not acceptable yet: CPU sweep 807 findings, suites red (91 Godot program timeouts
    under load, 11 Python failures). The Blender bridge is running (tracked). The maquette refit captured, but
    `native_probe` FAILs (`/private/tmp/labyrinth_codex/rr44-maquette-native/`). The director is running the windowed
    stages (logs `scratchpad/rr44_r0_<stage>.log`).
  - Next for rr-44: feedback 1 hands Codex the native frames and gates as ground truth (CPU ⊇ native) and the
    maquette probe result, and settles `TODO_DESIGN_held_follow_reference_frame`: grip displacement is measured in the
    body frame, relative to the root and pelvis travel, so only the arm's own swing moves the hook.
- 2026-10-27 17:15 (resume checklist):
  - **Running (detached Codex):** rr-44 round 0 (Gaoler), fix-18 round 0 (Continue bug), pt14-04 round 0 (replaces
    pt14-01's runtime hero-silhouette build with precomputed data; pt14-01's rounds are used up, branch
    `codex/pt14-01` 2b0cc4cd5, worktree removed), lit-01 round 1 (`briefs/lit-01_feedback_1.md`: stronger tuning,
    crop bug, off-identity under a frozen clock, fire Warband room).
  - **On resume:**
    1. Run `codex_unit.py status`, then arm one watchdog.
    2. Re-arm the inbox comment watch (ArtifactComments `watch` on the inbox URL).
    3. For each finished unit, read its `result_N.md`, then run its windowed proof. pt14-04:
       `sh tests/pt14_01_design_owner_proof.sh`. lit-01: `tests/prop_lighting_owner_proof.sh`. fix-18: the pt14-03
       probe commands.
  - pt14-03 is committed (b110566f4) and its worktree is kept for the native probe runs.
  - Waiting on the owner: the playtest-14 notes.
- 2026-10-27 16:30: **Production bug found: fix-18 running.** After Continue into a saved fight, every rig-v2 enemy is
  drawn 370–480 px below its tile. Production code here equals playtest 14. Evidence comes from the pt14-03 native
  probe (b110566f4, root-viewport capture): natural spawns are affected too, it persists over 120 frames and a
  resize, and the hero is fine. The rig-v2 presentation positions are stale (`pixel_presentation.gd:76/79`).
  - pt14-03's probe is the reproduction. The Mirror evidence waits for fix-18.
  - **lit-01 running**, the owner-requested prop-lighting spike: a Python port of Sprite Fusion Sprite Normals,
    prop normal shading, torch-cast prop shadows, all behind `LABYRINTH_PROP_LIGHTING` (default off).
  - Running: rr-44 (Gaoler), pt14-01 round 3 (silhouette build on a worker thread), lit-01, fix-18.
- 2026-10-27 15:40: **gaoler-pose APPROVED.** **rr-44 is running** with the director's art (fd9a0e439): the lowered
  arm in both views, the underlays, the motion, and brief `briefs/rr-44.md`. After its first round the director runs
  the native stages and hands Codex the native ground truth.
  - **pt14-01** is in re-review after fix rounds 1–2 (a9dc7dccd): export-aware rear silhouettes, the equipped hero
    silhouette, warm-up at combat setup, zero layout misses.
  - **pt14-02** is in its final round (3).
    - The Mirror probe's offset is probe-only (a post-layout cache write).
    - The real-fight probe found maquette enemies (Mirror, Seer) submitted ~440 px below their tile after
      Continue, in a headless draw-path trace. Round 3 saves native frames at +0/+30/+120 frames to tell a transient
      from a persistent offset. If it is real, it becomes a separate unit.
  - **Owner question, answered:** sprite normal maps (Sprite Fusion Sprite Normals, MIT, Rust CLI). Recommended a
    spike: maquette normal pass for rigged enemies, the library (low brightness weight, whole-painting) for the hero
    and props, wired into the existing CombatArtTreatment shader, plus torch-direction contact shadows. Waiting on
    the owner: now or after the Gaoler.
- 2026-10-27 14:10: **Owner verdicts (inbox):** heirloom-screen-built APPROVED; lancer-rig-v2 APPROVED (spear-shaft
  show-through logged in the new `backlog_art.md`, low priority); gaoler-rig NEEDS CHANGES; pt13-badges NEEDS CHANGES.
  All four threads were answered and resolved. Verdicts are in `feedback.md`.
  - **Gaoler (rr-44, designing):** the owner rejected the lantern hold, the one-armed walk, the hook direction and the
    free elbow's backward bend; death is "perfect". The director is repainting the chain arm low at his side, with the
    hook pointing away from his body: the front (img-rr44-gaoler-front-arm-r1, composited by
    `staged/rr-44/compose_arm.py`) is done, and the rear (img-rr44-gaoler-rear-arm-r1) is running. Motion is in
    `staged/rr-44/motion_tracks.json`: shoulder_pendulum arms, `held_follow` chain sway, `elbow_policy`, and the hands
    carrying the hit. Next: post the still to the inbox for a quick look, then the body underlay for the new arm
    footprint, then the rr-44 brief (re-fit the maquette's far arm, re-cut, elbow gate over every rig, full suites in
    the final round).
  - **pt14-01 (running):** an intent chip takes the lower-left spot when it covers clearly less of other units' and
    props' rest silhouettes. The hero counts double, and the margin is 15% of the chip area.
- 2026-10-27 04:45: **Playtest 14** is posted (inbox `playtest-14`). It is a detached worktree
  `../Labyrinth.worktrees/peer-benchmark-playtest-14` at 8f930994a; the start, warband and snare fixtures are verified.
  Playtest 13 is superseded. Its worktree is kept for now because an owner shell has it as its working directory.
  - Batch 13 is fully green on integration 4dd8abd43:
    - Godot: one failure, fixed in afb0ff82d. It was a test: the headless pointer at (0, 0) hovered the reference slot
      after pt13-03's layout change.
    - Python (parallel runner, 2,097 tests, 23 min): three failures, all stale pins from pt13-03, fixed in 8f930994a and
      by the pt13-08 merge.
  - Merged since: fix-17, pt13-03, perf-06, perf-07, pt13-08 (see units.md). The Codex preamble now requires a
    `tools/python_suite_resources.json` entry for every new Python test module.
  - Director follow-ups:
    - Worldbreak and the upgraded Cloudstep Loop overflow the parchment by 2-6 px. Look at a windowed capture, then
      fix the copy or the layout.
    - Card views built from an id (deck view, campfire, purge, Scavenger, boons, Graftwright) show base text, not
      item- or relic-modified text, for example Nail Bomb's Consume/Exhaust. Decide whether they should show the
      modified text.
  - Waiting on the owner: playtest 14, plus verdicts on pt13-torches, pt13-boss-preview, pt13-mirror and pt13-dial-graftwright.
- 2026-10-27: **Batch 13 merged** into integration: pt13-01, pt13-02, pt13-04, pt13-05, pt13-06, pt13-07 (heirloom
  screen, approved mockup), rr-42 (Gaoler v2) and rr-43 (Lancer). Each had focused proof and a Codex SIGNOFF.
  - The batch full suites ran once: Godot 9 failures, Python 6. The director fixed the shadow cache (6f8f25315) and
    the Dial copy (ecbb6e2f1). **fix-17** (running) repairs the rest: the Gaoler travel contract, the heirloom test
    registration, the humanoid_motion pin, the rr-41 reseal, the encounter golden and measurement, and FIX-14.
  - **pt13-03** (card legibility) is in round 3 of 3: production-hierarchy measurement, no vacuous passes, UID
    sidecars, and the run_scene hotspot.
  - **perf-06** (test speed, owner-approved): a parallel Python runner, 18 min against 104 min serial, with the same
    2,012 tests and every sweep still running. Digest-gated skipping was rejected as unsafe. Round 2 of 3: workers
    import only their assigned modules, and the shard deadline is asserted. After merge, `merge_unit.sh` and
    `batch_suites.sh` switch to `tools/run_python_suite.py`.
  - Codex now runs full suites only when a brief asks; the director runs them once per merge batch (preamble change
    approved by the owner).
  - Next: merge fix-17, pt13-03 and perf-06 → full suites once (parallel runner) → **playtest 14** (detached worktree,
    start/warband/snare fixtures verified) → inbox, then playtest 13 is superseded.
- 2026-10-26 15:55: **Playtest 13** is posted (inbox `playtest-13`). It is a detached worktree
  `../Labyrinth.worktrees/peer-benchmark-playtest-13` at 831d3c185 (sb-03 merged). The start, warband and snare
  fixtures are verified. Playtest 12 is superseded.
  - **Owner notes from playing** (`spec/peer_benchmark/pt13_owner_feedback.md`) produced six units, all running or
    queued, with briefs in `.codex/tasks/briefs/pt13-0N.md`:
    - pt13-01: the Black Sun Dial becomes "Each ground tile you Expend gives your next attack +3 damage (up to +9)",
      and the Graftwright's runtime fight gate is removed. Round 0 is accepted; round 1 counts Magma Vent and
      Cinder Patch, decided by source.
    - pt13-02: intent chips slide at most 24 px and avoid only HUD.
    - pt13-03: the card legibility audit (14 px text / 16 px icons), equipment previews at 224 px, and the Sabatons
      root cause.
    - pt13-04: the boss bar damage preview, matching the regular bars.
    - pt13-05: animated biome torches; all six biome idle sheets were nearly frozen.
    - pt13-06: the Glacial Mirror registered at its two-sole midpoint.
  - **Heirloom screen:** the director's mockup (`staged/heirloom/`, choice and ceremony) is posted as inbox
    `heirloom-screen` for approval before the build.
  - **sb-03 merged** (4d32522d8, sidecars 831d3c185): Godot PASS. Python failed only `test_sb02_movement`. Its
    worst-sample wall-clock gate fails under load, and an A/B showed pre-sb-03 fails the same way. Fixed in
    9bce8a562: the gate now uses the best cold repeat and the median warm plan, with the 4 ms cap unchanged.
  - **rr-43** (Lancer owner fixes): round 0 is accepted. Rear v2 is registered and re-cut, and the front spear is
    one rigid piece. Round 1 adds the house outline to the director's rear recipe (`edge_light_share` 0.108 to 0.0)
    and runs the full suites.
- 2026-10-26 07:05: rr-41 MERGED (1d584e0b1; Godot PASS, Python OK). The Lancer's cloak lining is painted, native
  ALL GATES PASS with 0 errors, and inbox `lancer-rig` was updated with the before/after and the new reel. The
  rr-37/39/40/41 worktrees are removed.
  - rr-38 (Gaoler) used its three rounds. Its CPU sweep is now calibrated to native ground truth (263/263 signatures),
    but the native frames still tore: walk fill block, press coat patch and shoulder seams. Codex capacity stalled
    round 3 three times; resumed after an hour.
  - **rr-42** (running, base codex/rr-38): director Gaoler body underlay (`staged/rr-42/`, approved at 3×; arms, chain
    and legs removed, gambeson flanks and coat lining painted), floating continuation fills removed, motion at the
    director's targets clamped per channel to native-clean budgets (floors: press 10/12, hip −10), full suites in the
    final round.
  - Memory saved: rig units need native ground truth handed to Codex (`rig-native-ground-truth`).
  - Next: rr-42 → director native judgment → merge → Gaoler inbox item → playtest refresh (fb-01, fix-11..16, the
    Lancer, tt-01/02, sb-01/02, the Gaoler).
- 2026-10-25 23:45: sb-01 + sb-02 MERGED (bd8ecf2a7). The director truncated `tests/test_program_suite_runner.py`
  while resolving conflicts (a write-before-read in a script); repaired in a39c096c1. The registration guard and
  runner tests pass, and the full Godot re-run passes. Inbox `status-badges-built` is posted (mock vs build at 2×,
  Ice and Air Warbands).
  - rr-41 round 1 (68f12c82e): 396 more UVs resolved from director paint; per-cloak verifier. Windowed proofs
    queued, then a Codex re-review.
  - rr-38 round 2 running: rear knee pocket filled by same-piece row extension (decided), CPU-findings triage,
    sidecar tracking.
- 2026-10-25 20:30: three lanes in review.
  - **sb-01 + sb-02**: Codex SIGNOFF at 1ee314e2a (bounded placement, hero on top, prefiltered plans with worst cold
    2.2 ms, movement 1.13×, Burst restored, A→Freeze→A stale-plan fix). Director final captures queued, then merge
    with the full suites and post the build beside mock B.
  - **rr-41** (Lancer cloak lining): the director approved the legs underlay at 3× (`staged/rr-41/`). Round 0 got
    CHANGES REQUESTED: the gate must certify the posed vacated leg region, and the verifier must check per-cloak
    ownership. Feedback 1 is written and resumes after its windowed proofs finish.
  - **rr-38** (Gaoler) round 0, director-judged: the rig reads well. The native gates fail on the walk; death floats
    the chain, the kneel doesn't read and the chain arm stays up; the press is too small. The director edited the
    motion data (chain.drop, arm fall to −36, press wind-up 22 / slam 18, all clamped to joint budgets) and decided
    the rear near arm stays under the cowl. Feedback 1 is running, with full suites in its final round.
- 2026-10-25 18:30: tt-02 MERGED (9d7e3bb96; Godot PASS, Python OK) and perf-05 MERGED (c13aaaa59; its four shards
  pass on integration). Inbox `short-tooltips` was updated with both passes and three questions: length and tone,
  wider panels, and dropping the Melee/Ranged/Range panels like Time.
  - Running: **rr-38** (Gaoler rig, base bbb11242f) and **sb-02** feedback 1 (head-room band decided, hero group on
    top, ≤ 4 ms plans, en01 Burst and perf-03 equivalence regressions, native crowded encounters, full suites).
  - Next: merge sb-01 + sb-02 and post the built nameplates beside mock B; rr-41 (Lancer cloak lining); then the
    playtest refresh.
- 2026-10-25 17:00: LANCER MERGED (rr-40 with rr-39, rr-37 and mq-14; bbb11242f). Python is OK. Godot's only failure was
  perf/transition_failure_case timing out at 180 s under concurrent Codex load; re-run alone it passed in 118.5 s.
  - The mq-11 pinned-inventory test conflicts were resolved to integration's shared `PinnedInventoryTests` scope
    (fix-13); mq-14's per-unit delivery context was dropped as redundant.
  - Inbox `lancer-rig` was posted with the review reel, the four facings in play, and an honest weak spot: a flat cloak
    lining behind the near leg in the front lunge and Frost Pin. Planned as **rr-41** (director underlay; notes in
    `.codex/tasks/briefs/rr-41-notes.md`).
  - **rr-38** (Gaoler rig) launches on bbb11242f. **perf-05** is planned: shard transition_failure_case.
  - **tt-02**: Codex SIGNOFF b5b3e0a15 (no findings, 36/36 mutations). Director renderer captures are queued, then
    it merges.
  - **sb-02** round 0 (67deb1851): bounded placement, compaction, draw order, incremental movement at 1.10× base,
    crest guard. Open:
    - the head-room band value (a brief gap);
    - the Fire edge-fit;
    - 39–40 ms cold-plan spikes;
    - an inherited sb-01 regression (en01: Ember Tick Burst badge);
    - perf/combat_frame_scenarios retained-binding equivalence.
    Director captures are queued; feedback 1 follows.
- 2026-10-25 15:00: sb-01 used its three rounds (f0d6170e7). The director judged its windowed capture: it matches mock B
  within 3 px, and the order discs are clear. The final Codex review found two Medium regressions from round 3's group
  solver: unbounded downward search (a crowded fixture pushes groups 350–500 px, under the hand) and full HUD rebuilds
  on every movement frame (about 4× slower).
  - **sb-02** (running, based on codex/sb-01) applies a director rule: bounded placement (one row, 24 px, board area,
    reserved UI), compact pills to icon and count, then draw order nearer the camera on top. It also adds an
    incremental movement path (within 1.15× base) and the crest guard, and runs the full suites in its final round.
    sb-01 and sb-02 merge together. Mock-versus-built sheet: scratchpad `sb01_mock_vs_built.png`, regenerate after
    merge.
- 2026-10-25 14:40: tt-01 MERGED (dbb5ab804, sidecars a4aafbaa5; Godot PASS, Python OK). Lantern Shot's stack went
  from 668 px to 426 px.
  - **tt-02** (running): about 120 card panels are built in code and never read the glossary (two or three sentences,
    sub-headings inside the body, sentence-as-title with an empty body, Cleanse repeating one line four times). Director
    copy `staged/tt-02/card_panels.json` (57 rows, rules R1–R7, three glossary edits) moves every card-panel sentence
    into `data/card_panel_text.json`. A base dump of all 309 cards' stacks is in `staged/tt-02/base_panels.json`;
    the dump tool is `director_tools/card_tooltip_dump.gd`.
  - **sb-01** is on its final round (3): order discs collide with whole HUD groups (defense plates included), threat
    chips avoid placed intent popups, cache tests cover Freeze, keywords, Truesight and defenses, and a crowded-fixture
    no-overlap sweep is added.
  - Next: post tt-01 before/after to the inbox (`staged/tt-02/tt01_before_after.png`).
- 2026-10-25 12:20: OWNER FIT-AND-FINISH REQUESTS (two new lanes).
  - **tt-01** (merged 14:40): short card tooltips. 108 glossary tooltips rewritten by the director (1,696 → 965 words,
    `staged/tt-01/tooltips.json`); the Time panel dropped from cards; cut detail moves to the Grimoire. Skills and
    battlefield rules unchanged.
  - **sb-01** (running): board statuses/defenses redesigned. Inbox `status-badges` was APPROVED as variant B: Block and
    Stoneskin plates on the HP bar, and status pills under it bordered by class (can't act normally / vulnerable /
    buff / trait) with words for the no-count statuses. Mock, geometry and probe in `staged/sb-01/`.
  - Inbox: `enemy-no-action` APPROVED and closed.
- 2026-10-25 11:20: INTEGRATION GREEN at 8f512a905 (fix-16 merged 72b83b906; Godot PASS with the six fix-12 shards;
  Python's only failure, stale sidecars from rr-39 reset leftovers, was repaired in 8f512a905).
  - rr-40 (Lancer fallout) round 1 is running on Codex review findings: a Capacitor prepared-pose regression from the
    shared reset, legacy-renderer callers in the pack/export tests, an unused branch, and hover-timing misses. It runs the
    full suites itself. Then rr-37+rr-39+rr-40 merge together, rr-38 (Gaoler) launches, and the playtest refresh follows.
  - Owner approved `enemy-no-action` in the inbox.
- 2026-10-25 09:20: MERGED fix-12 + fix-14 + fix-15 (0b71b528f, sidecars 1dbcd8fda): every loss in a Tether or Mimic
  turn plays once on the step that owns it, with an ordered resolver journal proving presented equals resolved.
  - The rr-39 merge (the Lancer, with rr-37 and mq-14) turned both full suites red: pre-battle canvas,
    prepared-canvas equivalence, combat-frame perf, full-scene cutouts and crop-plan tests still reached the retired
    renderer. Integration was **reset to 1dbcd8fda**; the work stays on codex/rr-39.
  - Running: **rr-40** (the Lancer's full-suite fallout, based on codex/rr-39; runs the full suites itself) and
    **fix-16** (shard `fix_12_test`, which timed out at the runner's 180 s limit under load).
  - Integration is red only on fix-16's timeout until fix-16 merges. rr-38 (Gaoler) waits for rr-40.
  - Next once green: playtest refresh (fb-01, fix-11, the fix-12/14/15 one-loss rule, the Lancer on rig v2, el-05) and
    the Lancer review reel to the inbox.
- 2026-10-25 03:30: LANES.
  - rr-37 (Lancer) used its rounds (d614c9862). In the director's 2–4× judgment the spear clips are good, but the
    front far-arm fill still showed cloak slivers and gaps. The director painted an underlay (the approved front
    without the far arm and spear; `staged/rr-39/`). rr-39 (running, based on codex/rr-37) uses it, retires the legacy
    renderer (projectile 64 px off), makes the uncovered gate generic and fixes the proof script's re-run abort.
    rr-37 and rr-39 merge together.
  - fix-12 + fix-14 (every loss once, on its owning step; the 51-case matrix): fix-14 used its rounds (e1c9217ac).
    The final Codex review and the proof are pending; then they merge together.
  - rr-38 (Gaoler rig) launches after rr-37/rr-39 merge.
- 2026-10-25 00:25: INTEGRATION GREEN at 5b046e48a (fix-13 + mq-15 merged; Godot PASS, Python 1866 OK).
  - rr-37 is done with its three rounds (b90356c1a). Its windowed proofs are queued for the director's 2–4× judgment.
    The Codex review's two Medium leftovers (the legacy renderer still feeding the projectile origin; gate breadth) go
    to rr-39, based on codex/rr-37, which merges with it.
  - rr-38 (Gaoler rig) launches after rr-37 + rr-39 merge, reusing rr-39's generic uncovered-surface gate.
  - fix-12 is on its final round (reaction ordering).
- 2026-10-24 23:00: fix-11 MERGED (4c322e38b); integration repair 71afb7c06 (runner pins); Godot PASS, Python re-run.
  - Gaoler: mq-15 accepted at cd510ab7b. The approved mq3 paintings are already in 3/4 (only the in-game cutout is
    square), so the clay is fitted to them (front IoU 0.83) and **no repaint is needed**: rr-38 rigs the approved
    paintings as they are. Brief `briefs/rr-38.md` and motion `staged/rr-38` are written; it launches after mq-15
    merges.
  - fix-13 (running) must merge before mq-15 and rr-37: the mq-11 preservation test rejects any new figure's delivery.
  - fix-12 (running): Tether arrival damage pops twice (pre-existing).
  - rr-37 is on its final round (hidden fills behind the far arm and spear, uncovered-surface gate).
  - mq-14 (in rr-37) and mq-15 both change `blender/cloth.py`, `compile_recipe.py` and `contract.py`; whichever merges
    second needs a careful reconcile and a regeneration check for both figures.
- 2026-10-24 21:00: INTEGRATION GREEN at a5394dac9 (Godot PASS, Python PASS).
  - MERGED fb-01 (7c817a86a): enemies say why they didn't act, with a readable 0.8 s hold. Owner request.
  - MERGED fix-08 (63be03c6c): the blocked-input explanation counts from its first drawn frame.
  - Integration repair a5394dac9: the program runner test pins fb-01's appended program.
  - rr-37 (Lancer rig) round 2 is committed (544f09bd4); its windowed proofs are queued. One fix round is left.
  - mq-15 (Gaoler re-pose maquette) is ready. Brief `briefs/mq-15.md`; it launches with the bridge.
  - Follow-ups: fb-01's callout hold uses the wall clock (`intent_callouts.gd:180`), so give it fix-08-style
    first-drawn-frame timing; the tether's separate "Cancelled" label.
- 2026-10-24 16:35: INTEGRATION GREEN at a2aaedb51 (el-05 merged; Godot PASS, Python 1803 OK).
  - fb-01 round 2 is done (turn captions name Frozen/Petrified/Shocked); its director proof is queued.
  - rr-37 (Lancer rig) is running on its branch. The branch carries:
    - mq-14, signed off;
    - the Lancer r5 paintings, director-approved, gate PASS. The rear is a fresh paint-over scaled to the front's
      hood-to-sole height, because mq-14's native rear projects 17% shorter and each view registers separately;
    - staged/rr-37 motion.
  - Inbox `rule-ghosts` is open, with one question: a brighter outline on every landing ghost?
- 2026-10-24 (evening): LANES.
  - mq-14 (Lancer maquette) is running, with the bridge on.
  - fb-01 is running: enemy no-action reasons replace "Cancelled", with a readable 0.8 s hold. Owner request.
  - el-05 is director-built at 66769a3a8, and its Codex review is running:
    - Upheaval throw ghosts and Shadowstep Blink shades, via forecast `emergences` that keep hidden movers private;
    - beats in the card landing strip.
    - Inbox `rule-ghosts` asks whether every landing ghost should get a brighter outline for dark creatures.
  - Next: the Gaoler re-pose after the bridge frees, and fix-08.
- 2026-10-24 18:40: IN FLIGHT WHILE THE OWNER'S PLAYTEST IS PENDING.
  - The owner wants no new playtest build yet. Refresh once more substantive changes accumulate.
  - mq-14 is running (Lancer maquette on the current builder; the bridge is on).
  - Next lanes:
    - move ghosts for Shadowstep's Blink and Upheaval's throw, and beats in the turn-order strip (director design,
      inbox mockup first);
    - the Gaoler re-pose, after mq-14 frees the bridge;
    - fix-08.
- 2026-10-24 18:25: OWNER VERDICTS.
  - gloam-rig-v2 APPROVED: "Good enough for now." It goes on the revisit list with the Mirror's feet and fists.
  - herald-walk-fix APPROVED.
  - Both inbox items are done and their threads resolved. playtest-12 is still open, and publishing to master still
    waits on the owner's go-ahead.
- 2026-10-24 12:30: INTEGRATION GREEN at f9ee96e87 (Godot suite at the merge; Python 1803 tests OK after the repair).
  - MERGED rr-36 (25a5bfe0e), carrying mq-13 and rr-35: the Gloam Stalker rebuilt.
  - Integration repair f9ee96e87: rr-36's tests read a committed 13-pose fixture, bound to the full-samples hash, not
    the gitignored proof log.
  - The rr-35 and rr-36 worktrees are removed; their branches are kept.
  - Waiting on the owner:
    - `gloam-rig-v2`, `playtest-12` and `herald-walk-fix` in the inbox;
    - the go-ahead to publish to master. Playtest 12 is pinned at 010a64da9, before the Gloam rebuild.
  - Next: follow-ups (Shadowstep/Upheaval move ghosts, beats in the landing strip, Lancer rr-06, fix-08). Last Light
    and the Hoarder stay held until the owner has played the Warband and the Snare.
- 2026-10-24 10:45: GLOAM POSTED. Inbox item `gloam-rig-v2` is open: r3 paintings lineup plus the 2x review clip.
  - rr-36 fixed D1-D5 at their ownership causes. Director windowed proofs a7a894dbb: all stages and the D1-D5 native
    checks PASS. The director's 2x judgment found every defect gone.
  - rr-36 round 1 (85f33073d) added the D3 ownership guard, from the Codex review.
  - Round 2 (running) repins the accepted rests to the a7a894dbb rebake. The stale pin is the only focused failure.
  - Then: re-review, then merge rr-36 into integration with full suites. That merge carries mq-13 and rr-35.
- 2026-10-24 (late): rr-36 RUNNING (Gloam native defects). rr-35 is complete at 8b4f094ae: three fix rounds and Codex
  review fixes; every gate and windowed stage PASS with native=True.
  - The director's 2x review of the native frames found five defects the gates missed:
    - a dark wedge at the front near heel in `move`;
    - the front near shin breaking up (move, slash, ambush);
    - a dark band across the rear near thigh at contact;
    - a seam line across the cloak at the wind-ups;
    - a fraying hem.
  - rr-36 (fresh session, based on `codex/rr-35`) fixes them with per-defect native checks. Brief: `briefs/rr-36.md` on
    that branch; evidence in `staged/rr-36/evidence/`.
  - The e4b60147b native captures are copied, gitignored, to `rr35/proof/e4b60147b_native/` in the rr-36 worktree.
  - Not posted to the owner yet. mq-13 and rr-35 ride in rr-36's branch.
- 2026-10-24 07:10: rr-35 RUNNING (Gloam re-rig). Its branch carries the inputs:
  - mq-13, merged into the rr-35 branch rather than integration, because `tests/test_rr33_cutout.py` binds the old
    delivery. The Codex re-review of b45655345 found one medium issue (a test path); the director fixed it in
    c79ebe1ff, as the reviewer proposed.
  - The r3 paintings, committed as director data in f1fae7475 and director-approved; the identity gate passes front
    and rear:
    - front: the v3 image-model edit, scaled 0.96 to share the rear's maquette scale and palette-matched to the
      approved mq-12 front;
    - rear: palette-matched to the r3 front;
    - heights 198/195; lateral axis 8.4 degrees from the shoulders; sheet `jobs/gloam_stalker/sheet_pair_mq13.png`.
  - Next: review rr-35, run the windowed proofs, post the Gloam clips to the inbox, then merge with full suites.
- 2026-10-24 06:20: GLOAM REBUILD.
  - mq-13 round 3 committed (b45655345): saved geometry recomputed and bound into the resume receipts; unused config
    removed. The final Codex re-review is running. The bridge is stopped.
  - Front repaint (image job `mq13-gloam-front-r3`):
    - v1 has the right crouch, hunch and flush plates. Registered to the maquette (scale 0.94), its IoU is 0.77; the
      approved mq-12 was 0.79.
    - The near shin sits ~22 native px right of the maquette's near leg. The rig would split it between the leg and the
      blade.
    - v2 was a code pixel edit that left the foot floating; it is rejected. v3 is a real image edit.
  - The rear kit is staged in the scratchpad and waits for the approved front as its identity reference.
  - rr-35 brief: `briefs/rr-35.md`. Motion data: `staged/rr-35/motion_tracks.json`. Only the slash changed: a leading
    blade (`hand_far`) cleave of 18 px lift and 20 px forward, with a rear lift of 14 through `view_keys`. It launches
    after both paintings pass the gate.
- 2026-10-24 04:55: INTEGRATION GREEN at 010a64da9. Both full suites pass with el-01/02/04, fix-09/10, rr-32/33 and
  rr-34 merged.
  - PLAYTEST 12 is pinned at `../Labyrinth.worktrees/peer-benchmark-playtest-12` (detached at 010a64da9, imported).
    Never merge into it. Inbox `playtest-12` carries three launch commands (start / warband / snare).
  - Inbox `herald-walk-fix` posts the loincloth clip. playtest-11 is marked superseded.
  - Publish to master still needs the owner's go-ahead after they play.
  - Next: mq-13 (in re-review), then the Gloam repaint and rr-35.
- 2026-10-24 01:50: OWNER VERDICTS.
  - rule-views APPROVED, red threat marking included.
  - herald-gloam-rigs NEEDS CHANGES. The owner first clicked approve by mistake and corrected it in chat.
    - Herald: the far leg draws over the loincloth through the front walk. rr-34 (running) puts the tabard above
      `leg_far`.
    - Gloam: "quite broken". Floating shoulder pieces, wonky rear stance and perspective, a slash that barely moves,
      and the blade behind the body in the front view.
  - Gloam rebuild plan:
    1. mq-13 (running, bridge on): maquette r3, a stalking crouch (ankles ~220 px apart, knees forward), a real hunch
       (head to (440, 330)), carapace plates at 60% and flush.
    2. The director repaints front and rear from the r3 clays (identity gate).
    3. rr-35 re-rigs the Gloam: carapace owned by the torso; `hand_near` (blade) above the torso and capes in the front
       view (it's z 5 now, under the torso's 14); a new slash with a real wind-up and full sweep, authored within the
       measured joint budget; the other clips re-keyed for the new pose.
- 2026-10-24 00:50: MERGED fix-09 (655995e9e) and el-04 (82ef77706, director-built, Codex SIGNOFF f217c1ac6):
  - The battlefield rule panel above the objective (icon, name, sentence, beats left, direction arrow) replaces the
    wind chip.
  - Beat tokens show in the turn-order rail; previously a beat rendered as a second hero portrait.
  - The next beat's tiles show as threats at rest when the beat is due.
  - fix-10 is running on el-02 fallout in suites el-02 never ran (Weaver continuity, threats-at-rest icons, destruction
    preview, Warband tether_beam, and the Thrall/Weaver cast clips not playing).
  - Then both full suites and the owner's playable build. The design is in `element_rules/el-04_design.md` (as built).
- 2026-10-23 23:40: MERGED rr-32 (Herald, d06ed27b0), rr-33 (Gloam, 0027e90ee; registry/shadow conflicts union-merged
  by the director) and el-02 (434629f53). All ROSTER CUTOUTS ARE DONE except the Lancer (rr-06 later).
  - Suites at 0027e90ee found rig fallout, now repaired in 33bc14426: the en02 registration check (Herald/Gloam are
    cutouts) and the Gaoler records re-certified to rr-32's backward-compatible maquette tool (pixels identical).
  - Two more rig regressions are in fix-09 (running): SFX harness coverage of cutout contact cues, and the perf test's
    need for a live directional still (none remain).
  - el-02 stall rows were bot blindness (Codex replay: each winnable with legal play).
  - Next: fix-09 merge, then BOTH FULL SUITES, then el-04 (director-built views; design `element_rules/el-04_design.md`),
    then the owner's playable build. Herald + Gloam clips are saved for the inbox
    (`output/peer-benchmark-2026-10-12/rigs-2026-10-23/`).
- 2026-10-23 22:00: INTEGRATION GREEN at fb0350327 (el-01 + three director repair commits; both full suites pass).
  - el-02 launched from fb0350327 (brief `briefs/el-02.md`). el-04 (director-built panel, beat token, previews) is
    designed after el-02 lands, since it adopts el-02's icon keys.
  - rr-32 (Herald) round 2 committed f8492ffa3: native gates 0 errors, horn whole through the fist at the −30° death
    pose; Codex review running.
  - rr-33 (Gloam) review: CHANGES REQUESTED (two small items), fixed by the director in 0d63c50d6. Windowed
    re-proof running for fresh receipts, then Codex re-review.
- 2026-10-23 20:55: el-01 MERGED (abb0b8a78), plus integration repairs on codex/el-01:
  - The Gale Herald is Anchored by its data flag (`"anchored": true`, mirrored in staged wave_e1); no type literal,
    no wielder immunity. The Mirror is pushed; immobility alone holds the Capacitor.
  - The encounter golden was re-recorded for seeds 1 and 421; a structured diff showed changes only in their Gale
    Herald rooms (Gust cadence).
  - The battlefield_rules_probe `--check-only` contract is appended last in the program manifest; approved glossary
    copy names Gust.
  - Third suite run in progress. Then launch el-02 (brief `briefs/el-02.md`; design.md drops `lasting`, retires Ice
    Pillar everywhere, and states Anchored-only protection).
  Roster:
  - rr-32 (Herald) round 2 back: native seam/horn repairs, headless gates PASS. Windowed re-proof queued behind rr-33.
  - rr-33 (Gloam) round 2 back: all gates PASS; windowed proofs running.
- 2026-10-23 22:40: element-rules APPROVED (revision 3). Binding design `element_rules/design.md`.
  Units:
  - el-01 running: framework, the six resolvers, Wind becomes Gust.
  - el-02 next: Warband/Snare/ordinary-enemy retrofit, keyword retirement, measurement.
  - el-04 director: the panel, turn-clock token, previews and 5 new rule icons; Claude builds, Codex reviews.
  - Then a playable build for the owner.
  Roster:
  - mq-12 round 2 running (Codex review: test_mq09_forms inventory, garment-gate mutations, manifest receipts).
  - Herald/Gloam fronts repainted as edits of r1 (`jobs/<id>/mq12_front`, gate PASS; Gloam art_scale 0.98). Rears
    are running as image jobs mq12-{herald,gloam}-rear-r2.
- 2026-10-23 21:15: INTEGRATION GREEN at 536fe0014 with wind-01 (owner-approved wind; Codex SIGNOFF ff209110b).
  - Owner design principle (2026-10-23): one core rule per element, remixed across every special fight, no new
    keywords. v1 proposal (element_rules_v1.html, inbox element-rules) was too vague per the owner ("fire ground is a
    primitive, not a rule"); v2 defines each element as a board-wide beat like Wind. Boss/Guardian/clarity items folded in.
  - Publish to master: wind-v3 approved; snare-pressures-play still open (two pressures may change under the element
    rules). Ask the owner before pushing.
  - Next: mq-12 (Herald + Gloam shoulders) then repaint + rigs; Lancer rr-06 resume after.
- 2026-10-23 19:10: wind-v3 OWNER APPROVED. wind-01 tests at 111657c0e; Codex review running; then merge, full suites,
  and ask the owner to publish (warband-markers-v2 is superseded by wind-v3).
  - Roster gap the owner asked about: wave 1 is 9/11 done and on master (Tick, Grub, Seer v2, Thrall v3, Capacitor,
    Mirror, Weaver, Mimic v2, Mortar v2). Gale Herald + Gloam Stalker (rr-08, parked in the old rig style) and the
    Frostglass Lancer (rr-06, painting approved 10-17) never resumed. Next after wind-01: fresh humanoid-rig-v2 units
    for the Herald + Gloam, then the Lancer (worktrees rr-06/rr-08 still hold the old-style checkpoints).
- 2026-10-23 18:45: warband-markers-v2 came back NEEDS CHANGES (wind source/direction unclear; decorative gusts blow the
  wrong way). wind-01 (director-built, worktree `../Labyrinth.worktrees/wind-01`, WIP c648ab6d2) is posted as inbox
  `wind-v3`. Publish to master stays held until the owner approves it.
  - On approval: update the tests that pin the old streak constants and chip titles (en02_enemies_suite,
    wbv_markers_suite, warband_orders_probe/mutations, snare_probe, snare_ui_test) and any air-room ambient/floor
    fixtures; focused suites; Codex review; merge; full suites; then ask to publish.
  - Director tools: `director_tools/wind01_*` on codex/wind-01 (capture probe, gameplay clip probes, clip.py, collect.sh).
- 2026-10-23 12:15: INTEGRATION at 60de13b9a.
  - Suites: Godot PASS at e3e32dbf1; Python PASS after the provenance repair.
  - Everything queued is merged. Codex queue is empty except fix-08 (low, not started).
  - Publish (full suites at the exact HEAD, then authorize-publish, then push) waits on owner verdicts:
    warband-markers-v2, snare-pressures-play.
- 2026-10-23 11:10: INTEGRATION GREEN at ea5267ab4 with perf-04 (hover back near October speed).
  - Publish waits on owner verdicts: warband-markers-v2, snare-pressures-play.
  - Remaining queue: meas-03 merge (Skybolt measurement tooling, needs a short review); fix-08 (blocked prompt
    stall, low).
- 2026-10-23 08:20: INTEGRATION GREEN at f8b6924d1 with shader-01 (Steam builds now persist their shader cache).
  Publish still needs owner verdicts on warband-markers-v2 and snare-pressures-play. Next: perf-04 (hover 2x slower
  than 10-08), fix-08 (blocked prompt stall, low).
- 2026-10-23 06:00: INTEGRATION GREEN at e732a5880 (Godot PASS, Python PASS).
  - Contents since master d96eadf4f: meas-02, wbv-01 (markers v2), spx-06 (Snare pressures), fix-06, qa-15, perf-02,
    fix-07 (Petrify, owner-approved), bal-01 (Skybolt, owner-approved), perf-03, det-04.
  - Publish needs owner verdicts on warband-markers-v2 and snare-pressures-play.
  - Removed merged worktrees.
  - Next unblocked: shader-01 (export the macOS build, reproduce the cache-save failure, warm combat effects);
    perf-04 (hover 2x slower than 10-08); fix-08 (blocked prompt stall); meas-03 merge after a light review.
- 2026-10-23 04:30: perf-03 accepted 99eafc833.
  - Idle headless min-of-3: trap knock 18.5-19.0 ms (10-08: 20); hover 7.7/9.8/11.2 ms (10-08 ordinary 3.4, still
    2x; follow-up perf-04).
  - Owner's 150 ms hitch = a Codex review job starting + first-use shader compiles in the exported build (its cache
    never saves): shader-01 next.
  - bal-01 Skybolt Exhaust + 8 merged.
  - det-04 in final review; then batch-merge perf-03 + det-04 (+ meas-03) and run clean full suites before asking the
    owner to publish.
- 2026-10-23 early: perf-03 r1 committed 6e23ba348 (WIP; budgets unmet; measured under meas-03 load, so noisy).
  Findings:
  - The owner's exact hitch (Hobnail Drive kick, lightning trap 8, collision 2, death) was ~35 ms on 10-08 with
    the same causes (checkpoint persist, GUI dispatch, board layout, ~98 UI nodes): NOT a regression.
  - Ordinary board hover regressed: 6 ms on 10-08 vs 12 ms now (HUD unit build, torch motes, preview overlays).
  Next:
  - When meas-03 finishes: director runs the harness on oct08 / base 69444f134 / perf-03 on an idle machine
    (3 runs each) plus native.
  - Keep only the perf-03 fixes that measurably help. The background checkpoint/analytics writes need a durability
    review before they can land.
  - oct08 checkout: /private/tmp/labyrinth_codex/oct08-baseline (remove after).
  - Ready to merge: fix-06, qa-15, perf-02, fix-07, det-03 (held until timing work is done).
- 2026-10-22 19:10: QUEUE (in order, none started while the owner plays):
  1. perf-03 controlled native measurement;
  2. shader-01;
  3. det-03 feedback_2;
  4. fix-07 feedback_2 (Funeral Bell double Block, spec, shared wording);
  5. perf-02 idle timing proof + native check;
  6. batch merge fix-06/qa-15/perf-02/det-03/fix-07;
  7. bal-01: evaluate Skybolt.
     - Owner (2026-10-22): "infinite range shock seems pretty bonkers... may need a drawback if we want that upside."
     - Heuristic: 6.38, the top score in the whole 126-card reward pool; legendary median 4.58.
     - Director to measure it (sweep/bot) and propose options in the inbox before any change.
- 2026-10-22 19:00: owner hit a ~150 ms hitch at 18:49:45 (Pale Spark knockback, enemy onto a lightning trap, death,
  collision; air combat 9). Evidence:
  - telemetry performance-2026-10-22.jsonl: >50 ms frames 1.9/min in combat vs 0.6/min on 10-08; the max of 150 ms
    also occurred on 10-08;
  - the director's fix-07 Codex review started 18:49:14 (repo worktree copy + Godot);
  - the Steam build's shader cache never saves (37 shader_rd _save_to_cache errors this session; cache untouched
    since Jul 7), and the log shows a shader compile at 18:49.
  Next, when the owner stops playing:
  - perf-03: controlled native measurement of master vs the 10-08 checkpoint (knock-into-trap and full-combat
    scenarios), with root causes for any regression;
  - shader-01: why the shader cache fails to save, plus a load-time warmup of combat effects.
  No Codex runs or reviews while the owner plays.
- 2026-10-22 18:30: fix-06 + qa-15 signed off (batch merge pending). perf-02 needs only the director's idle-machine
  benchmark + native frame check (a run during the owner's Steam play session read 5x slow: not valid). det-03
  feedback_2 staged. HOLD heavy jobs (suites, benchmarks, busy-loop proofs, windowed captures) while the owner plays.
- 2026-10-22: owner: start queued small fixes/polish while they review; do NOT start Last Light or the Hoarder until
  they have played the Warband and Snare. Launched fix-06, perf-02, qa-15, det-03 from 78b8f557b. Removed merged
  worktrees cap-02, map-03, meas-02, rr-28, spx-01..06 (branches kept). Capture speed (cap-01/02) was already done.
- Latest (system clock 2026-10-21 23:40): integration 20c6ae2ad green (adds the Snare clip probe). Inbox item
  `snare-pressures-play` posted (six tier-2 clips, 100-HP passive hero; shadow hit hardest, 100 to 23). Next publish
  waits on owner verdicts: warband-markers-v2 and snare-pressures-play; then suites at HEAD, authorize-publish, push.
  Also pending: playtest-11, enc-clarity/dragons/guardians (flag Noctyrax 0% / Zekarion 14% with enc-dragons).
- 2026-10-22 03:30: spx-06 MERGED f89e8d60c; integration green. Integration now = master d96eadf4f + meas-02 +
  wbv-01 (markers v2) + spx-06 (Snare pressures). Next publish needs owner verdicts: warband-markers-v2 and the Snare
  pressure clips (being recorded). Codex queue empty.
- 2026-10-22 00:40: integration de6f5c0b3 green (meas-02 3de58366e, wbv-01 44bfcdfc7 + manifest repair). spx-06
  signed off (3113bb689 + 7b33bd170); merged integration into it at 6afd4668d (ghosts follow the prepared Snare
  headwind projection; boundary test rewritten); native Snare proof 6/6; short Codex review of the resolution running,
  then merge. Owner verdicts pending: warband-markers-v2, playtest-11, enc-clarity/dragons/guardians.
- 2026-10-21 23:40: **Checkpoint published: origin/master = d96eadf4f** (decisions). Playtest 11 = frozen
  ../peer-benchmark-playtest-11 at d96eadf4f. In flight: spx-06 fix round 1 (feedback/spx-06_feedback_1.md), meas-02
  (Guardian/dragon measurement), wbv-01 (markers v2 merged with integration at 8712bcba4; needs Codex review + suites).
- 2026-10-21 18:30:
  - spx-07 MERGED b5e3b5cbc (Codex SIGNOFF f3f7d8458 after 2 fix rounds; native sweep max 20.1/17.5 ms Warband,
    34.5 ms ordinary; targeting floor 40 ms = follow-up perf-02). Warband inspection fixture pinned to revision-6 maps
    (df876a12c). Integration Godot 479 s PASS, Python OK.
  - Owner: map-built APPROVED ("Really nice."). warband-markers NEEDS CHANGES (rings/dashes amateurish) -> redone in
    wbv-01 2a5eedc77 (wind landing ghosts, Dive flight swoosh, crackling Tether/chain arcs); posted `warband-markers-v2`.
  - spx-06 (Snare pressures) LAUNCHED from 7ff2f5ae5. wbv-01 merges after its verdict (conflicts expected in
    wind_view/tether_view with spx-06; director resolves).
- 2026-10-21 13:10:
  - map-03: Codex review of 4687a81ab = CHANGES REQUESTED (room drag committed travel; v7 exhaustion fell back to the
    straight 5-lane layout; weak v5/v6 and panel guards; typed literals). Fixed by the director in 24d083bab: rooms
    forward wheel/drags and a drag never travels; stored per-section v7 fallback `data/section_map_v7_fallbacks.json`
    (+ mystery hidden types; tools/section_map_v7_fallbacks.gd); base digests for revisions 5/6; real-pointer and
    lifecycle tests; the walk completes on its timer. Round 2 (4250cb52e): keys/pads in a drag's release frame still
    travel; the release-fallback regression validates the v7 web. Codex SIGNOFF 4250cb52e. MERGED 0c2726d67; the
    Graftwright integration test now keeps its revision-6 map (4b2fb012a). Integration Godot 561 s PASS, Python OK.
  - spx-05 MERGED (0ce68a9aa). spx-07 r1 committed 31380ca38 (r0 a892292ab): wind lock + spread spawns + side rule done;
    native director probe sweep max frame ordinary 32.7 / air T2 22.1 / lightning T3 21.2 ms (integration 71/72/64).
    Card targeting worst 23-38 ms (budget 20) accepted as FOLLOW-UP perf-02 (first visit to each target simulates the
    enemy response; candidates: worker-thread simulation or cheaper PASS preview). Codex code review running; spx-06
    launches after spx-07 merges.
  - Warband marker redesign, director-implemented in `../Labyrinth.worktrees/wbv-01` (uncommitted prototype): feathered
    Command glow + rim (no outline), gilt crowned-skull crest on the captain's bar (LEADER box gone; floor beacon off in
    Warband fights), wind streaks instead of per-tile chevrons, chevrons + ghost ring slide previews. Posted as inbox
    `warband-markers`; build after the verdict and after spx-07 merges (both touch wind_view/combat_board_view).
- 2026-10-21 11:40:
  - map-03 (Claude-implemented at the owner's request): revision 7 web generator + scrolling map + inked trails +
    lantern walk built in `../Labyrinth.worktrees/map-03` (wip 997005302); native captures and clip posted as inbox
    item `map-built`; full suites running; then Codex code review, then merge.
  - spx-05 round 3 running (Vaulting Sigil crossing sealed thresholds; two surviving mutants).
  - Warband rework queued from the owner's warband-built verdict (see feedback.md): perf, wind lock, marker redesign
    (director mockup first), spread spawns, then a new playtest build.
- 2026-10-21 10:15 — OPEN OWNER ASK (dropped, now re-tracked): map branching. Playtest 9 note 1 ("more interesting
  branching, take inspiration from Slay the Spire") got map-02 (revision 5, merged dd4e67d43 2026-10-17, on master since
  the 2026-10-19 checkpoint). map-02 was accepted on variety *between* maps (fallback rate, distinct topologies) and was
  never shown to the owner as an inbox item. Owner 2026-10-21: still "too much like a few straight lines with a couple
  of branches here and there"; not like Slay the Spire or Inscryption. Next: measure choice density on revision 6
  maps (forks per route, longest no-choice run, out-degree, lane changes), design revision 7 with a mockup on the real
  map art, post it to the inbox, then brief map-03 (generator + layout; disjoint from the spx combat files).
- 2026-10-21 07:45 (encounter specials + Mortar):
  - MERGED on integration: spx-01 round 3 (ee46bc2fc), spx-04 Warband orders (167958603), the Slag Mortar v2 rig as
    one squashed commit (7b7553afb; rr-30 + rr-31, Codex SIGNOFF e9aadfc32, director visual acceptance with minor
    joint specks on the revisit list), the re-measured revision-6 bot baseline (d617cf371) and the density-manifest fix
    (8df5ff702). Godot suite PASS at d617cf371; the only Python failure (density manifest) is fixed and its tests pass.
  - Inbox: mortar-rig-v2 posted (open). warband-built, enc-clarity, enc-dragons, enc-guardians open.
  - Running: spx-05 round 1 (`feedback/spx-05_feedback_1.md`: seal tint, chip plate and placement, sealed medallion,
    Seal rules text, legend rule, turn-1 escape allowed, two extra probe frames).
  - Next: judge spx-05 r1 natively, Codex review, merge; then launch spx-06 (`briefs/spx-06.md`, Snare pressures);
    then brief Last Light and the Ember Hoarder.
  - Removed worktrees: rr-30, rr-31, mq-11 (branches kept).
- 2026-10-20 19:00:
  - rr-29 MERGED 007f685c0 (+ sidecars 7e3122289, import path fix). All windowed stages PASS on feffbfb06 (production
    rerun after a hidden-window stall), director visual judgment passed, Codex SIGNOFF feffbfb06, both full suites
    green. Inbox item mimic-rig-v2 posted (awaiting owner). Low, not blocking: a faint 1 px chest seam during actions,
    visible only at 3x.
  - rr-30 → rr-31: rr-31 imported the director motion (arms low and close). Round 0's image gates were over-strict;
    round 1 calibrated them on approved rigs (Seer, Thrall, Mirror, Mimic) and found they can't separate the torn
    brace20 and rear death78 frames from approved motion. Director decision: image gates stay as diagnostics only;
    acceptance is the director's visual judgment of the native clips. Round 1 committed e6eea62a8; its windowed
    stages are running. Then: judge, re-review, merge, inbox clip. Remove the rr-30 and rr-31 worktrees after landing.
- 2026-10-20 15:40:
  - mq-11 merged (56de97dfb). Codex SIGNOFF a3fc15b69, native acceptance director_06, integration green at 300f8277b.
  - rr-29 (Mimic re-rig) and rr-30 (Mortar re-rig) launched from 7adad7e92.
  - Their new maquette deliveries (capture without the .blend or determinism) were copied untracked into each
    worktree's `tests/mq11_proof/director_06/<figure>/capture/`. The source copy stays in the mq-11 worktree until both
    land.
  - Backlog:
    - find the suite test that rewrites `experiments/cutouts/briar_weaver/mq9/proof/samples.json` (seen twice;
      restored each time);
    - mq-11 Low: an off-mask crack regression;
    - sfx-05 Low: three missing regression cases.
- 2026-10-20 14:25 (Mimic/Mortar owner fixes):
  - **mq-11.** The director authored the design data:
    - the Mimic's 16-tuft mop, measured from the built skull (generator `staged/mq11/mimic_hair.py`);
    - the Mortar's belt and flaps.
  - Brief/gate corrections, all director decisions:
    - the flap length is 1.25 thigh;
    - the centre line is each flap's own attachment, judged on the median of the central rows, ±12 px at 1024.
  - Native acceptance passed for both (director_04, 2e97131de). The Codex review requested changes: 3 Medium, 2 Low,
    4 surviving mutations. Fix round 2 is running (feedback_2). Then the director reruns `workflow build` natively and
    merges.
  - **Paint-overs approved by the director:**
    - Mimic hair, front and rear r2;
    - Mortar belt and loincloth, front and rear, composited below y 560.
    - Staged in `staged/mq11/paint/`; inbox item `mq11-paint` is open.
  - **Next:** launch rr-29 (Mimic re-rig) and rr-30 (Mortar re-rig) after mq-11 merges. Briefs and motion data are
    committed in 6868f0862.
- 2026-10-20 afternoon:
  - Merged int-05 (6a188d45d) and sfx-05 (672b55f64; Codex SIGNOFF 2b4095104; Empower cues onset-trimmed by the
    director, blocked-health card.invalid). Godot PASS.
  - Python had 1 error: test_empower_sfx imported sound-lab deps at module level. It now skips its two audio tests
    without the venv, like test_sfx_lab.
  - The full suite rewrote the tracked `experiments/cutouts/briar_weaver/mq9/proof/samples.json` (runtime hashes). It
    was restored. Backlog: find the test with this side effect.
  - Capacitor windowed rr17_proof PASS on ee03daf93 (cap-02 crop + rr-28 scoped preservation); cap-check worktree
    removed.
  - Inbox:
    - empower-sound-built is open (clip with sound).
    - Encounter redesign: proposal https://claude.ai/artifact/D6P63LRV4ccFizPGmMqzRX. enc-specials APPROVED
      2026-10-21. MERGED on integration: spx-02 a20648afc (map placement, emblems, legend, tooltips, rewards), spx-03
      8b53574d4 (Warband combat; standard fights Defeat All in revision 6+), integration repair fd9adb42c (the
      escape-transaction test pinned to revision 5), and spx-01 011dd1467 (analytics context, sweep, bot v2 as a
      relative benchmark; suites running). Running: spx-04 (the six Warband orders). Pinned playtest worktree
      `../Labyrinth.worktrees/peer-benchmark-playtest-spx` at fd9adb42c (detached) for the owner's Warband inbox item.
      Next: Umbral Snare, Last Light, Hoarder briefs. enc-clarity, enc-dragons and enc-guardians await verdicts.
      See `encounter_redesign/README.md`.
    - Inbox cards now support an optional `link`.
  - sfx-05 Low (backlog): three missing regression cases (rejected-toggle silence, available() health guard,
    can_attempt() non-health guards).
  - mq-11 running (Blender bridge bp49pzgph).
- Merged on integration since playtest 10: map-02, cbt-01, boon-01, fix-05, flow-01, qa-07, qa-08, bug-01, mq-04,
  rr-05, det-01, rr-07, mq-05 (d2560b9c9), rr-12 (9fdb6462f), mq-06 (78d87f474), mq-07 (663a8e84e). Owner approved:
  section transition, Bloomer rr-05 clip, roster plan, Lancer look, Burrow Grub and Ember Tick rigs (rr-12).
- **Humanoid rig v2** (owner rejected the rr-07 Seer and Thrall rigs) — binding spec
  `spec/peer_benchmark/humanoid_cutout_rig.md`, decisions 2026-10-18.
- Running / state:
  - Seer v2 (rr-10 + rr-13) MERGED 66d07be81: owner approved; Codex SIGNOFF 3c6363908; integration Godot PASS, Python
    974 OK. rr-10/rr-13 worktrees removed.
  - rr-14 (humanoid foundations: foot IK, case-driven anatomy, Thrall-shaped fixture) running.
  - det-02 and pace-01 merged; integration green at 4e874c34f (Godot PASS, Python 978 OK). The rr-05 owner-proof
    script and det-02's helper were fixed after the first full-suite run caught them.
  - rr-14 merged e08e4e296; purge-01 merged 3d8b22d4f (integration green: Godot PASS, Python 999 OK). Thrall v2:
    rr-11 + rr-15 committed 4f287165b: windowed native gates 0 errors, sheets/idle/production/review PASS; reach gate
    reports overreach (death flings, front jab claw) without failing. Codex review of the range running. Inbox:
    thrall-rig-v2, purge-polish, enemy-pacing-2 open (pace-02/purge-03 merged and published).
  - 2026-10-18 cleanup: removed 15 merged worktrees (93 GB). Kept: anim-01/02 (shelved, unmerged), rr-06/rr-08 (parked),
    qa-05 (merged, but 2 uncommitted edits: scripts/asset_loader.gd, tests/helpers/program_sub_suites.gd; inspect
    before removing), peer-benchmark-playtest-10 (frozen playtest), gear-devlog-capture.
  - Parked: rr-06 (2ceaf8ed4) and rr-08 (bb84ed68e), old rig style; convert to v2 later.
- Usage discipline (memory `codex-usage-discipline`): at most 3 fix rounds per session, then a fresh unit; workers run
  focused tests in fix rounds; full suites only at merge.
- Director reminder: run `parallel_task.py contract … && preflight` in every new worktree before launch.
  Workers can't write Git metadata.
- **Checkpoint published 2026-10-19: origin/master = 209cbc67c** (decisions). Next checkpoint on the owner's word.
- Resumed 2026-10-20 11:52: int-05, sfx-05 and mq-11 launched from ee03daf93 (Blender bridge running for mq-11); Capacitor windowed re-check running in throwaway worktree cap-check. Earlier pause note kept below for its checklist.
- (Paused 2026-10-20 10:24 for the owner's video meeting.)
  Resume checklist, in order:
  1. Launch int-05 (scope test_rr14_seer_identity to rr-14's range + re-pinned-guard sweep; the only red test on
     integration), sfx-05 (Empower charge/un-charge cues: A at -24 LUFS, un-charge -30), and mq-11 (Mimic hero-style
     hair; Mortar loincloth on the hip line). mq-11 needs the Blender bridge for its worktree. Briefs committed 7ad4fd7e4.
     Steps per unit: CU new, reset to integration HEAD, copy brief to .codex/tasks/briefs, contract + preflight, launch,
     re-arm spec/peer_benchmark/director_tools/watch_loop2.sh (scratchpad copy) as a tracked background job.
  2. Windowed Capacitor re-run on integration (rr17_proof.sh; checks cap-02's crop + rr-28's scoped preservation
     together) in a throwaway worktree.
  3. After mq-11: director paint-overs (Mimic head only; Mortar loincloth only) through the identity gate, then rig
     units: Mimic (re-cut head, arm swing from the shoulder opposite the legs with forearm lag, front-view hands crossing
     the chest draw in front) and Mortar (re-cut loincloth, rigid head and bracers, covered elbow/shoulder joints, a
     stretch limit added to the gates).
  Integration HEAD after the pause notes: e03e2ab90+ (rr-28 + cap-02 merged; post-merge repairs 84406a34a).
- Next (in order), 2026-10-19 night:
  1. **Integration green at e151882cd** (Godot PASS, Python OK): rr-23, rr-25, rr-24, rr-21, ui-03, rr-26 and int-03
     (integration repair: ui-03 targeting regressions fixed in product code, fixtures derived from canonical
     declarations, Mortar digests, density manifest, unit-scoped preservation pins, Empower glossary at 19 words).
  2. **Integration green at 1fd63e03c** (Godot PASS, Python 1458 OK): rr-27, int-04 and cap-01 merged. Proof captures
     are now cropped to the actor and saved as lossless WebP (Seer production 30 min/4 GB -> 4.3 min/0.58 GB).
     Native re-check under the canonical gate (fast captures, throwaway worktree native-check): Mirror, Weaver,
     Mortar, Thrall, Capacitor native PASS; Seer 31 joint tears; Mimic 73 joint tears (rear death 49, bolt 18, move/
     mirror/hit 2 each); Capacitor's proof-script shadow-preservation pins other figures (stale baseline).
     rr-28: tears closed (Seer 25 / Mimic 36 own-piece texels); director windowed native gates PASS 0 errors for both;
     Capacitor shadow preservation scoped (PASS). Fix round 1 running (recipe clips validated against tear evidence).
     Mimic and Capacitor production captures hit a cap-01 bug (fixed crop planned from the first canvas; the actor's
     canvas moves within a run) -> cap-02 running. Evidence: /private/tmp/labyrinth_codex/rr28_evidence (delete after).
  3. Inbox open: empower-built, mortar-rig, weaver-rig, mimic-rig. Master checkpoint only on the owner's word.
  4. Found by cap-01's director run (2026-10-20): under rr-26's canonical gate (joint tears can no longer pass as air;
     historical frame/pocket exceptions no longer waive source-space failures) the Seer's native gates fail with 31
     joint tears of 2-3 px (front move 7, bolt 20, hit 4/8/9, death 27-30/62; rear mark 10, 27-46). Same failures on
     integration code, so it isn't cap-01. Plan: land cap-01, then re-capture native proofs for every rig with the fast
     path (Seer, Thrall, Mirror, Mimic, Weaver, Mortar, Capacitor) and give each failing rig a fix unit (clip-scoped
     own-piece continuations, as for the Thrall's front pockets). Hole list: scratchpad seer_holes.json (re-derive with
     native_errors(..., hole_details=[])).
  4. Backlog from today: the Mirror's feet and fists revisit (owner: "not totally sold"); unify the two detached
     provenance classifiers (rest_space.py from rr-26, source_space.py from rr-25) with differential tests (rr-26 review Low);
     rr-26 Low: a sum-preserving canonical-weight regression; rr-21 Low: path-containment test fixture.
     Thrall rear tether fin (low priority; rr-27 study in experiments/cutouts/arc_thrall/rr27/tether_study and stash
     "rr-27 r3 tether lowering study"): candidate A (65/153) holds well but every raise/lower path tried folds the arm
     under the reach gate; a fix needs a wide outward arc or a gate rule for brief swings. Original notes: the rear
     hold target (forward 206, lift 63 from rest tip 44,204.75; forward = (+0.866,-0.5), lift = -y) puts the cap near
     (222,39), past the far shoulder (170,83) and head (156,49), so the upper arm crosses the back. Plan: render rear
     hold poses for cap targets A (100,20) f65/l153, B (85,60) f47/l121, C (95,130) f59/l46, D (60,95) f19/l101 and
     pick one by eye; then a data edit before the post-rr-26 record refresh.
     Empower charge sound: audition posted 2026-10-20 (inbox empower-sound): recipes
     spec/peer_benchmark/staged/sfx/recipes_empower.json (A Kindle, B Seal, C Ignite), rendered with sfx_lab design.py
     against the rebuilt library index output/sfx-lab-index-2026-10-20/ (the /tmp copy was lost to temp cleanup);
     clips in output/peer-benchmark-2026-10-12/empower-charge-audition/. After the pick: build via sfx_lab build.py
     with the mix targets and wire the cue (a small unit).
     Keyword tooltip stacks list a keyword twice when an Empower bonus modifies it (charged Overhead Smash: MELEE
     "Modified by: Empower +4" and plain MELEE). Pre-existing: `action_icon_library._append_tooltip_entry` dedupes on
     icon+full text. Show each keyword once, keeping the modified entry.
     Proof capture speed (owner OK'd 2026-10-19): production captures write every frame as a full 1920x1080 lossless
     PNG (~7,900 frames, ~14 GB, 30-50 min per rig). Tooling unit after the current rigs land: crop each frame to the
     actor's bounds plus a margin and use fast PNG compression, same pixels gated; target a few minutes and <1 GB per rig.
  5. Then: Lancer/Herald/Gloam v2 conversions; rr-09 (narrow rig proof bindings), qa-09..12, design-01.
  5. Hygiene: workers can't write Git metadata, so the director merges integration into unit branches; never commit to
     integration while its suites run; proof captures are deleted after review (20 GB each round).
- Paint-overs DONE (director, identity gate PASS): `spec/art_identity/jobs/{hoarfrost_seer,arc_thrall,gale_herald,
  gloam_stalker}/mq5_{front,rear}`. Motion data: `staged/rr-07`, `staged/rr-08`.
- Review inbox: https://claude.ai/artifact/SWBweH8njp6JEy9GBpguyE — open: playtest-10 (owner's call).
- Follow-up (2026-10-17): `tests/skill_progression_analytics_test.gd` fails on the integration branch (2 failures: terminal outbox fixture / resumable-run clear) and is not in `tests/run_tests.gd`, so nothing caught it. Next QA unit: find the cause, and wire every supplemental test into the suite (or a supplemental runner) so they can't rot.
- Test-debt follow-ups (from qa-08's audit; ids in tests/quarantine.json once it lands): qa-09 stale references, qa-10 legacy cutout tests, qa-11 long diagnostics, qa-12 export-workflow tests, bug-01 prepared_other_character_view ownership (possible real bug, do first), design-01 tests needing director UI/rules decisions.
- bug-02 (2026-10-17): `tests/owned_cpu_asset_preparation_test.gd` fails deterministically on the director's machine. Both "Cancelled audio must drain without publishing its private source" checks fail, on integration and on the qa-08 merge; it passed in Codex's sandbox runs. Find the root cause (a cancel-after-publish race in `asset_loader.prepare_audio_for`, or a test that assumes the worker is still running one frame later), fix it, and register the test. It's quarantined at the qa-08 merge.
- qa-13 (2026-10-17): `suites/full_scene_controls_program` fails only under heavy load (the rr-05 windowed proof running alongside): `card_keywords_suite._test_live_targeted_empower_and_stagger_preview` reported "Targeting arrow remains visible and ends on the hero" with the endpoint 1 px off the hero (875.73 vs 874.72). It passes 3/3 alone. Find the frame-timing root cause (likely the hero idle bob versus the arrow endpoint sample) and make the check deterministic.
- rr-09 (2026-10-17): the maquette rig proof's `input_bindings` include `scripts/run_scene.gd` and `scripts/combat_board_view.gd`, so any unrelated change to either file marks every rig's pixel samples and native captures stale (the rr-05 recheck failed after the flow-01 and bug-01 merges). Bind the pixel samples and native parts only to the files that affect rig rendering (the `scripts/maquette_cutout_runtime/**` renderer, the case data and the presentation constants), and keep RunScene bindings only on the production capture. Do this before rr-07/rr-08 multiply the cost.
- det-02 (2026-10-18): `tests/suites/health_ghost_suite.gd` line ~162 compares the ghost tracker's elapsed time with wall-clock time × Engine.time_scale within 60 ms. It failed once under load in the integration suite after det-01 (rr-07 running alongside) and passes 3/3 alone. Make it deterministic: compare against the frame deltas the tracker actually received, or drive the presentation clock from an injected delta, without wall time. Also audit the suite for other wall-clock assertions.
- det-02 noticed wall-clock watchdogs in `tests/suites/combat_motion_timing_suite.gd` (~line 42); audit them in the next determinism unit.
- Follow-up (2026-10-17): fix-05's committed map timing assertion (≤ 250 ms per section) failed once under parallel suite load (257 ms in bug-01 r5; recheck 173 ms). In the committed suite, assert the deterministic search-node budget instead of wall time, and keep the wall-time limits in the 2,000-seed sweep tool. Give it to qa-08 if it's still open, otherwise to the next QA unit.
- Blender bridge runs for worktree mq-03 (idles out 3 h after the last job; restart for rr-06/roster units with
  their worktree names).

## In flight (2026-10-15 late, playtest 7 follow-ups; Codex model gpt-6-astra + max_running 6 for today — revert the Labyrinth profile after)
- Merged today: sfx-03, rr-01, art-04 (shrike), por-01, ux-02, art-05, ui-02, qa-04, fix-03. Playtest 7 = 7901c37f0.
- Merged into integration: chr-02 (9d711ceb5), art-06 (bf3ed130a), ux-03 (a98d3683f), art-07 (af5163220), vfx-01 (693209518), rr-02 (0d2975df1),
  fix-04 (81e7f0dc9), ux-04 (1a9e585e7). Full suite running on integration (no merges until done). Playtest 9 after sfx-04. Full suite running on integration (no merges until it finishes). ux-04 (text rewrite) launched.
- MERGE HYGIENE: after merging a unit that changes imported assets (audio/art), run `godot --headless --import` in the
  integration worktree before the full suite (qa-05: stale audio imports made the sync suites fail).
- REVIEW POLICY (owner 2026-10-15, Claude usage): peer reviews run on Codex via `scratchpad/codex_review.sh UNIT REF PROMPT`
  (detached scratch worktree under /private/tmp/labyrinth_codex/review/, output REF.md there); art judging is done by Claude
  directly, no judge/review subagents.
- Codex review running: sfx-04 39141f2a3.
- vfx-01 r4 running: peer found the r3 CPU win was a held-frame benchmark artifact (real frames: lightning +5.35 ms);
  director: rasterize line cores on the GPU (non-AA polylines in the low-res layer), sample CPU on unique frames.
- Running: rr-02 r7 (inter-leg painted shadow; native motion probe error), anim-02, art-07 r2 (empty-body override rule).
- anim-01/anim-02 SHELVED (owner 2026-10-15): the mesh-warp idle reads as the "weird rippling" the owner rejected before,
  and the shrike's whole-body bob reads as an unrealistic bounce. Not merged. Replacement: real cutout parts with
  independent rigid bob/sway (typical idle). Owner OK'd the order: rr-03 shrike rig (brief ready) launches when rr-02 lands, then the other 11
  static enemies as a cutout wave (cutout skill segmentation); they stay still paintings until rigged.
- art-07 r1 running (peer CHANGES on b40c9fd70: hue protection swallowed 64-93% of real rear bodies; re-processing must
  reproduce recorded pixels; green residue; filter validation). Approved art unaffected (processed with the pre-art-07 tool).
- sfx-04 r4 running (peer CHANGES on 6eca206c0: combat speed 1.5x/2x breaks alignment, shop.sell_02 malformed, restore
  gain over peak caps, bank test not in suite; director rule: align to the earliest local max within 2 dB, cut ≥20 dB
  below; compact audit/provenance).
- Wave 1b art (judge adb5256b83138e82d):
  - Lightning wisp: pair judge PASS = `mq1_front_v2` + `mq1_rear_v3` (crackle-trim edit, tone L, no palette match).
    Sheet `sheet_pair_mq1.png`, shown to owner. Cloud texture is the softest approved (owner may call it smooth).
  - Shale bloomer: pair accepted = `mq3_front_v2` (judge PASS) + `mq3_rear_v2` (trunk edit, padded to 1092 for maquette scale,
    palette-matched via front-job link; judge-tested fix for its only fail). Sheet `sheet_pair_mq3.png`. Shown to owner.
    Optional polish: front honeycomb rows → hex clusters.
  - art-06 merged: new raw_steps kits are recorded with `tools/art_identity_gate.py record-steps --kit …` then re-processed
    (sidecar); bloomer mq2_front, mq3_front_v2, wisp mq1_rear_v2 migrated, registry check PASS.
- Lancer pair: judge PASS r2; director tone r2 restored the frost read (front/rear `mq1_front_v3`/`mq1_rear_v3`,
  sheet `sheet_pair_mq1_v3.png`, 50e1b836c). Shown to owner; awaiting verdict before rigging.
  These two kits use the art-05 field names: re-record them with art-06's migration when art-06 merges.
- Gaoler: owner-approved rounded pair `mq3_front_v4` + `mq3_rear_v3`; rr-02 rigs it; phase 3 = production integration.
- ux-04 (text rewrite) launches after ux-03 merges. Owner question open: self-hit amplification (Meteorfall/Detonate).
- Watchdog: `scratchpad/watch_loop2.sh` (tracked background job).

## Next actions
1. Process each fix round (windowed proofs yourself), peer review, merge; then cut playtest 8.
2. rr-02: run the listed windowed commands (native_rest, render v03, verify-render, proof.py); review the reel.
3. Owner verdict on the lancer → rig via rr-02's tool. Remaining wave 1b: bile bloomer, lightning wisp, acolyte/veilbound,
   harrier, warden (front), cinder ooze (front). Wave 2: roc fledgling + gallows roc. Wave 3: dragons.
4. Known environment-only test noise (2026-10-13): `test_chopin_death_music` fails when a Godot import leaves untracked
   `output/classical_soundtracks/**/preview.ogg.import` sidecars (delete them); the task-queue handoff test flaked once.
- Plan page (artifact): https://claude.ai/artifact/N1G8qgbt58t6CbufwQxq5d — source output/peer-benchmark-2026-10-12/plan_page/ (plan_template.html → index.html via inline-font build snippet)

## Update 2026-10-12 evening
- Merged into integration: ev-01 (5ca4bfe87).
- Running: map-01, feel-01, biome-01, sfx-00. Queued (--wait): ev-02 launch, itb-02 fix round.
- Ready briefs: itb-01 (after feel-01), sfx-01 (after feel-01).
- Owner feedback: air pillar bow removed (v3 approved). Owner granted CC0/free-commercial downloads; Mixkit set aside
  (scripted download vs its terms) in output/sfx-sources-excluded-2026-10-12/.
- SFX venv: ~/.cache/umbra-sfx/venv (numpy/scipy/soundfile/pyloudnorm).
- Peer review: none yet — run one review over the merged wave before asking the owner to inspect.
- SFX audition page (artifact, db picks in collection 'picks'): https://claude.ai/artifact/PZV7sqf6pPZSpK7r6419Rk — source output/peer-benchmark-2026-10-12/sfx/audition_v1/publish.html (make_publish_page.py); candidates picks_v1.json

## Update (integration f3fcff1fc→8c71fa17b)
- Integration contains: ev-01, sfx-00 (+director fixes), feel-01, ev-02, biome-01. Full suite PASS at 8c71fa17b.
- In flight: map-01 r2 (ev-01 integration: reveal→scout mysteries), itb-02 r3 (dock baseline), itb-01, feel-02.
- Next: merge map-01 → launch meta-01 (run end) → meta-02 (Chronicle) → meta-03 (Depths); sfx-01 after itb-01; SFX round-2 candidates for owner 'none fit' cues; peer review of the merged wave; owner inspection fixture of the integration branch.

## Update (integration 83b26b846)
- Integration contains: ev-01, sfx-00, feel-01, ev-02, biome-01, map-01, feel-02, itb-02.
- Suites: full suite rerun at 28170510d in progress (the feel-02 run was stopped because the itb-02 merge changed the tree mid-run).
- Running: int-01, itb-01, meta-01, sfx-01. Peer review subagent over master..8c71fa17b in progress.
- SFX audition: owner at 63/82; v1 verdicts in feedback.md; snapshot output/.../sfx/owner_picks_db/.
- Next: merge int-01/itb-01/meta-01 as they pass; meta-03 after meta-01; meta-02 brief; SFX round 2 for none-fit cues
  (block.break, push.slide, trap.trigger, radiance.light, illusion.break) after the owner finishes v1; build approved assets.

## Update (integration bb2d50457)
- Merged since: int-01 (65bfb8add). Integration suite PASS at 28170510d (full, undo, ghost, biome, feel).
- SFX: owner finished v1 picks (76 docs). 77 variants built + imported (a1ce556d9); cue data has variants for 67 cues.
  Round 2 (5 cues) = layered recipes (staged/sfx/recipes_r2.json) waiting for sfx-02's renderer. No new ambience.
  marketing/.gdignore added: a full `godot --import` otherwise imports the trailer's symlinked asset copy and rewrites
  .import files with marketing paths (never run a full import without it).
- Peer review wave 1: REQUEST_CHANGES → fix-01 running. Re-review with the same reviewer (agent acb9d916bb6559805) after.
- Running: fix-01, meta-01, sfx-01, sfx-02; queued: itb-01 r1. Ready: meta-02, meta-03 (after meta-01).

## Brief checklist additions (learned 2026-10-12)
Every UI brief must also decide: fallback copy for missing/legacy data, overflow layout at the maximum content size,
sound (or explicitly none) for every new reveal, and the full owned-file list incl. run_scene/run_tests registration.
Enemy briefs: one icon per concept, stand-in art policy, encounter data entries.
Every windowed probe brief: capture a 1920×1080 SubViewport (UPDATE_ALWAYS) like tests/movement_undo_probe.gd — never
root.get_texture() (non-native on this display; failed itb-01, en-02, en-03).
Every art job (enemy, prop, NPC body): the visual identity gate — canon refs via `kit`, `process`, review sheet + canon
sheet, independent judge subagent, then owner; never approve at generation size (owner verdict 2026-10-12).
Every UI brief: no default/unstyled boxes — every panel, chip and bar uses the design-system helpers (bramble empty-bar regression).

## Update (integration 02c3a4368)
- Merged: fix-01 (re-review REQUEST_CHANGES → fix-01 r1 running: victory-beat stale board blocker), sfx-02, itb-01.
- SFX: all cues picked (round 2 built ed2e07f04). Waiting on sfx-01 (cue bank) to hear them in game.
- Enemies: E1 art approved (6), E2 art approved except briar weaver r1; 7 icons approved. en-01, en-02 running; en-03
  queued. enc-01 r1 (empty earth/shadow boards in captures) queued. meta-01 r1 (12 TODO_DESIGN decided) queued.

## Playtest rule (2026-10-12 incident)
The owner's playtest runs from a FROZEN detached worktree (`../Labyrinth.worktrees/peer-benchmark-playtest`, pinned to a
verified commit), never from the integration worktree: the game reads data files at runtime, so merging mid-session
mixed old enemies.json with new encounters.json and blanked the board. Refresh the playtest worktree only between
sessions (`git -C <wt> checkout --detach <commit>` + headless `--import`), after the suite passes at that commit.
- Playtest builds: `peer-benchmark-playtest` (5ab3b59cc, session 2); `peer-benchmark-playtest-3` (95bf93536: SFX mix
  pass, fix-02, en-01 enemies, run-end screen). New sessions get a NEW frozen worktree; old ones are removed only after
  the owner confirms they're done.

## Update (integration 325ace5ca) — visual identity gate
- Owner (2026-10-12): new enemy art isn't at standard (head-on views, miniaturized detail, capacitor wrong perspective);
  wants tooling + rules that make identity regressions hard. Response: spec/visual_identity_gate.md + spec/art_identity/
  (canon, preamble, views, bands, judge rubric); art-01 builds the tooling; art-02 re-arts all 12 enemies through the kit.
- Pilot 1 (scratch, unedited): tick/thrall/capacitor at correct view; thrall pale+lanky, capacitor too clean → preamble
  gained Proportions + Palette sections. Pilot 2 running (thrall, capacitor, gloam stalker, gust shrike).
  Sheet: output/peer-benchmark-2026-10-12/identity_gate/pilot_before_after.png.
- Mechanics of en-04..06 keep merging with current art as placeholders (registry kind `pending_reart`).
- Next: review en-06/itb-03/en-05 probes → merge; en-05 decisions round; art-01 review; after art-01: kit runs for 12
  fronts → judge → owner sheets → rears; rules: AGENTS.md section + create-labyrinth-enemy skill + brief checklist.
- Then: UI identity lint (palette/StyleBox via design-system helpers) — phase 2 of the gate.

## Playtest 4 (frozen worktree ../peer-benchmark-playtest-4 at 4fc16f982; import + start fixture verified)
New since playtest 3: start room opens the map (ux-01), threats at rest v2 (itb-03), en-02/03/06 section enemies with
placeholder art, Chronicle (meta-02), Umbra Depths (meta-03), encounter fallback (qa-01). Do not touch that worktree.

## Update (art-02 judge-complete, 2026-10-13)
- All 12 section enemies re-painted through the identity kit; independent judge PASS on every front and rear
  (spec/peer_benchmark/staged/reart/judge_log.md). Owner review images: output/peer-benchmark-2026-10-12/identity_gate/
  review_before_after_board.png, review_fronts_rears_2x.png.
- Gate learnings folded in: despill ring + key unmix; no-copy reference rule; front-only lateral axis; rear handedness
  rule; rear-specific subjects when a rear keeps coming out as a front/side view; deterministic Lab palette match and
  outline cleanup (prototypes in spec/art_identity/prototype/, to become first-class `process` steps in art-03).
- Integration: en-01..06 all merged; full suite green at c474da57f+.
- Next: owner approves art → art-03 (directional static art + portraits + density + registry + gate metrics:
  edge_light_share, front/rear consistency).

## Playtest 5 (frozen worktree ../peer-benchmark-playtest-5 at b7bec5a4b; import + start fixture verified)
Adds en-04 (briar weaver, slag mortar) and en-05 (glacial mirror, gust shrike) + flag-rider fix over playtest 4. All 12 section enemies, old art. Do not touch that worktree.

## Playtest 6 (frozen worktree ../peer-benchmark-playtest-6 at 74965c9a1; import + start fixture verified)
Adds art-03: the 11 approved section enemies with new front/rear art, four-direction facing, new portraits. Gust shrike still old art (maquette pending owner).

## Update (integration 6786edf5d, 2026-10-13)
- Merged sfx-03 (lookahead limiter; hit.blade.light +7 dB, status.shatter +6, status.freeze +5; 100 ms short-window
  measure). Sync conflict in tests/test_sfx_lab.py resolved keeping qa-03's optional-module guards on every class.
  Sound-lab venv: 39 tests OK; system Python: 39 skipped cleanly; SFX bank PASS.
- Integration full Godot suite PASS (685 s) at the qa-03 merge; Python discovery's 2 failures are environmental (above).

## Playtest 7 (frozen worktree ../peer-benchmark-playtest-7 at 7901c37f0; import + start fixture verified)
Adds: perched gust shrike (maquette repaint, four facings, portrait); crawler rig recolour; sfx-03 limiter + louder blade/shatter/freeze cues. The gaoler still uses its old rig (rounded repaint awaiting owner, then rr-02 re-rig).

## Playtest 8 (frozen worktree ../peer-benchmark-playtest-8 at 3782ea5d0; full suite PASS; import + start fixture verified)
Adds since playtest 7: Chronicle spells as card tiles with hover previews (chr-02); glossary tooltip stacks on relic
choices, owned relics and inline icons, data-driven glossary (ux-03); 17 rebuilt turn-order portraits (por-01); Fatigue
no longer amplified by Expose/Chilled/Frozen + SPENT HUD + token icons (fix-03); pixel-identical UI cleanup (ui-02);
tooling (art-05/06, qa-04). Not yet in: sound sync, pixel FX, gaoler rig, new lancer/wisp/bloomer art (await owner).


## Playtest 9 (frozen worktree ../peer-benchmark-playtest-9 at 44500665e; full suite PASS 807 s after re-import; fixture verified)
Adds since playtest 8: Briar Weaver/any enemy never takes a silent empty turn — falls back to its fallback intent with a
cancelled badge (fix-04); sound sync — hits land on the visual climax across speeds, cue length caps (electric trap buzz
≤1.2 s) (sfx-04); pixel-art elemental FX (vfx-01); approved glossary/relic text rewrite with gold keywords (ux-04);
art tooling (art-07, rr-02 maquette→cutout; gaoler rig not production-integrated). Fixture opens combat vs briar weaver,
crawler, harrier. Not yet in: shrike cutout (rr-03 round 3), other static-enemy cutouts, new lancer/wisp/bloomer art.

## Update 2026-10-16 early
- Merged rr-03 + qa-06 (Gust Shrike cutout rig; collapse death; proof hardening) at f411c09a9; integration full suite
  PASS after re-import. Shrike board reel: output/peer-benchmark-2026-10-12/shrike/gust_shrike_production_reel_v05.mp4.
- Disk filled to 0 bytes (Codex review checkouts 105 GB, merged-unit worktrees ~85 GB, old playtests, probe homes, then
  23 GB of demo-01 raw frames). Owner approved cleanup (now 245 GB free) and asked to clean up as we go: review runner
  deletes its checkout after each review; merged+clean unit worktrees are removed at merge; captures stream per clip.
- demo-01 (scripted demo clips with audio, 21 clips / 3 reels) round 2: streaming per-clip recording + 8 GB disk guard.
- Next: record + review demo reels → send to owner; static-enemy cutout wave (after owner sees the shrike reel); owner
  verdicts pending on lancer/wisp/bloomer art and on self-hit amplification; owner has more follow-up notes coming.

## Update 2026-10-16 afternoon
- Merged: ux-05 (previews mark destruction), pb-01 (pre-battle heading + living foes), deck-01 (no magic limit, Purge),
  demo-01 (demo clip recorder), rr-04 (Shale Bloomer + Lightning Wisp maquette rigs; conflict in pre_battle_view.gd →
  int-02 routes all surfaces to the maquette renderers).
- Merge hygiene addition: after merges run BOTH the Godot full suite and `python3 -m unittest discover -s tests -p
  'test_*.py'` in integration (Python-only failures slipped past the Godot run: glossary copy budget, demo exemption
  fixtures bound to live source fingerprints).
- Blender bridge (owner-approved): `tools/blender_bridge/bridge.py <worktree...>` runs headless Blender jobs from
  /private/tmp/labyrinth_codex/blender_bridge/queue for sandboxed Codex maquette units; start as a tracked director job,
  stop with `touch /private/tmp/labyrinth_codex/blender_bridge/STOP`.
- mq-03 (Blender-native maquettes: CC0 base mesh + armature, cloth sim, plates, crystals): lancer r3 maquette + front
  paint-over shown to owner; awaiting verdict before rear + roster rollout.
- Next: int-02 → integration suites (Godot + Python) → playtest 10. Owner pending: lancer r3 direction, bloomer/wisp
  motion videos, boon list.

## Playtest 10 (frozen worktree ../peer-benchmark-playtest-10 at 718101953; Godot + Python suites PASS; fixture verified)
Adds since playtest 9: previews mark destroyed terrain/traps/illusions/lethal pull ghosts instead of hiding them
(ux-05); pre-battle shows only `OBJECTIVE · <TITLE>` with the rule in a tooltip, foes play their board idles (pb-01);
magic-slot limit dropped — spells go straight into the deck, Purge at Scavenger (50, +25) and Campfire (deck-01);
Shale Bloomer + Lightning Wisp maquette cutout rigs on every surface (rr-04, int-02); Gust Shrike rig (rr-03/qa-06).
Not yet in: run-start boons, map branching, auto next-section transition, Immolation buff, move+block "Stay",
Frostglass Lancer redo (mq-03 in progress), remaining static-enemy rigs.
