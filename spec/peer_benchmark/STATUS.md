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

## In flight (2026-10-15 late, playtest 7 follow-ups; Codex model gpt-6-astra + max_running 6 for today — revert the Labyrinth profile after)
- Merged today: sfx-03, rr-01, art-04 (shrike), por-01, ux-02, art-05, ui-02, qa-04, fix-03. Playtest 7 = 7901c37f0.
- Merged into integration: chr-02 (9d711ceb5; peer signoff 99d872fa5, r5 tests-only).
- Running (6): vfx-01 r2, rr-02 r5 (motion-frame gates), anim-01 r5 (re-send of r4), ux-03 r4 (peer CHANGES: stray
  keyword-tooltip line on 9 cards, TopBar overlap at 1.25x, wrapped owned tray, opt-in callers, one click guard, skills
  read skills.json), art-06 r2 (peer CHANGES: 5 surviving mutants, record-steps INPUT CHANGED, resolved paths, job-link
  scope). Image: img-mq-bloomer-front-r3.
- sfx-04 r4 running (peer CHANGES on 6eca206c0: combat speed 1.5x/2x breaks alignment, shop.sell_02 malformed, restore
  gain over peak caps, bank test not in suite; director rule: align to the earliest local max within 2 dB, cut ≥20 dB
  below; compact audit/provenance).
- Wave 1b art (judge adb5256b83138e82d):
  - Lightning wisp: front v2 judge PASS (`jobs/lightning_wisp/mq1_front_v2`; cloud texture softest approved, note for
    owner). Rear generating (img-mq-wisp-rear-r1, prompt_rear_r1, refs = maquette r3 rear + approved front).
  - Shale bloomer: mq2_front FAIL (r7 maquette head-on/symmetric 0.954, arm-like stubs, low deep shadow, honeycomb lost)
    → maquette r8 + prompt r3 → `jobs/shale_bloomer/mq3_front` (symmetry 0.741) at the judge.
  - After art-06 merges: art-06 removes `png_bytes`, so director kit scripts must use `tools/art_identity_gate.py record-steps`;
    run it on every raw_steps kit created in integration after art-06 branched (bloomer mq2_front, mq3_front_v2).
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
