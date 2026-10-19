# Peer-benchmark program — STATUS

Goal (owner, 2026-10-12): raise every facet of Escape the Umbra to the bar of Slay the Spire and
Into the Breach — visual cohesion/identity/fidelity, playability, mechanics, board + UI animation,
sound, content completeness (room types, events, map branching), card/enemy design, level gen.
Experimental: owner may cherry-pick or revert. Bold changes allowed; prior Codex-era approvals are
not binding. Claude directs (all taste), Codex implements (orchestrate-codex skill).

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
- Next (in order), 2026-10-19 afternoon:
  1. Integration green at 521fa8f20+ (Godot PASS, Python 1223 OK): mq-10, rr-18, gait-01 merged (+ director post-merge
     fixes). gait-01 = every humanoid walks on the protagonist's model (6 steps/tile, projected legs, pelvis fit).
  2. Running: rr-20/21/22 round 2 (walk adoption, Mimic restaging, Mortar crucible masks, native gate fixes); rr-24
     (Thrall re-cut: collar, skirt). rr-23 (Mirror re-cut, guard order) committed ba68a1359: windowed chain + Codex
     review running.
  3. On each finish: windowed proof (locked chain scripts in scratchpad), Codex review, merge with suites, then fresh inbox
     items (Mirror, Thrall first; then Mimic, Weaver, Mortar).
  4. Backlog from today: the Mirror's feet and fists revisit (owner: "not totally sold"); unify the two detached
     provenance classifiers (rest_space.py from rr-26, source_space.py from rr-25) with differential tests (rr-26 review Low);
     rr-26 Low: a sum-preserving canonical-weight regression; rr-21 Low: path-containment test fixture.
     Thrall rear tether (director data, staged/rr-11 view_keys.rear): the tube rises over the FAR shoulder, so the upper
     arm crosses the back and leaves a fin at the near shoulder; re-key it to rise over the near shoulder after rr-24 lands.
     Empower charge sound: three candidates for an owner audition (ui-03 ships silent).
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
