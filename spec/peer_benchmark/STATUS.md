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
M0 — research + gap audit (in progress).

## In flight
- Codex: ev-01 (event engine), map-01 (map v2). Watchdog: `cu watch` background.
- Research agents: StS, ITB (pending); SFX sourcing agent → output/sfx-sources-2026-10-12/ (owner approved CC0/free-commercial downloads).
- Done: Umbra inventory (spec/peer_benchmark/umbra_inventory.md).

## Next actions
1. Event art: 27 image runs (pixel-painterly like card art, ragged dark vignette; native ~480x320 shown 2x).
2. ev-02: illustrated event view + omen HUD (needs mockup).
3. feel-01: hit-stop, impact flash, enemy-turn pacing, combat speed setting.
4. sfx-01: data-driven SFX cue bank + call sites (after sourcing).
5. Gap audit artifact for the owner (after research lands).
6. Follow-up after ev-01+map-01 merge: reveal effect = scout mystery rooms in layout rev 4.
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
